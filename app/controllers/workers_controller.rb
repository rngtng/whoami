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
      respond_to do |format|  #strange bug: fromat.html must be first in row in case format is not given!?
         format.html
         format.js { render :partial => "worker", :collection => @workers }
      end
   end


   def show
     # daemon :status
   end

   def new
   end

   def create
      params[:user] = params[:user].first if params[:user].is_a? Array
      params[:type] = params[:type].first if params[:type].is_a? Array
      params[:key] = "w#{Time.now.to_i}"  if params[:key].nil? || params[:key].empty?
      MiddleMan.new_worker( { :class => :fetch_resources_worker, :job_key => params.delete( "key" ), :args => params } )

      #opt[:worker_method] = :fetch_resources
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

