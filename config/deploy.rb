####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

# This defines a deployment "recipe" that you can feed to capistrano
# (http://manuals.rubyonrails.com/read/book/17). It allows you to automate
# (among other things) the deployment of your application.

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================
# You must always specify the application and repository for every recipe. The
# repository must be the URL of the repository you want this recipe to
# correspond to. The deploy_to path must be the path on each machine that will
# form the root of the application path.

set :application, "WhoAmI"
set :repository, "https://whoami.opendfki.de/repos/trunk/"


# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================


# set :scm, :darcs                      # defaults to :subversion
# set :svn, "/path/to/svn"              # defaults to searching the PATH
# set :darcs, "/path/to/darcs"          # defaults to searching the PATH
# set :cvs, "/path/to/cvs"              # defaults to searching the PATH
# set :gateway, "gate.host.com"         # default to no gateway


set :use_sudo, false

# =============================================================================
# SSH OPTIONS
# =============================================================================
# ssh_options[:keys] = %w(/path/to/my/key /path/to/another/key)
# ssh_options[:port] = 25

# =============================================================================
# TASKS
# =============================================================================
# Define tasks that run on all (or only some) of the machines. You can specify
# a role (or set of roles) that each task should be executed on. You can also
# narrow the set of servers to a subset of a role by specifying options, which
# must match the options given for the servers to select (like :primary => true)

#desc <<DESC
#An imaginary backup task. (Execute the 'show_tasks' task to display all available tasks.)
#DESC
#task :backup, :roles => :db, :only => { :primary => true } do
#   # the on_rollback handler is only executed if this task is executed within
#   # a transaction (see below), AND it or a subsequent task fails.
#   on_rollback { delete "/tmp/dump.sql" }
#
#   run "mysqldump -u theuser -p thedatabase > /tmp/dump.sql" do |ch, stream, out|
#      ch.send_data "thepassword\n" if out =~ /^Enter password:/
#   end
#end

# Tasks may take advanannotatione of several different helper methods to interact
# with the remote server(s). These are:
#
# * run(command, options={}, &block): execute the given command on all servers
#   associated with the current task, in parallel. The block, if given, should
#   accept three parameters: the communication channel, a symbol identifying the
#   type of stream (:err or :out), and the data. The block is invoked for all
#   output from the command, allowing you to inspect output and act
#   accordingly.
# * sudo(command, options={}, &block): same as run, but it executes the command
#   via sudo.
# * delete(path, options={}): deletes the given file or directory from all
#   associated servers. If :recursive => true is given in the options, the
#   delete uses "rm -rf" instead of "rm -f".
# * put(buffer, path, options={}): creates or overwrites a file at "path" on
#   all associated servers, populating it with the contents of "buffer". You
#   can specify :mode as an integer value, which will be used to set the mode
#   on the file.
# * render(template, options={}) or render(options={}): renders the given
#   template and returns a string. Alternatively, if the :template key is given,
#   it will be treated as the contents of the template to render. Any other keys
#   are treated as local variables, which are made available to the (ERb)
#   template.

#desc "Demonstrates the various helper methods available to recipes."
#task :helper_demo do
#   # "setup" is a standard task which sets up the directory structure on the
#   # remote servers. It is a good idea to run the "setup" task at least once
#   # at the beginning of your app's lifetime (it is non-destructive).
#   setup
#
#   buffer = render("maintenance.rhtml", :deadline => ENV['UNTIL'])
#   put buffer, "#{shared_path}/system/maintenance.html", :mode => 0644
#   sudo "killall -USR1 dispatch.fcgi"
#   run "#{release_path}/script/spin"
#   delete "#{shared_path}/system/maintenance.html"
#end

# You can use "transaction" to indicate that if any of the tasks within it fail,
# all should be rolled back (for each task that specifies an on_rollback
# handler).

 task :dfki do
   role :web, "pc-6433.kl.dfki.de"
   role :app, "pc-6433.kl.dfki.de"
   role :db,  "pc-6433.kl.dfki.de", :primary => true
   set :deploy_to,    "/home/whoami/public/"           # defaults to "/u/apps/#{application}"
   set :mongrel_conf, "/home/whoami/public/current/config/mongrel_cluster_dfki.yml"
   set :user,         "whoami"    # defaults to the currently logged in user
 end
 
 task :warteschlange do
   role :web, "whoami.warteschlange.de"
   role :app, "whoami.warteschlange.de"
   role :db,  "whoami.warteschlange.de", :primary => true
   set :deploy_to,    "/kunden/warteschlange.de/produktiv/rails/whoami/"           # defaults to "/u/apps/#{application}"
   set :mongrel_conf, "/kunden/warteschlange.de/produktiv/rails/whoami/current/config/mongrel_cluster.yml"
   set :user,         "ssh-21560-rails"    # defaults to the currently logged in user
 end


namespace :backgroundrb do
   desc "Start  backgroundrb"
   task :start, :roles => :app do
      #run "#{deploy_to}current/script/fetch_resources_daemon start -- -e production"
      run "#{deploy_to}current/script/backgroundrb start -- -r production"
   end

   desc "Stop backgroundrb"
   task :stop, :roles => :app do
      #run "#{deploy_to}current/script/fetch_resources_daemon stop -- -e production"
      run "#{deploy_to}current/script/backgroundrb stop -- -r production"
   end
end

namespace :deploy do
   task :copy_background, :roles => :app do
      run "cp -f #{release_path}/vendor/middleman_rails_init.rb  #{release_path}/vendor/plugins/backgroundrb/lib/middleman_rails_init.rb"
   end

   task :set_config, :roles => :app do
      run "mv -f #{release_path}/config/database_dfki.yml #{release_path}/config/database.yml"
      run "mv -f #{release_path}/config/api_keys_dfki.yml #{release_path}/config/api_keys.yml"
      run "mv -f #{release_path}/config/gmaps_api_key_dfki.yml #{release_path}/config/gmaps_api_key.yml"
   end
   
   task :restart, :roles => :web do
      
   end

   task :start, :roles => :web do
     run "mongrel_rails start -e production -d -n 3 -c #{deploy_to}current"
   end
   
   task :stop, :roles => :web do
     run "mongrel_rails stop -c #{deploy_to}current"
   end

end


after  'deploy:update_code', 'deploy:set_config'
after  'deploy:update_code', 'deploy:copy_background'

before 'deploy:stop',  'backgroundrb:stop'
after  'deploy:start', 'backgroundrb:start'

before  'deploy:restart', 'deploy:stop'
after   'deploy:restart', 'deploy:start'


before 'mongrel:cluster:restart',  'backgroundrb:stop'
after  'mongrel:cluster:restart',  'backgroundrb:start'

