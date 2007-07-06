require 'capistrano/version'
load 'deploy' if respond_to?(:namespace) # cap2 differentiator

#load default data
load 'config/deploy'

#load server specific data
begin
   case server
   when 'dfki':
      load 'config/deploy_dfki'
   end
rescue NameError
   load 'config/deploy_default'
end

