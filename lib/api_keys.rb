####################
#
# $LastChangedDate: 2007-06-06 11:21:13 +0200 (Wed, 06 Jun 2007) $
# $Rev: 44 $
# by $Author: bielohla $

#Class fo the manipulation of the API keys
class ApiKeys
   #Read the API key config for the current ENV
   unless File.exist?(RAILS_ROOT + '/config/api_keys.yml')
      raise Exception.new("File RAILS_ROOT/config/api_keys.yml not found")
   else
      env = ENV['RAILS_ENV'] || RAILS_ENV
      API_KEYS = YAML.load_file(RAILS_ROOT + '/config/api_keys.yml')[env]
   end

   def self.get(options = {})
      raise Exception.new( "No apitype given") if options.empty?
      api = options.keys.first
      api_s = api.to_s
      raise Exception.new( "No api available") unless API_KEYS.has_key?(api_s)
      raise Exception.new( "No data available") unless API_KEYS[api_s].has_key?(options[api].to_s)
      API_KEYS[api_s][options[api].to_s]
   end
end

