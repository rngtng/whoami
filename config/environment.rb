####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

RAILS_GEM_VERSION = '2.3.4'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  
   config.action_controller.session = {
     :session_key => '_app_session',
     :secret      => '3c9a9ee9a412932113153ef594aaf44ae0aa966086038f3c34834af92d09ef1b504b953da4a768cd86d5ca3536c276fcb5ddf6cd462ab801be1f9ad489f0aca6'
   }
   
   config.action_controller.session_store = :active_record_store
end