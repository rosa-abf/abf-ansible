require 'cape'
require 'capistrano_colors'

set :default_environment, {
  'LANG' => 'en_US.UTF-8'
}

require 'rvm/capistrano'
require 'bundler/capistrano'
require 'new_relic/recipes'

set :whenever_command, "bundle exec whenever"

# main details
# ssh_options[:forward_agent] = true
# default_run_options[:pty] = true

set :application, "rosa_build"
set :rvm_ruby_string, '{{ ruby_version }}@rosa_build'
set(:deploy_to) { "{{ deploy_to }}" }
set :user, "{{ user }}"
set :use_sudo, false
set :keep_releases, 3
set :git_enable_submodules, 1

set :domain, "localhost"
role :app, domain
role :web, domain
role :db,  domain, :primary => true

set :scm, :git
# set :repository,  "git@github.com:rosa-abf/rosa-build.git"
set :repository,  "{{ repo }}"
set :branch, "{{ branch }}"
# set :deploy_via,  :remote_cache
set :deploy_via, :copy
set :copy_dir, "/home/{{ user }}/tmp"

# require './lib/recipes/nginx'
require 'puma/capistrano'
set :workers_count, 4
require './lib/recipes/resque'

# require './lib/recipes/skype'
# set :skype_topic, 'ABF' # Skype chat topic name

namespace :deploy do
  task :symlink_all, :roles => :app do
    run "mkdir -p #{fetch :shared_path}/config"

    # Setup DB, application, newrelic
    %w(database application newrelic).each do |config|
      run "cp -n #{fetch :release_path}/config/#{config}.yml.sample #{fetch :shared_path}/config/#{config}.yml"
      run "ln -nfs #{fetch :shared_path}/config/#{config}.yml #{fetch :release_path}/config/#{config}.yml"
    end

    # It will survive downloads folder between deployments
    run "mkdir -p #{fetch :shared_path}/downloads"
    run "ln -nfs #{fetch :shared_path}/downloads/ #{fetch :release_path}/public/downloads"

    # It will survive sitemaps folder between deployments
    run "mkdir -p #{fetch :shared_path}/sitemaps"
    run "ln -nfs #{fetch :shared_path}/sitemaps #{fetch :release_path}/public/sitemaps"
  end

  task :symlink_pids, :roles => :app do
    run "cd #{fetch :shared_path}/tmp && ln -nfs ../pids pids"
  end

end

after "deploy:finalize_update", "deploy:symlink_all"
after "deploy:update_code", "deploy:migrate"
after "deploy:setup", "deploy:symlink_pids"

# Resque
after "deploy:stop",    "resque:stop"
after "resque:stop",    "resque:scheduler:stop"

after "deploy:start",   "resque:start"
after "resque:start",    "resque:scheduler:start"

after "deploy:restart", "resque:restart"
after "resque:restart",    "resque:scheduler:restart"

after "deploy:restart", "deploy:cleanup"

namespace :rake_tasks do
  Cape do
    mirror_rake_tasks 'db:seeds'
  end
end

namespace :puma do
  desc 'Restart puma'
  task :restart, :roles => :app, :on_no_matching_servers => :continue do
    begin
      stop
    rescue Capistrano::CommandError => ex
      puts "Failed to restart puma: #{ex}\nAssuming not started."
    ensure
      start
    end
  end
end
