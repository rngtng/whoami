# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

f = File.join(File.dirname(__FILE__), 'config', 'boot')
require( f )if File.exist?( f ) 

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails' if defined?( RAILS_ROOT )

task :install_gems do
   #echo "Install vendor gems:"
   sh "gem install --include-dependencies feed-normalizer" 
   sh "gem install --include-dependencies rflickr" 
   sh "gem install --include-dependencies youtube" 
   sh "gem install --include-dependencies twitter4r"
   
   #echo "Install individual gems:"
   sh "svn co https://whoami.opendfki.de/repos/gems gems"
   
   #echo "Build gems:"
   sh "cd gems/delicious; gem build Rakefile; gem install mydelicious"
   sh "cd gems/lastfm; gem build Rakefile; gem install mylastfm"
   sh "cd gems/plazes; gem build Rakefile; gem install plazes"
end
