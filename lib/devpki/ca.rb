require 'devpki'
require 'devpki/data_directory'
require 'sqlite3'
require 'rubygems'
require 'openssl'

module DevPKI
  class CA

    attr_accessor :sqlite_db
    attr_accessor :id

    def initialize(id=0)
      raise CADBError.new("CA ##{id} does not exist. It must be initialized first.") if not DevPKI::CA.exists?(id)

      @sqlite_db = SQLite3::Database.open(DevPKI::CA.db_path(id))
      @id = id
    end

    def self.delete(id)
      raise InvalidOption.new("CA with ID #{id} does not exist.") if not self.exists?(id)
      File.delete self.db_path(id)
    end

    # Initializes an empty CA database and generates a certificate for self
    def self.init(id, name=nil, parent_ca_id=nil)
      raise InvalidOption.new("CA with ID #{id} already exists!") if self.exists?(id)
      raise InvalidOption.new("Parent CA with ID #{id} does not exist!") if parent_ca_id != nil and not self.exists?(parent_ca_id)

      db = SQLite3::Database.new(self.db_path(id))

      sql = <<-SQL
        create table certificates (
          id integer primary key autoincrement,
          private_key_id integer not null,
          pem text,

          FOREIGN KEY(private_key_id) REFERENCES private_keys(id)
        );

        create table private_keys (
          id integer primary key autoincrement,
          pem text
        );
      SQL

      db.execute_batch(sql)

      if parent_ca_id != nil
        raise InvalidOption.new("Parent CA with ID #{id} does not exist!") if not self.exists?(parent_ca_id)
        puts "Exists: #{self.exists?(parent_ca_id)}"
        parent_db = SQLite3::Database.open(self.db_path(parent_ca_id))

        parent_ca_raw = parent_db.get_first_value( "select pem from certificates" )
        parent_key_raw = parent_db.get_first_value( "select pem from private_keys" )

        parent_ca_cert = OpenSSL::X509::Certificate.new parent_ca_raw
        parent_ca_key = OpenSSL::PKey::RSA.new parent_key_raw
      end

      key = OpenSSL::PKey::RSA.new(2048)
      public_key = key.public_key

      name ||= "Generic DevPKI CA ##{id}"
      subject = "/CN=#{name}"

      cert = OpenSSL::X509::Certificate.new
      cert.subject = OpenSSL::X509::Name.parse(subject)
      if parent_ca_id == nil
        cert.issuer = cert.subject
      else
        cert.issuer = parent_ca_cert.subject
      end
      cert.not_before = Time.now
      cert.not_after = Time.now + 2 * 365 * 24 * 60 * 60
      cert.public_key = public_key
      cert.serial = Random.rand(1..100000)
      cert.version = 2

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert

      if parent_ca_id == nil
        ef.issuer_certificate = cert
      else
        ef.issuer_certificate = parent_ca_cert
      end

      cert.extensions = [
        ef.create_extension("basicConstraints","CA:TRUE", true),
        ef.create_extension("subjectKeyIdentifier", "hash"),
      ]
      cert.add_extension ef.create_extension("authorityKeyIdentifier",
                                             "keyid:always,issuer:always")

      if parent_ca_id == nil
        cert.sign key, OpenSSL::Digest::SHA512.new
      else
        cert.sign parent_ca_key, OpenSSL::Digest::SHA512.new
      end

      db.execute( "INSERT INTO private_keys (pem) VALUES ( ? )", key.to_pem )
      private_key_id = db.last_insert_row_id

      db.execute( "INSERT INTO certificates (private_key_id, pem) VALUES ( ?, ? )", private_key_id, cert.to_pem)

      puts key.to_pem
      puts cert.to_pem
    end

    # Checks if CA with given ID exists
    def self.exists?(id)
      File.exists?(self.db_path(id))
    end

    # Returns the path to a CA database
    def self.db_path(id)
      DevPKI::DataDirectory::absolute_path_for("ca_#{id}.db")
    end

  end
end