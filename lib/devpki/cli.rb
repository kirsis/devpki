require 'devpki'
require 'thor'

Dir["devpki/cli/**/*.rb"].each {|file| require file[4..-1] }

module DevPKI
  class CLI < Thor
    desc "ca [<id>] <command> [<args>]", "PKI CA functionality"
    subcommand "ca", DevPKI::SUBCLI::CA
  end
end