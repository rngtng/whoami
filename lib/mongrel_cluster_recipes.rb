Capistrano::Configuration.instance(:must_exist).load do
  depend :remote, :gem, "mongrel_cluster", ">=0.2.1"
  after "deploy:setup", "mongrel:cluster:setup"
  
  set(:mongrel_servers, 1)
  set(:mongrel_port) { abort 'Please configure the mongrel_port variable before deploying' }
  set(:mongrel_address, "127.0.0.1")
  set(:mongrel_environment, "production")
  set(:mongrel_user) { user }
  set(:mongrel_group) { user }
  set(:mongrel_prefix, nil)
  set(:mongrel_conf) { File.join(shared_path, 'config', 'mongrel_cluster.yml') }

  namespace :mongrel do
    namespace :cluster do
      desc <<-DESC
      Configure Mongrel processes on the app server. This uses the :use_sudo
      variable to determine whether to use sudo or not. By default, :use_sudo is
      set to true.
      DESC
      task :setup, :roles => :app do
        argv = []
        argv << "mongrel_rails cluster::configure"
        argv << "-N #{mongrel_servers.to_s}"
        argv << "-p #{mongrel_port.to_s}"
        argv << "-e #{mongrel_environment}"
        argv << "-a #{mongrel_address}"
        argv << "-c #{current_path}"
        argv << "-C #{mongrel_conf}"
        argv << "--user #{mongrel_user}" if mongrel_user
        argv << "--group #{mongrel_group}" if mongrel_group
        argv << "--prefix #{mongrel_prefix}" if mongrel_prefix
        cmd = argv.join " "
        run "mkdir -p #{File.dirname(mongrel_conf)}"
        run cmd
      end
      
      desc <<-DESC
      Start Mongrel processes on the app server.  This uses the :use_sudo variable to determine whether to use sudo or not. By default, :use_sudo is
      set to true.
      DESC
      task :start, :roles => :app do
        run "mongrel_rails cluster::start -C #{mongrel_conf}"
      end
      
      desc <<-DESC
      Restart the Mongrel processes on the app server by starting and stopping the cluster. This uses the :use_sudo
      variable to determine whether to use sudo or not. By default, :use_sudo is set to true.
      DESC
      task :restart, :roles => :app do
        run "mongrel_rails cluster::restart -C #{mongrel_conf}"
      end
      
      desc <<-DESC
      Stop the Mongrel processes on the app server.  This uses the :use_sudo
      variable to determine whether to use sudo or not. By default, :use_sudo is
      set to true.
      DESC
      task :stop, :roles => :app do
        run "mongrel_rails cluster::stop -C #{mongrel_conf}"
      end
    end
  end
  
  namespace :deploy do
    desc <<-DESC
    Start the Mongrel processes on the app server by calling mongrel:cluster:start
    DESC
    task :start, :roles => :app do
      mongrel.cluster.start
    end
    
    desc <<-DESC
    Restart the Mongrel processes on the app server by calling mongrel:cluster:restart
    DESC
    task :restart, :roles => :app do
      mongrel.cluster.restart
    end
  end
end
