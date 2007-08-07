####################
#
# $LastChangedDate$
# $Rev$
# by $Author$ 

ActionController::Routing::Routes.draw do |map|
   # The priority is based upon order of creation: first created -> highest priority.

   # Sample of regular route:
   # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
   # Keep in mind you can assign values other than :controller and :action

   # Sample of named route:
   # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
   # This route can be invoked with purchase_url(:id => product.id)

   # You can have the root of your site routed by hooking up ''
   # -- just remember to delete public/index.html.
   # map.connect '', :controller => "welcome"

   # Allow downloading Web Service WSDL as a file with an extension
   # instead of a file named 'wsdl'
   #map.connect ':controller/service.wsdl', :action => 'wsdl'

   map.resources :users
   map.resource :session, :new => { :create_openid => :post,  :openid => :get }
   map.open_id_complete 'session/new;create_openid', :controller => "session", :action => "create_openid", :requirements => { :method => :get }

   map.resources :accounts, :new => { :auth => :get, :auth_finish => :get, :check_host => :get } do |accounts|
      accounts.resources :included_resources, :controller => 'resources'
   end

   map.resources :resources, :collection => { :map => :get, :timeline => :get, :ical => :get }

   map.resources :workers
   
   map.home '', :controller => 'resources', :action => 'index'
end

