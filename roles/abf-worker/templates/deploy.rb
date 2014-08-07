require 'cape'
require 'capistrano_colors'

set :rvm_ruby_string, '{{ ruby_version }}@abf-worker'
require 'rvm/capistrano'
require 'bundler/capistrano'

require 'capistrano/ext/multistage'
set :stages, %w(production) # auto readed
set :default_stage, "production"

# main details
# ssh_options[:forward_agent] = true
# default_run_options[:pty] = true

set :env, ENV['ENV'] || 'production'

set :application, "abf-worker"
set(:deploy_to) { "/home/{{ user }}/#{application}" }
set :user, "{{ user }}"
set :use_sudo, false
set :keep_releases, 3

set :scm, :git
# set :repository,  "git@195.19.76.241:abf/abf-worker.git"
# set :repository,  "git@abf.rosalinux.ru:abf/abf-worker-lxc.git"
# set :repository,  "rosa@abf.rosalinux.ru:/mnt/gitstore/git_projects/abf/abf-worker-lxc.git"
set :repository,  "{{ repo }}"
# set :deploy_via,  :remote_cache
set :deploy_via, :copy

set :workers_count, 2

set :rvm_install_ruby_threads, 1


before "deploy:setup",        "deploy:init"

after "deploy:update",        "deploy:init_keys"
after "deploy:update",        "deploy:symlink_all"
after "deploy:update",        "rake_tasks:abf_worker:init_boxes"

before "deploy:stop",         "god:terminate_if_running"

after "deploy:stop",          "resque:stop_workers"
after "deploy:stop",          "rake_tasks:abf_worker:stop"
after "deploy:stop",          "rake_tasks:abf_worker:clean_up"
after "deploy:update",        "rake_tasks:abf_worker:clean_up"
after "deploy:restart",       "deploy:cleanup"
# after "deploy:rpm",           'notify_rollbar'


namespace :god do
  def god_is_running
    !capture("#{god_command} status >/dev/null 2>/dev/null || echo 'not running'").start_with?('not running')
  end

  desc "Stop god"
  task :terminate_if_running do
    run "#{god_command} terminate" if god_is_running
  end
end

# task :notify_rollbar, :roles => :app do
#   set :revision, `git log -n 1 --pretty=format:"%H"`
#   set :local_user, `whoami`
#   set :rollbar_token, '271331c166dd4baab27108be6fceb9fd'
#   rails_env = fetch(:rails_env, 'production')
#   run "curl https://api.rollbar.com/api/1/deploy/ -F access_token=#{rollbar_token} -F environment=#{rails_env} -F revision=#{revision} -F local_username=#{local_user} >/dev/null 2>&1", :once => true
# end

namespace :deploy do

  task :init do
  end

  task :init_keys do
    run "cd #{fetch :current_path} && chmod 600 keys/vagrant"
  end

  task :symlink_all do
    run "mkdir -p #{fetch :shared_path}/config"

    # Setup DB, application, newrelic resque
    %w(application vm resque).each do |config|
      run "cp -n #{fetch :release_path}/config/#{config}.yml.sample #{fetch :shared_path}/config/#{config}.yml"
      run "ln -nfs #{fetch :shared_path}/config/#{config}.yml #{fetch :release_path}/config/#{config}.yml"
    end

    run "ln -s #{fetch :shared_path}/pids #{fetch :release_path}/pids"
    if fetch(:update_vm_yml)
      run "cp -f #{fetch :release_path}/config/vm.yml.sample #{fetch :shared_path}/config/vm.yml"
    end

    run "cp -f #{fetch :release_path}/config/restart.sh #{fetch :shared_path}/config/restart.sh"
  end

  task :iso, :roles => :iso do 
    run_worker_with_params({
      :INTERVAL => 5,
      :COUNT    => 4,
      :QUEUE    => 'iso_worker',
      :GROUP    => 'iso'
    })
  end

  task :publish, :roles => :publish do
    queue = 'publish_worker'
    run_worker_with_params({
      :INTERVAL => 5,
      :COUNT    => 4,
      :QUEUE    => "#{queue}_default,#{queue}",
      :GROUP    => 'publish'
    })
  end

  task :rpm, :roles => :rpm do
    queue = 'rpm_worker'
    run_worker_with_params({
      :INTERVAL => 5,
      :COUNT    => 1,
      :QUEUE    => "#{queue}_default,#{queue}",
      :GROUP    => 'rpm'
    }, 'abf-worker.god')
  end

end

namespace :resque do
  task :stop_workers do
    ps = 'ps aux | grep resque | grep -v grep'
    run "#{ps} && kill -QUIT `#{ps} | awk '{ print $2 }'` || echo 'Workers already stopped!'"
    # run "#{ps} && kill -9 `#{ps} | awk '{ print $2 }'` || echo 'Workers already stopped!'"
    # run "cd #{fetch :current_path} && #{current_env} bundle exec rake resque:stop_workers"
  end
end

namespace :rake_tasks do
  Cape do
    %w(clean_up init_boxes stop).each do |task|
      mirror_rake_tasks "abf_worker:#{task}" do |recipes|
        recipes.env['ENV'] = fetch(:env)
      end
    end
  end
end

def run_worker_with_params(params, config = 'resque.god')
  config_file = "#{fetch :current_path}/config/#{config}"
  run "#{god_command} -c #{config_file}", :env => worker_params(params)
end

def worker_params(params)
  {
    :VAGRANT_DEFAULT_PROVIDER => 'lxc',
    :RESQUE_TERM_TIMEOUT      => 600,
    :TERM_CHILD               => 1,
    :ENV                      => fetch(:env),
    :CURRENT_PATH             => fetch(:current_path),
    :BACKGROUND               => 'yes'
  }.merge(params)
end

def god_command
  "cd #{fetch :current_path} && rvm #{fetch :rvm_ruby_string} exec bundle exec god"
end