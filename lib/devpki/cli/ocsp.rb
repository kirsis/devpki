require 'devpki'
require 'thor'

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


    end
  end

end