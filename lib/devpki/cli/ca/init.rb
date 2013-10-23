require 'devpki'
require 'thor'
require 'devpki/ca'

module DevPKI
  module SUBCLI
    class CA < Thor
      desc "init <id> [--name=<name>] [--with-parent=<id>]", "Create a new CA"
      long_desc <<-LONGDESC
        Initializes a new certification authority (CA) with given ID. The given ID must not already be in use
        by another CA.

        The ID provides a way to specify which CA you wish to target with other commands.
        You may omit the <id> argument, if you wish, in which case it is assumed to be 'default'.

        You only need to specify ID, if you plan to use multiple CAs.

        If the --name option is given, the value will be included in the CA's commmon name.

        If the option --with-parent is given, the CA will be created as a subordinate CA to the specified parent CA.
        Without this option, the CA will be created as a root CA.
      LONGDESC
      option :name, :banner => "<name>", :desc => "Value to include in the CA's certificate common name"
      option :"with-parent", :banner => "<id>", :desc => "ID of the parent CA. If ommitted, the CA will be created as a root CA"

      def init(id="default")
        DevPKI::CA.init(id, options[:name], options[:"with-parent"])
      end
    end
  end
end