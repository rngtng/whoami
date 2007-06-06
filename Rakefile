####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

f = File.join(File.dirname(__FILE__), 'config', 'boot')
require( f ) #if File.exist?( f )

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails' #if defined?( RAILS_ROOT ) <- doesn't work?!

task :install_rails do
   sh "gem install --include-dependencies rails"
end

task :install_deploy_gems do
   sh "gem install --include-dependencies termios"
   sh "gem install --include-dependencies capistrano"
   sh "gem install --include-dependencies mongrel"
   sh "gem install --include-dependencies mongrel_cluster"
end

task :install_vendor_gems do
   sh "gem install --include-dependencies feed-normalizer"
   sh "gem install --include-dependencies youtube"
   sh "gem install --include-dependencies twitter4r"
   sh "gem install --include-dependencies rflickr"
   sh "gem install --include-dependencies daemons"
   sh "gem install --include-dependencies optiflag"
   sh "gem install --include-dependencies ruby-openid"
   put  ""
   puts "#######################################################"
   puts "####  WARNING: rFlickr 2006.02.01   has a bug!     ####"
   puts "#######################################################"
   put  ""
   puts "to fix it, go to:"
   puts "  YOURGEMREPOS/gems/rflickr-2006.02.01/lib/flickr/base.rb"
   puts " and change line 644: def from_xml(xml,photo=nil)"
   puts " to  def self.from_xml(xml,photo=nil)"
   put  ""
   put  ""
   put  "to get rid of the xmlsimple warnings go to:"
   puts "  YOURGEMREPOS/gems/youtube-XXXX/lib/youtube.rb"
   put  " and change line 26: require 'xmlsimple'"
   put  " to require 'xmlsimple' unless defined? XmlSimple"
end

task :install_my_gems do
   puts "Install individual gems:"
   sh "svn co https://whoami.opendfki.de/repos/gems gems"
   puts "Build gems:"
   sh "cd gems/delicious; gem build Rakefile; gem install mydelicious"
   sh "cd gems/lastfm; gem build Rakefile; gem install mylastfm"
   sh "cd gems/plazes; gem build Rakefile; gem install plazes"
end

task :install_gems do
   install_vendor_gems
   install_my_gems
end

task :cleanup_gems do
   sh "gem cleanup"
end

task :outdated_gems do
   sh "gem outdated"
end

task :update_gems do
   sh "gem update"
end

