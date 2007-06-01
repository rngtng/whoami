# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

task :install_gems do
   #echo "Install vendor gems:"
   sh "gem install feed-normalizer" 
   sh "gem install rflickr" 
   sh "gem install youtube" 
   sh "gem install twitter4r"
   
   #echo "Install individual gems:"
   sh "svn co https://whoami.opendfki.de/repos/gems gems"
   
   #echo "Build gems:"
   sh "cd gems/delicious"
   sh "gem build Rakefile" 
   sh "gem install mydelicious"
   sh "cd ../lastfm"
   sh "gem build Rakefile" 
   sh "gem install mylastfm"
   sh "cd ../plazes"
   sh "gem build Rakefile" 
   sh "gem install plazes"
end
