unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/database requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
  namespace :db do
    namespace :mysql do
      desc '[internal] Create the database user'
      task :create_db_user, :roles => :db do
        auth  = fetch :db_credentials
        sauth = fetch :db_root_credentials

        script_file = write(<<-EOS)
          CREATE USER '#{auth[:username]}'@'%' IDENTIFIED BY '#{auth[:password]}';
          GRANT ALL ON `#{fetch :application}\_%`.* TO '#{auth[:username]}'@'%';
          FLUSH PRIVILEGES;
        EOS

        begin
          run <<-CMD
            mysql \
              --host='#{sauth[:hostname]}' \
              --user='#{sauth[:username]}' \
              --password='#{sauth[:password]}' \
              --default-character-set=utf8 < \
              #{script_file}; \
            rm -f #{script_file}
          CMD
        rescue Capistrano::CommandError
          logger.important 'ERROR: Could not create the user used to access the database.'
        end
      end

      desc '[internal] Create the database'
      task :create_database, :roles => :db do
        auth = fetch :db_credentials

        begin
          run <<-CMD
            mysqladmin \
              --host='#{auth[:hostname]}' \
              --user='#{auth[:username]}' \
              --password='#{auth[:password]}' \
              create '#{fetch :db_database_name}'
          CMD
        rescue Capistrano::CommandError
          logger.info 'ERROR: Could not create the database'
        end
      end
    end
  end
end
