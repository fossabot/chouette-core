require 'capistrano/ext/multistage'
require './config/boot'

set :stages, %w(sandbox dev staging production)
set :application, "stif-boiv"
set :scm, :git
set :repository,  "git@github.com:AF83/stif-boiv.git"
set :deploy_to, "/var/www/stif-boiv"
set :use_sudo, false
default_run_options[:pty] = true
set :group_writable, true
set :bundle_cmd, "/var/lib/gems/2.2.0/bin/bundle"
set :rake, "#{bundle_cmd} exec /var/lib/gems/2.2.0/bin/rake"

set :keep_releases, 5
after "deploy:update", "deploy:cleanup"

set :rails_env, -> { fetch(:stage) }
set :deploy_via, :remote_cache
set :copy_exclude, [ '.git' ]
ssh_options[:forward_agent] = true

require "bundler/capistrano"

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end

 # Prevent errors when chmod isn't allowed by server
  task :setup, :except => { :no_release => true } do
    dirs = [deploy_to, releases_path, shared_path]
    dirs += shared_children.map { |d| File.join(shared_path, d) }
    run "mkdir -p #{dirs.join(' ')} && (chmod g+w #{dirs.join(' ')} || true)"
  end

  task :bundle_link do
    run "ln -fs #{bundle_cmd} #{release_path}/script/bundle"
  end
  after "bundle:install", "deploy:bundle_link"

  desc "Symlinks shared configs and folders on each release"
  task :symlink_shared, :except => { :no_release => true }  do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/"
    run "ln -nfs #{shared_path}/config/environments/#{rails_env}.rb #{release_path}/config/environments/"
    run "ln -nfs #{shared_path}/config/secrets.yml #{release_path}/config/"
    run "ln -nfs #{shared_path}/config/newrelic.yml #{release_path}/config/"

    run "ln -nfs #{shared_path}/tmp/imports #{release_path}/tmp/imports"
  end
  after 'deploy:update_code', 'deploy:symlink_shared'
  before 'deploy:assets:precompile', 'deploy:symlink_shared'

  desc "Make group writable all deployed files"
  task :group_writable do
    run "sudo /usr/local/sbin/cap-fix-permissions /var/www/chouette2"
  end
  after "deploy:update", "deploy:group_writable"
end

namespace :delayed_job do
  task :restart do
    run "sudo /etc/init.d/stif-boiv restart"
  end
  # after "deploy:restart", "delayed_job:restart"
end
