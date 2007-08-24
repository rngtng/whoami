####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

module AuthenticatedTestHelper
   # Sets the current user in the session from the user fixtures.
   def login_as(user)
      @request.session[:user] = user ? users(user).id : nil
   end

   def authorize_as(user)
      @request.env["HTTP_AUTHORIZATION"] = user ? "Basic #{Base64.encode64("#{users(user).login}:test")}" : nil
   end

   # taken from edge rails / rails 2.0.  Only needed on Rails 1.2.3
   def assert_difference(expressions, difference = 1, message = nil, &block)
      expression_evaluations = [expressions].flatten.collect{|expression| lambda { eval(expression, block.binding) } }

      original_values = expression_evaluations.inject([]) { |memo, expression| memo << expression.call }
      yield
      expression_evaluations.each_with_index do |expression, i|
         assert_equal original_values[i] + difference, expression.call, message
      end
   end

   # taken from edge rails / rails 2.0.  Only needed on Rails 1.2.3
   def assert_no_difference(expressions, message = nil, &block)
      assert_difference expressions, 0, message, &block
   end
end

#module AuthenticatedTestHelper
#
#   # Assert the block redirects to the login
#   #
#   #   assert_requires_login(:bob) { |c| c.get :edit, :id => 1 }
#   #
#   def assert_requires_login(login = nil)
#      yield HttpLoginProxy.new(self, login)
#   end
#
#   def assert_http_authentication_required(login = nil)
#      yield XmlLoginProxy.new(self, login)
#   end
#
#   def reset!(*instance_vars)
#      instance_vars = [:controller, :request, :response] unless instance_vars.any?
#      instance_vars.collect! { |v| "@#{v}".to_sym }
#      instance_vars.each do |var|
#         instance_variable_set(var, instance_variable_get(var).class.new)
#      end
#   end
#end
#
#class BaseLoginProxy
#   attr_reader :controller
#   attr_reader :options
#   def initialize(controller, login)
#      @controller = controller
#      @login      = login
#   end
#
#   private
#   def authenticated
#      raise NotImplementedError
#   end
#
#   def check
#      raise NotImplementedError
#   end
#
#   def method_missing(method, *args)
#      @controller.reset!
#      authenticate
#      @controller.send(method, *args)
#      check
#   end
#end
#
#class HttpLoginProxy < BaseLoginProxy
#   protected
#   def authenticate
#      @controller.login_as @login if @login
#   end
#
#   def check
#      @controller.assert_redirected_to :controller => 'sessions', :action => 'new'
#   end
#end
#
#class XmlLoginProxy < BaseLoginProxy
#   protected
#   def authenticate
#      @controller.accept 'application/xml'
#      @controller.authorize_as @login if @login
#   end
#
#   def check
#      @controller.assert_response 401
#   end
#end
#

