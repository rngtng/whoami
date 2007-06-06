#!/usr/bin/env ruby

####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

require 'optiflag'

module Daemon extend OptiFlagSet
   optional_flag "user" do
      description "Username whom Accounts should be checked"
      alternate_forms "u"
      default '%'
   end
   optional_flag "sleep" do
      description "Time in seconds how long Daemon should sleep"
      alternate_forms "s"
      default 60
   end

   optional_flag "env" do
      description "Rails environment"
      value_in_set ["development","production"]
      alternate_forms "e"
      default "development"
   end

   optional_flag "type" do
      description "Account type to check"
      alternate_forms "t"
      #value_in_set ["Blog","Flickr","Youtube","Lastfm","Twitter","Flickr","Delicious","Feed"]
      default ""
   end

   usage_flag "h","help","?"

   and_process!
end

#You might want to change this
ENV["RAILS_ENV"] = ARGV.flags.env

require File.dirname(__FILE__) + "/../../config/environment"

$running = true;
Signal.trap("TERM") do
   $running = false
end

type = ARGV.flags.type
user = ARGV.flags.user
seconds = ARGV.flags.sleep

ActiveRecord::Base.logger << "##################################################################\n"
ActiveRecord::Base.logger << "Starting #{type} Deamon for #{user} with #{seconds} seconds sleep.\n"

while($running) do
   f = Account.find_to_update( type, user )
   if f
      ActiveRecord::Base.logger << "Updateing Account #{f.type} owned by #{f.user.login} at #{Time.now}.\n"
      # f.daemon_fetch_items
   end
   sleep seconds
end
