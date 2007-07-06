# =============================================================================
# ROLES
# =============================================================================
# You can define any number of roles, each of which contains any number of
# machines. Roles might include such things as :web, or :app, or :db, defining
# what the purpose of each machine is. You can also specify options that can
# be used to single out a specific subset of boxes in a particular role, like
# :primary => true.

#### Warteschlange
role :web, "whoami.warteschlange.de"
role :app, "whoami.warteschlange.de"
role :db,  "whoami.warteschlange.de", :primary => true
set :deploy_to,    "/kunden/warteschlange.de/produktiv/rails/whoami/"           # defaults to "/u/apps/#{application}"
set :mongrel_conf, "/kunden/warteschlange.de/produktiv/rails/whoami/current/config/mongrel_cluster.yml"
set :user,         "ssh-21560-rails"    # defaults to the currently logged in user
