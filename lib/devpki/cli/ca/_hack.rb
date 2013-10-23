require 'devpki'

module DevPKI
  module SUBCLI
    class CA < Thor

      # Hack to override the help message produced by Thor.
      # https://github.com/wycats/thor/issues/261#issuecomment-16880836
      def self.banner(command, namespace = nil, subcommand = nil)
        "#{basename} ca #{command.usage}"
      end

    end
  end
end

