require 'devpki'
require 'thor'

Dir["lib/devpki/cli/*.rb"].each {|file| require file[4..-1] }