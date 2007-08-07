# Put your code that runs your task inside the do_work method it will be
# run automatically in a thread. You have access to all of your rails
# models.  You also get logger and results method inside of this class
# by default.
class FetchResourcesWorker < BackgrounDRb::Worker::RailsBase

   def do_work( args = {} )
      @type  = Account.types.include?(   args[:type] ) ? args[:type] : ''
      @user  = User.all_logins.include?( args[:user] ) ? args[:user] : ''
      @sleep = args[:sleep].to_i > 3 ? args[:sleep].to_i : 10.seconds
      @log   = []
      results[:type] = @type
      results[:user] = @user
      results[:sleep] = @sleep
      results[:sleep_cnt] = @sleep
      results[:running] = true
      results[:stopped] = false
      results[:last_run] = Time.now
      results[:account_type] = ''
      results[:account_user] = ''

      log( "Inited worker #{@type} for #{@user}" )
      while results[:running] do
         begin
            #fetch_resources
         rescue Exception => e
            log( "Error: #{e}" )
         end
         do_sleep
      end
      results[:stopped] = true
      log( "Stopped worker #{@type} for #{@user}" )
   end

   def fetch_resources
      results[:processing] = true
      account = Account.find_to_update( @type, @user )
      if account
         log( "Updateing Account #{account.type} owned by #{account.user.login}" )
         results[:account_type] = account.type
         results[:account_user] = account.user.login
         account.worker_fetch_resources
      end
      results[:last_run] = Time.now
      results[:processing] = false
   end

   def do_sleep
      results[:sleep_cnt] = @sleep
      while( results[:sleep_cnt] > 0 && results[:running] ) do
         sleep 1
         results[:sleep_cnt] -= 1
      end
   end

   def log( msg )
      logger.info( msg )
      @log << msg
      results[:log] = @log 
   end
end
FetchResourcesWorker.register

