unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/database requires Capistrano 2"
end

Capistrano::Configuration.instance(:must_exist).load do
  namespace :db do
    namespace :mysql do
      desc '[internal] Create the database user'
      task :create_user, :roles => :db do
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

      desc '[internal] Backup mysql database'
      task :backup, :roles => :db do
        latest_backup = fetch :latest_backup
        on_rollback { run "rm -f #{latest_backup}" }
        auth  = fetch :db_credentials

        begin
          run <<-CMD
            #{try_sudo} mysqldump \
              --host='#{auth[:hostname]}' \
              --user='#{auth[:username]}' \
              --password='#{auth[:password]}' \
              --default-character-set=utf8 \
              '#{fetch :db_database_name}' > \
              '#{latest_backup}' &&
            #{try_sudo} bzip2 -9 '#{latest_backup}'
          CMD
        rescue Capistrano::CommandError
          abort 'Not able to backup the database'
        end
      end

      desc '[internal] Import a dump to the mysql database'
      task :import, :roles => :db do
        tmp_file = write File.read(arguments)
        auth = fetch :db_credentials

        begin
          run <<-CMD
            #{try_sudo} mysql \
              --host='#{auth[:hostname]}' \
              --user='#{auth[:username]}' \
              --password='#{auth[:password]}' \
              --default-character-set=utf8 \
              '#{fetch :db_database_name}' < \
              '#{tmp_file}' &&
            rm -f '#{tmp_file}'
          CMD
        rescue Capistrano::CommandError
          abort 'Failed to import the database'
        end
      end

      desc '[internal] Backup skiped tables from the mysql database'
      task :backup_skiped_tables, :roles => :db do
        auth = fetch :db_credentials

        fetch(:skip_tables_on_import, []).each do |t|
          begin
            run <<-CMD
              #{try_sudo} mysqldump \
                --host='#{auth[:hostname]}' \
                --user='#{auth[:username]}' \
                --password='#{auth[:password]}' \
                --default-character-set=utf8 \
                '#{fetch :db_database_name}' '#{t}' >> \
                '#{fetch :backuped_skiped_tables_file}'
            CMD
          rescue Capistrano::CommandError
            logger.info "WARNING: It seems the database does not have the table '#{t}', skipping it."
          end
        end

        desc '[internal] Restore skiped tables to the mysql database'
        task :restore_skiped_tables, :roles => :db do
          auth = fetch :db_credentials

          begin
            run <<-CMD
              mysql \
                --host='#{auth[:hostname]}' \
                --user='#{auth[:username]}' \
                --password='#{auth[:password]}' \
                --default-character-set=utf8 \
                '#{fetch :db_database_name}' < \
                #{fetch :backuped_skiped_tables_file}
            CMD
          rescue
            abort 'ERROR: I could not restore the tables defined in skip_tables_on_import'
          end
        end
      end
    end
  end
end
