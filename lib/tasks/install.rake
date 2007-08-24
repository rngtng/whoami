namespace :install do
   desc "Install rails"
   task :rails do
      sh "gem install --include-dependencies rails"
   end

   desc "Install deploy gems"
   task :deploy_gems do
      sh "gem install --include-dependencies termios"
      #sh "gem install --include-dependencies capistrano"
      sh "gem install --include-dependencies -s http://gems.rubyonrails.org capistrano" #capsitrano 2.0
      sh "gem install --include-dependencies mongrel"
      sh "gem install --include-dependencies mongrel_cluster"
   end

   desc "Install vendor gems"
   task :vendor_gems do
      sh "gem install --include-dependencies feed-normalizer"
      sh "gem install --include-dependencies youtube"
      sh "gem install --include-dependencies twitter4r"
      sh "gem install --include-dependencies rflickr"
      sh "gem install --include-dependencies daemons"
      sh "gem install --include-dependencies slave"
      sh "gem install --include-dependencies ruby-openid"
      sh "gem install --include-dependencies icalendar"
      puts ""
      puts "#######################################################"
      puts "####  WARNING: rFlickr 2006.02.01   has a bug!     ####"
      puts "#######################################################"
      puts ""
      puts "to fix it, go to:"
      puts "  YOURGEMREPOS/gems/rflickr-2006.02.01/lib/flickr/base.rb"
      puts " and change line 644: def from_xml(xml,photo=nil)"
      puts " to  def self.from_xml(xml,photo=nil)"
      puts ""
      puts ""
      puts "to get rid of the xmlsimple warnings go to:"
      puts "  YOURGEMREPOS/gems/youtube-XXXX/lib/youtube.rb"
      puts " and change line 26: require 'xmlsimple'"
      puts " to require 'xmlsimple' unless defined? XmlSimple"
   end

   desc "Install individual gems"
   task :my_gems do
      puts "Install individual gems:"
      sh "svn co https://whoami.opendfki.de/repos/gems gems"
      puts "Build gems:"
      sh "cd gems/delicious; gem build Rakefile; gem install mydelicious"
      sh "cd gems/lastfm; gem build Rakefile; gem install mylastfm"
      sh "cd gems/plazes; gem build Rakefile; gem install plazes"
   end

   desc "Install whoami source"
   task :whoami do
      sh "svn co https://whoami.opendfki.de/repos/trunk whoami"
   end

   desc "Install all gems"
   task :gems do
      install:vendor_gems
      install:my_gems
   end

   desc "Install everything needed"
   task :all do
      install:vendor_gems
      install:my_gems
      install:whoami
   end
end
