require 'devpki'
require 'thor'
require 'devpki/ca'
require 'devpki/data_directory'

module DevPKI
  module SUBCLI
    class CA < Thor
      desc "delete <id> [-all]", "Delete a CA"
      long_desc <<-LONGDESC
        Deletes a certification authority (CA) and its database.

        If ID is not given, it is assumed to be 0.

        With option --all, all CA databases will be deleted.
      LONGDESC
      option :all, :type => :boolean
      def delete(id=0)
        if options[:all]
          DevPKI::DataDirectory::reset_to_empty
        else
          DevPKI::CA.delete(id)
          puts "CA database deleted."
        end
      end
    end
  end
end