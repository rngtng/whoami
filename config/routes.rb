####################
#
# $LastChangedDate$
# $Rev$
# by $Author$ 

ActionController::Routing::Routes.draw do |map|

   map.home2 '', :controller => 'resources', :action => 'index', :username => ''
   map.home '/users/:username', :controller => 'resources', :action => 'index'
   
   map.signup '/signup', :controller => 'users',   :action => 'new'
   map.login  '/login',  :controller => 'session', :action => 'new'
   map.logout '/logout', :controller => 'session', :action => 'destroy'
   
   map.open_id_complete 'session', :controller => "session", :action => "create", :requirements => { :method => :get }
   
   map.resources :users
   map.resource :session, :controller => 'session'

   map.resources :accounts, :path_prefix => '/users/:username', :new => { :auth => :get, :auth_finish => :get, :check_host => :get } do |accounts|
      accounts.resources :resources, :path_prefix => '/users/:username/accounts', :controller => 'resources'
   end

   map.resources :resources, :path_prefix => '/users/:username',  :collection => { :map => :get, :timeline => :get, :cluster => :get, :ical => :get }

   map.resources :workers

end

