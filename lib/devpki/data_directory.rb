require 'devpki'
require 'rbconfig'
require 'xdg'

Dir["lib/devpki/cli/**/*.rb"].each {|file| require file[4..-1] }

module DevPKI
  class DataDirectory

    def self.supported_operating_systems
     [:linux, :macosx]
    end

    def self.os
      @os ||= (
        host_os = RbConfig::CONFIG['host_os']
        case host_os
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
          :windows
        when /darwin|mac os/
          :macosx
        when /linux/
          :linux
        when /solaris|bsd/
          :unix
        else
          raise Error.new("unknown os: #{host_os.inspect}")
        end
      )
    end

    # Only support OSX atm
    def self.platform_supported?
      return self.supported_operating_systems.include?(self.os)
    end

    def self.reset_to_empty
      FileUtils.rm_rf(self.absolute_path)
      self.get
    end

    def self.absolute_path
      unexpanded = (case self.os
        when :linux
          File.join(XDG['DATA_HOME'].to_s, "devpki")
        when :macosx
          "~/Library/Application Support/devpki"
        else
          nil
      end)
      File.expand_path(unexpanded)
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