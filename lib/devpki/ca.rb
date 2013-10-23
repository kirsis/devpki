require 'devpki'
require 'devpki/data_directory'
require 'sqlite3'

module DevPKI
  class CA

    attr_accessor :sqlite_db
    attr_accessor :id

    def initialize(id=0)
      raise Exception.new("CA ##{id} does not exist. It must be initialized first.") if not DevPKI::CA.exists?(id)

      @sqlite_db = SQLite3::Database.open(DevPKI::CA.db_path(id))
      @id = id
    end

    # Initializes an empty CA database and generates a certificate for self
    def self.init(id=0, name=nil, parent_ca_id=nil)
      raise Exception.new("CA with ID #{id} already exists!") if self.exists?

      SQLite3::Database.new(self.db_path(id))
    end

    # Checks if CA with given ID exists
    def self.exists?(id=0)
      File.exists?(self.db_path(id))
    end

    # Returns the path to a CA database
    def self.db_path(id=0)
      DevPKI::DataDirectory::absolute_path_for("ca_#{id}.db")
    end

  end
end