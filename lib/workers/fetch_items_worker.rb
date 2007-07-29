# Put your code that runs your task inside the do_work method it will be
# run automatically in a thread. You have access to all of your rails
# models.  You also get logger and results method inside of this class
# by default.
class FetchItemsWorker < BackgrounDRb::Worker::RailsBase

   def do_work( args = {} )
      @type = args[:type] ||= ''
      @user = args[:user] ||= '%'
      @sleep = 30.seconds
      results[:args] = args
      results[:stopped] = false
      results[:running] = true
      results[:last_run] = Time.now
      results[:account_type] = '?'
      results[:account_user] = '?'

      logger.info( "Worker #{@type} inited for #{@user} at #{Time.now}." )
      while results[:running] do
         fetch_items
         results[:sleep_cnt] = @sleep
         while( results[:sleep_cnt] > 0 && results[:running] ) do
            sleep 1
            results[:sleep_cnt] -= 1
         end
      end
      results[:stopped] = true
   end

   def fetch_items
      results[:processing] = true
      account = Account.find_to_update( @type, @user )
      if account
         logger.info("Updateing Account #{account.type} owned by #{account.user.login} at #{Time.now}." )
         results[:account_type] = account.type
         results[:account_user] = account.user.login
         account.daemon_fetch_items
      end
      results[:last_run] = Time.now
      results[:processing] = false
   end
end
FetchItemsWorker.register

