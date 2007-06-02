#!/usr/bin/env ruby

#You might want to change this
ENV["RAILS_ENV"] ||= "development"

require File.dirname(__FILE__) + "/../../config/environment"

$running = true;
Signal.trap("TERM") do 
  $running = false
end

seconds = 60 #in seconds
type  = ''
user = '%' #any user

ARGV.each do |p|
   seconds = p.to_i if p.to_i > 0 #if integer it must be sleeptime
   type    = p if type.empty? && p.to_i < 1 #if string it must be type
   user    = p if p != type && p.to_i < 1 #if string it must be type
end
ActiveRecord::Base.logger << "##################################################################\n"
ActiveRecord::Base.logger << "Starting #{type} Deamon for #{user} with #{seconds} seconds sleep.\n"

while($running) do
  f = Account.find_to_update( type, user )
  if f
    ActiveRecord::Base.logger << "Updateing Account #{f.type} owned by #{f.user.name} at #{Time.now}.\n"
    f.daemon_fetch_items
  end  
  sleep seconds
end