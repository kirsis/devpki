require 'devpki'
require 'thor'
require 'net/http'

module DevPKI
  class CLI < Thor
    desc "ocsp [--method=get|post] --uri=<ocsp uri> ISSUER_CER_FILE:SUBJ_A.CER[,SUBJ_B.CER...]...", "Performs an OCSP query"
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

    def ocsp(*cer_files)

      raise InvalidOption.new("Please specify at least one CA and subject certificate file.") if cer_files.empty?

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

      if response.status != 0
        raise StandardError, "Not a successful status"
      end
      if response.basic[0][0].serial != cert.serial
        raise StandardError, "Not the same serial"
      end
      if response.basic[0][1] != 0 # 0 is good, 1 is revoked, 2 is unknown.
        raise StandardError, "Not a good status"
      end
      current_time = Time.now
      if response.basic[0][4] > current_time or response.basic[0][5] < current_time
        raise StandardError, "The response is not within its validity window"
      end

      # we also need to verify that the OCSP response is signed by
      # a certificate that is allowed and chains up to a trusted root.
      # To do this you'll need to build an OpenSSL::X509::Store object
      # that contains the certificate you're checking + intermediates + root.

      if response.basic.verify([],store) != true
        raise StandardError, "Response not signed by a trusted certificate"
      end

    end
  end

end