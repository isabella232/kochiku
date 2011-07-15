$:.unshift(File.expand_path('./lib', ENV['rvm_path'])) # Add RVM's lib directory to the load path.
require "rvm/capistrano"
set :rvm_type, :user
set :rvm_ruby_string, 'ree@kochiku'

require 'bundler/capistrano' # adds bundle:install step to deploy pipeline
require 'hoptoad_notifier/capistrano'

set :application, "Kochiku"
set :repository,  "git@git.squareup.com:square/kochiku.git"
set :branch, "master"
set :scm, :git
set :scm_command, '/usr/local/bin/git'

set :user, "square"
set :deploy_to, "/Users/square/kochiku"
set :deploy_via, :remote_cache
set :use_sudo, false

server "macbuild-master.sfo", :app, :web, :db, :primary => true
role :worker, "macbuild24.sfo", "macbuild25.sfo", "macbuild26.sfo"

set :rails_env,      "production"

after "deploy:setup", "kochiku:setup"
after "deploy:symlink", "kochiku:symlinks"

namespace :deploy do
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && rails server thin -e #{rails_env} -p 3000 -d"
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    @pid = nil
    run("cd #{current_path} && cat tmp/pids/server.pid") do |channel, stream, data|
      @pid = data if stream == :out
    end
    run "kill #{@pid}"
  end

  desc "Restart the web application server and all of the build slaves"
  task :restart do
    restart_app
    restart_workers
  end

  desc "Restart the web application server"
  task :restart_app, :roles => :app, :except => { :no_release => true } do
    stop
    start
  end

  desc "Restart the build slaves"
  task :restart_workers, :roles => :worker, :except => { :no_release => true } do
    # the trailing semicolons are required because this is passed to the shell as a single string
    run <<-CMD
      resque_parent_pid=$(ps x | grep -i 'resque-' | grep -iE 'Forked|Waiting' | grep -v grep | awk '{ print $1}');
      kill -QUIT $resque_parent_pid;

      while ps x | grep -q ^$resque_parent_pid; do
        echo "Waiting for Resque worker to stop on $HOSTNAME...";
        sleep 5;
      done;
    CMD
  end
end

namespace :kochiku do
  task :setup, :roles => [:app, :worker] do
    run "mkdir -p #{shared_path}/{build-partition,log_files}"
    run "[ -d #{shared_path}/build-partition/web-cache ] || #{scm_command} clone git@git.squareup.com:square/web.git #{shared_path}/build-partition/web-cache"
  end

  task :symlinks, :roles => [:app, :worker] do
    run "ln -nfFs #{shared_path}/build-partition #{current_path}/tmp/build-partition"
    run "ln -nfFs #{shared_path}/log_files #{current_path}/public/log_files"
  end
end
