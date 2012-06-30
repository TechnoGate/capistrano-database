unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/database requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
  namespace :db do
    namespace :mysql do
      desc '[internal] Load the credentials'
      task :credentials do

      end
    end
  end
end
