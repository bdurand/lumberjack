require 'couchrest'
require 'zucker/extensions'

module Lumberjack
  class Device
    class Couchdb < Device

	attr_reader :db

	def initialize(url,options = {})
	  server = CouchRest.new(url)
	  @db = server.database!(options[:db]) 	
	end

	def write(entry)
	 hash = entry.instance_variables.mash {|v| [v[1..-1],entry.instance_variable_get(v)]}
       @db.save_doc(hash)  		
	end
    end
  end
end
