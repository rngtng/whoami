# Put your code that runs your task inside the do_work method it will be
# run automatically in a thread. You have access to all of your rails
# models.  You also get logger and results method inside of this class
# by default.

class FetchResourcesWorker < BackgrounDRb::MetaWorker
   set_worker_name :fetch_resources_worker
   set_no_auto_load true

   DEFAULT_USER = ''
   DEFAULT_TYPE = ''
   DEFAULT_SLEEP = 10.seconds

   def create( args = {} )
      args ||= {}	   
      logger.info "Started" 
      set_type  ( args[:type]  && Account.types.include?(   args[:type] ) ) ? args[:type]       : DEFAULT_USER
      set_user  ( args[:user]  && User.all_logins.include?( args[:user] ) ) ? args[:user]       : DEFAULT_TYPE
      set_sleep ( args[:sleep] && args[:sleep].to_i > 3                   ) ? args[:sleep].to_i : DEFAULT_SLEEP
      set_last_run Time.now
      set_processing false
      set_stopped false
      wlog "Inited worker #{get_type} for #{get_user}"
      update
      fetch_resources
   end

   def fetch_resources
      set_processing true
      update
      account = Account.find_to_update( get_type, get_user )
      if account
         wlog "Updateing Account #{account.type} owned by #{account.user.login}"
         set_account_type account.type
         set_account_user account.user.login
         update
         # account.worker_fetch_resources
      end
      sleep 10
      set_last_run Time.now
      set_processing false
      update
      add_timer( get_sleep ) { fetch_resources } unless get_stopped
   end

   def worker_stop
      wlog "stopped"
      set_stopped true
      update
      logger.info "stopped"
   end

   def method_missing(name, *args)
      @status ||= {}
      @status[:log] ||= []
      str_name = name.to_s
      if str_name =~ /^set_(.*)/
         raise ArgumentError( "Only 1 argument is allowed on set_ methods" ) if args.length != 1
         return  @status[$1.to_sym] = args[0]
      end
      return @status[$1.to_sym] if str_name =~ /^get_(.*)/
      return @status[:log] << args[0] if str_name =~ /^(wlog)/
      return register_status( @status ) if str_name =~ /^update/
      return super( name, args)
   end


end

