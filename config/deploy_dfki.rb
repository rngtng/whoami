# =============================================================================
# ROLES
# =============================================================================
# You can define any number of roles, each of which contains any number of
# machines. Roles might include such things as :web, or :app, or :db, defining
# what the purpose of each machine is. You can also specify options that can
# be used to single out a specific subset of boxes in a particular role, like
# :primary => true.

#### DFKI
#set :default_shell, "/usr/bin/tcsh"
role :web, "serv-4103.kl.dfki.de"
role :app, "serv-4103.kl.dfki.de"
role :db,  "serv-4103.kl.dfki.de", :primary => true
set :deploy_to,    "/home/bielohla/rails/whoami/"           # defaults to "/u/apps/#{application}"
set :mongrel_conf, "/home/bielohla/rails/whoami/current/config/mongrel_cluster_dfki.yml"
set :user,         "bielohla"    # defaults to the currently logged in user

namespace :deploy do
   task :set_config, :roles => :app do
      run "mv -f #{release_path}/config/database_dfki.yml #{release_path}/config/database.yml"
      run "mv -f #{release_path}/config/api_keys_dfki.yml #{release_path}/config/api_keys.yml"
      run "mv -f #{release_path}/config/gmaps_api_key_dfki.yml #{release_path}/config/gmaps_api_key.yml"
   end
end

after  'deploy:update_code', 'deploy:set_config'