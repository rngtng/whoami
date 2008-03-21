####################
#
# $LastChangedDate: 2007-06-16 13:00:33 +0200 (Sat, 16 Jun 2007) $
# $Rev: 52 $
# by $Author: bielohla $

class WorkersController < ApplicationController
   before_filter :backgroundrb_runs?

   def index
      return render( :partial => "worker", :collection => @workers ) if request.xhr?  
   end


   def show
      # daemon :status
   end

   def new
   end

   def create
      params[:user] = params[:user].first if params[:user].is_a? Array
      params[:type] = params[:type].first if params[:type].is_a? Array
      params[:key] = "key#{Time.now.to_i}"  if params[:key].nil? || params[:key].empty?

      MiddleMan.new_worker(
      :worker => :fetch_resources_worker,
      :job_key => params[:key],
      :data => params )
      redirect_to workers_path
   end

   def destroy
      MiddleMan.delete_worker(:worker => :fetch_resources_worker, :job_key => params[:id] ) if params[:id]
      #MiddleMan.ask_work( :worker => :fetch_resources_worker, :job_key => $1.to_sym, :worker_method => :worker_stop) if params[:id] =~ /_(key.*)$/
      redirect_to workers_path
   end

   private
   def backgroundrb_runs?
      begin
         @workers = MiddleMan.query_all_workers
         @workers.delete :log_worker
      rescue
         render( :action => 'not_running', :layout => 'layouts/workers' )
      end
   end
end

