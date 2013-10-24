require 'thor'

require 'devpki'
require 'devpki/cli/ca/init'
require 'devpki/cli/ca/delete'
require 'devpki/cli/ca/_hack'

require 'devpki/cli/ocsp'

module DevPKI
  class CLI < Thor
    desc "ca [<id>] <command> [<args>]", "PKI CA functionality"
    subcommand "ca", DevPKI::SUBCLI::CA
  end
end