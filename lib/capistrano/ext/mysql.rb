unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/database requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
  namespace :db do
    namespace :mysql do
      ['credentials', 'root_credentials'].each do |method|
      end
    end
  end
end
