####################
#
# $LastChangedDate: 2007-06-16 13:00:33 +0200 (Sat, 16 Jun 2007) $
# $Rev: 52 $
# by $Author: bielohla $

class WorkersController < ApplicationController
   before_filter :backgroundrb_runs?

   def index
      @workers = running_workers
      @timestamps = MiddleMan.timestamps
      render( :layout => 'layouts/workers' )
   end


   def show
      daemon :status
      render( :layout => 'layouts/workers' )
   end

   def new
   end

   def create
      args = {}
      params[:user] = '%' if params[:user].nil?
      params[:type] = ''  if params[:type].nil?
      params[:sleep] = 10 if params[:sleep].empty?
      args[:user] =  params[:user]
      args[:type] =  params[:type]
      args[:sleep] =  params[:sleep]
      opt = {}
      opt[:job_key] = params[:key] unless params[:key].empty?
      opt[:class]   = :fetch_items_worker
      opt[:args]    = args
      MiddleMan.new_worker( opt )

      #opt[:worker_method] = :fetch_items
      #opt[:trigger_args] = { :repeat_interval => 45.seconds  }
      #MiddleMan.schedule_worker( opt )
      redirect_to workers_path
   end

   def destroy
      MiddleMan.worker(params[:id]).results[:running] = false
      redirect_to workers_path
   end

   private
   def backgroundrb_runs?
      begin
         @jobs = MiddleMan.jobs
      rescue
         render( :action => 'not_running', :layout => 'layouts/workers' )
      end
   end

   def running_workers
      workers = {}
      @jobs.each do |job|
         key = job.first
         next if key == :backgroundrb_results
         next if key == :backgroundrb_logger
         workers[key] = MiddleMan.worker( key )
         MiddleMan.delete_worker( key ) if workers[key].results[:stopped]
      end
      workers
   end
end

