require 'devpki'

module DevPKI
  class CA
    def self.init(id=0, name=nil, parent_ca_id=nil)
      puts "Initializing CA ##{id}"
    end
  end
end