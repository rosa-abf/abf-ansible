require 'capistrano_colors'

require 'rvm/capistrano'
require 'bundler/capistrano'

# main details
# ssh_options[:forward_agent] = true
# default_run_options[:pty] = true

set :application, "file_store"
set :rvm_ruby_string, '{{ ruby_version }}@rosa-file-store'
set(:deploy_to) { "{{ deploy_to }}" }
set :user, "{{ user }}"
set :use_sudo, false
set :keep_releases, 3

set :domain, "localhost"
# set :port, 22
# set :domain, "185.4.234.68" # st1
role :app, domain
role :web, domain
role :db,  domain, :primary => true

set :scm, :git
# set :deploy_via, :remote_cache
set :deploy_via, :copy
set :copy_dir, "/home/{{ user }}/tmp"
# set :repository, "git@github.com:warpc/rosa-file-store.git"
set :repository, "{{ repo }}"
set :branch, "{{ branch }}"

namespace :deploy do
  set :unicorn_binary, "bundle exec unicorn"
  set(:unicorn_pid) { "#{fetch :shared_path}/pids/unicorn.pid" }

  task :start, :roles => :app, :except => { :no_release => true } do 
    run "cd #{fetch :current_path} && #{try_sudo} #{unicorn_binary} -l /tmp/#{fetch :application}_unicorn.sock -E production -c config/unicorn.rb -D" # -p #{unicorn_port}
  end
  task :stop, :roles => :app, :except => { :no_release => true } do 
    run "#{try_sudo} kill `cat #{unicorn_pid}`" rescue warn 'deploy:stop FAILED'
  end
  task :graceful_stop, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} kill -QUIT `cat #{unicorn_pid}`" rescue warn 'deploy:graceful_stop FAILED'
  end
  task :reload, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} kill -USR2 `cat #{unicorn_pid}`" rescue warn 'deploy:reload FAILED'
  end
  task :restart, :roles => :app, :except => { :no_release => true } do
    reload
  end

  task :symlink_all, :roles => :app do
    run "mkdir -p #{fetch :shared_path}/config"

    # Setup DB, application
    %w(database application).each do |config|
      run "cp -n #{fetch :release_path}/config/#{config}.yml.sample #{fetch :shared_path}/config/#{config}.yml"
      run "ln -nfs #{fetch :shared_path}/config/#{config}.yml #{fetch :release_path}/config/#{config}.yml"
    end

    # It will survive uploads folder between deployments
    # run "mkdir -p #{fetch :shared_path}/uploads"
    # run "ln -nfs #{fetch :shared_path}/uploads/ #{fetch :release_path}/uploads"
    run "ln -nfs {{ upload_store }}/uploads/ #{fetch :release_path}/uploads"
  end

  task :symlink_pids, :roles => :app do
    run "cd #{fetch :shared_path}/tmp && ln -nfs ../pids pids"
  end
end

after "deploy:finalize_update", "deploy:symlink_all"
after "deploy:update_code", "deploy:migrate"
after "deploy:setup", "deploy:symlink_pids"

# if you want to clean up old releases on each deploy uncomment this:
after "deploy:restart", "deploy:cleanup"
