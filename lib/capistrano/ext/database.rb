require 'capistrano/ext/mysql'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/database requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
  namespace :db do
    task :credentials, :roles => :app do
      db_server_app = fetch :db_server_app

      case db_server_app
      when 'mysql'
        find_and_execute_task 'db:mysql:credentials'
      else
        abort "The database server #{db_server_app} is not supported"
      end
    end
  end
end
