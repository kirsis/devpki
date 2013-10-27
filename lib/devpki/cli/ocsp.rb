require 'devpki'
require 'thor'
require 'net/http'
require 'pry'

module DevPKI
  class CLI < Thor
    desc "ocsp [--method=get|post] --uri=<ocsp uri> [--chain-certs=ca1.cer,ca2.cer...] ISSUER_CER_FILE:SUBJ_A.CER[,SUBJ_B.CER...]...", "Performs an OCSP query"
    long_desc <<-LONGDESC
        This command performs an OCSP query against the given OCSP URI, over HTTP. To perform
        a query, at least 2 certificates are needed - the CA certificate and the subject certificate
        file that is to be checked for revocation.

        Only HTTP POST method is supported at the moment (RFC 2560).

        EXAMPLE:

        To test subj_a.cer (issuer certificate ca.cer) against http://ocsp.ca.com:

        > $ devpki ocsp --uri=http://ocsp.ca.com ca.cer:subj_a.cer


    LONGDESC
    option :method, :default => "post", :banner => "get|post", :desc => "Method to use. GET as per RFC5019, or POST as per RFC2560. Defaults to POST."
    option :uri, :banner => "<ocsp uri>", :required => true, :desc => "OCSP responder URI."
    option :"chain-certs", :banner => "ca1.cer,ca2.cer...", :desc => "Trusted certificates that can be used, when verifying OCSP response signature."

    def ocsp(*cer_files)

      raise InvalidOption.new("Please specify at least one CA and subject certificate file.") if cer_files.empty?

      chain_cert_files = []
      if options[:"chain-certs"] != nil
        chain_cert_files=options[:"chain-certs"].split(",")
      end

      ca_subj_map = {}
      cer_files.each do |ca_subj_pair|

        raise InvalidOption.new("\"#{ca_subj_pair}\" is an invalid CA and subject pair. Please pass a pair with format similar to \"ca.cer:a.cer[,b.cer...]\"") if not ca_subj_pair.include?(":")

        ca_subjlist_split = ca_subj_pair.split(":")

        ca_file = ca_subjlist_split.first

        raise InvalidOption.new("No subject certificates specified for CA file \"#{ca_file}\". Please pass a pair with format similar to \"ca.cer:a.cer[,b.cer...]\"") if ca_subjlist_split.length != 2
        subj_files = ca_subjlist_split.last.split(",")

        ca_subj_map[ca_file] = subj_files
      end

      ca_subj_map.each_pair do |ca_file,subj_file_list|
        raise InvalidOption.new("CA certificate file \"#{ca_file}\" does not exist.") if not File.exist?(ca_file)
        subj_file_list.each do |subj_file|
          raise InvalidOption.new("Subject certificate file \"#{subj_file}\" does not exist.") if not File.exist?(subj_file)
        end
      end

      method = options[:method].upcase
      raise InvalidOption.new("GET method not implemented yet.") if method == "GET"

      ###### -------------- move this to DevPKI::OCSP

      cert_ids = []
      store = OpenSSL::X509::Store.new
      chain_cert_files.each do |chain_cert_file|
        puts "Adding #{chain_cert_file} to store"
        store.add_file(chain_cert_file)
      end
      #store.set_default_paths
      #store.add_file("root.crt")

      ca_subj_map.each_pair do |ca_file, subj_file_list|
        ca_cert = OpenSSL::X509::Certificate.new File.read(ca_file)
        store.add_cert(ca_cert)

        subj_file_list.each do |subj_file|
          subj_cert = OpenSSL::X509::Certificate.new File.read(subj_file)

          cert_ids << OpenSSL::OCSP::CertificateId.new(subj_cert, ca_cert)
        end
      end

      request = OpenSSL::OCSP::Request.new
      cert_ids.each do |cert_id|
        request.add_certid(cert_id)
      end

      request_uri = URI(options[:uri])
      request_uri.path = "/" if request_uri.path.to_s.empty?

      http_req = Net::HTTP::Post.new(request_uri.path)
      http_req.content_type = "application/ocsp-request"
      http_req.body = request.to_der

      http_response = Net::HTTP.new(request_uri.host, request_uri.port).start do |http|
        http.request(http_req)
      end

      ## ----

      if http_response.code != "200"
        raise StandardError, "Invalid response code from OCSP responder: #{http_response.code}"
      end

      response = OpenSSL::OCSP::Response.new(http_response.body)
      puts "Status: #{response.status}"
      puts "Status string: #{response.status_string}"

      # Statuses from http://tools.ietf.org/html/rfc2560 section 4.2.1
      #
      # successful            (0),  --Response has valid confirmations
      # malformedRequest      (1),  --Illegal confirmation request
      # internalError         (2),  --Internal error in issuer
      # tryLater              (3),  --Try again later
      #                             --(4) is not used
      # sigRequired           (5),  --Must sign the request
      # unauthorized          (6)   --Request unauthorized
      if response.status != 0
        raise StandardError, "Not a successful status"
      end

      # response.basic.status will be populated, if response.status == 0
      cert_ids.each_with_index do |cert_id,ix|

        # SingleResponse structure from http://tools.ietf.org/html/rfc2560 section 4.2.1
        #
        # SingleResponse ::= SEQUENCE {
        # certID                       CertID,
        # certStatus                   CertStatus,
        # thisUpdate                   GeneralizedTime,
        # nextUpdate         [0]       EXPLICIT GeneralizedTime OPTIONAL,
        # singleExtensions   [1]       EXPLICIT Extensions OPTIONAL }
        # single_response = response.basic.status[ix]

        # Find the single response that matches current cert_id
        single_response = nil
        response.basic.status.each do |single_response_candidate|
          if single_response_candidate[0].serial.to_s == cert_id.serial.to_s
            single_response = single_response_candidate
            break
          end
        end

        raise StandardError.new("SingleResponse for certificate s/n ##{cert_id.serial.to_s} not found.") if single_response == nil

        # CertStatus from from http://tools.ietf.org/html/rfc2560 section 4.2.1
        #
        # CertStatus ::= CHOICE {
        # good        [0]     IMPLICIT NULL,
        # revoked     [1]     IMPLICIT RevokedInfo,
        # unknown     [2]     IMPLICIT UnknownInfo }
        if single_response[1] != 0
          raise StandardError, "CertStatus for cert s/n #{cert_id.serial.to_s} is #{single_response[1]}"
        end

        current_time = Time.now
        if single_response[4] > current_time or single_response[5] < current_time
          raise StandardError, "The response for cert_id s/n #{cert_id.serial.to_s} is not within its validity window"
        end
      end

      if response.basic.verify([],store) != true
        binding.pry
        raise StandardError, "Response not signed by a trusted certificate"
      end

    end
  end

end