require 'devpki'

Dir["lib/devpki/cli/**/*.rb"].each {|file| require file[4..-1] }

module DevPKI
  class DataDirectory

    # Only support OSX atm
    def self.platform_supported?
      (/darwin/ =~ RUBY_PLATFORM) != nil
    end

    def self.absolute_path
      File.expand_path("~/Library/Application Support/devpki")
    end

    def self.absolute_path_for(file_name)
      File.expand_path(file_name, self.absolute_path)
    end

    def self.get
      if not Dir.exists?(self.absolute_path)
        Dir.mkdir(self.absolute_path)
      end
      Dir.new(self.absolute_path)
    end

  end
end