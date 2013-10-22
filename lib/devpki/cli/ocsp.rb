require 'devpki'
require 'thor'

module DevPKI
  class CLI < Thor
    desc "ocsp NAME", "say ocsp to NAME"

    def ocsp(name)
      puts "Ocsp #{name}"
    end
  end
end