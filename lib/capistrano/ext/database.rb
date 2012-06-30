require 'capistrano/ext/helpers'
require 'capistrano/ext/mysql'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/database requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
  namespace :db do
    ['credentials', 'root_credentials'].each do |method|
      desc "[internal] Print the database server #{method}"
      task "print_#{method}", :roles => :app do
        logger.trace format_credentials(fetch "db_#{method}".to_sym)
      end

      desc "[internal] Load the database server #{method}"
      task method, :roles => :app do
        return if exists?("db_#{method}".to_sym)

        if remote_file_exists?(fetch "db_#{method}_file".to_sym)
          send "read_#{method}"
        else
          send "generate_#{method}"
        end
      end

      desc "[internal] Read the database server #{method}"
      task "read_#{method}", :roles => :app do
        read(fetch "db_#{method}_file".to_sym).tap do |content|
          set "db_#{method}".to_sym, {
            hostname: match_from_content(content, method, 'host'),
            port:     match_from_content(content, method, 'port'),
            username: match_from_content(content, method, 'user'),
            password: match_from_content(content, method, 'pass'),
          }
        end
      end

      desc "[internal] Generate the database server #{method}"
      task "generate_#{method}", :roles => :app do

      end
    end
  end

  before 'db:print_credentials', 'db:credentials'
  before 'db:print_root_credentials', 'db:root_credentials'
end
