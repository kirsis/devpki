require "devpki/version"

module DevPKI
  autoload :CLI, 'devpki/cli'

  class DevPKIError < StandardError
    def self.status_code(code)
      define_method(:status_code) { code }
    end
  end

  class InvalidOption < DevPKIError; status_code(10) ; end
  class CADBError < DevPKIError; status_code(11) ; end
end
