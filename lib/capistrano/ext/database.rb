require 'capistrano/ext/helpers'
require 'capistrano/ext/mysql'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/database requires Capistrano 2"
end

Capistrano::Configuration.instance(:must_exist).load do

  set :db_credentials_host_regex,            /hostname: (.*)$/o
  set :db_credentials_host_regex_match,      1
  set :db_credentials_port_regex,            /port: (.*)$/o
  set :db_credentials_port_regex_match,      1
  set :db_credentials_user_regex,            /username: (.*)$/o
  set :db_credentials_user_regex_match,      1

  namespace :db do
    desc 'Backup the database'
    task :backup, :roles => :db do
      set :latest_backup,
        "#{fetch :backup_path}/#{fetch :db_database_name}_#{Time.now.strftime('%d-%m-%Y_%H-%M-%S')}.sql"
      transaction do
        find_and_execute_db_task :backup
      end
    end

    desc 'Export the database'
    task :export, :roles => :db do
      transaction do
        backup
        download_backup
      end
    end

    desc 'Import the database'
    task :import, :roles => :db do
      transaction do
        backup
        backup_skiped_tables  if exists_and_not_empty? :skip_tables_on_import
        find_and_execute_db_task :import
        restore_skiped_tables if exists_and_not_empty? :skip_tables_on_import
      end
    end

    [:credentials, :root_credentials].each do |method|
      desc "[internal] Print the database server #{method}"
      task "print_#{method}", :roles => :app do
        logger.trace format_credentials(fetch "db_#{method}".to_sym)
      end

      desc "[internal] Load the database server #{method}"
      task method, :roles => :app do
        unless exists?("db_#{method}".to_sym)
          if remote_file_exists?(fetch("db_#{method}_file".to_sym), use_sudo: method == :root_credentials)
            send "read_#{method}"
          else
            send "generate_#{method}"
          end
        end
      end

      desc "[internal] Read the database server #{method}"
      task "read_#{method}", :roles => :app do
        read(fetch("db_#{method}_file".to_sym), use_sudo: method == :root_credentials).tap do |content|
          set "db_#{method}".to_sym, {
            hostname: match_from_content(content, 'host'),
            port:     match_from_content(content, 'port'),
            username: match_from_content(content, 'user'),
            password: match_from_content(content, 'pass'),
          }
        end
      end

      desc "[internal] Generate the database server #{method}"
      task "generate_#{method}", :roles => :app do
        set "db_#{method}".to_sym, {
          hostname: ask('What is the hostname used to access the database',
                        default: 'localhost',
                        validate: /.+/),
          port:     ask('What is the port used to access the database',
                        default: '',
                        validate: /\A[0-9]*\Z/),
          username: ask('What is the username used to access the database',
                        default: (method == :credentials) ? fetch(:db_username) : 'root',
                        validate: /.+/),
          password: ask('What is the password used to access the database',
                        default: gen_pass(8),
                        validate: /.+/,
                        echo: false),
        }
      end

      desc "[internal] Write the database server #{method}"
      task "write_#{method}", :roles => :app do
        on_rollback { run "rm -f #{fetch("db_#{method}_file".to_sym)}" }

        write format_credentials(fetch "db_#{method}".to_sym),
          fetch("db_#{method}_file".to_sym),
          use_sudo: method == :root_credentials
      end
    end

    desc '[internal] Create the database user'
    task :create_db_user, :roles => :db do
      transaction do
        find_and_execute_db_task :create_db_user
      end
    end

    desc '[internal] Create the database'
    task :create_database, :roles => :db do
      transaction do
        find_and_execute_db_task :create_database
      end
    end

    desc '[internal] Download the db backup file'
    task :download_backup, :roles => :db do
      fn = "#{random_tmp_file}.sql.bz2"
      on_rollback { `rm -f #{fn}` }
      download "#{fetch :latest_backup}.bz2", fn
      logger.important "The backup has been downloaded to #{fn}"
    end

    desc '[internal] Backup skiped tables'
    task :backup_skiped_tables, :roles => :db do
      set :backuped_skiped_tables_file, random_tmp_file
      on_rollback { run "rm -f #{fetch :backuped_skiped_tables_file}" }
      find_and_execute_db_task :backup_skiped_tables
    end

    desc '[internal] Restore skiped tables'
    task :restore_skiped_tables, :roles => :db do
      on_rollback { run "rm -f #{fetch :backuped_skiped_tables_file}" }
      find_and_execute_db_task :restore_skiped_tables
      run "rm -f #{fetch :backuped_skiped_tables_file}"
    end
  end

  # Internal Dependencies
  before 'db:print_credentials',      'db:credentials'
  before 'db:print_root_credentials', 'db:root_credentials'
  before 'db:create_db_user',         'db:root_credentials'
  before 'db:create_db_user',         'db:credentials'
  before 'db:create_database',        'db:credentials'
  before 'db:backup',                 'db:credentials'
  before 'db:import',                 'db:credentials'

  ['credentials', 'root_credentials'].each do |method|
    after "db:generate_#{method}", "db:write_#{method}"
  end

  # External Dependencies
  before 'deploy:server:setup', 'db:create_db_user'
  after 'deploy:server:setup', 'db:create_database'
  before 'db:write_credentials', 'deploy:setup_if_needed'
end
