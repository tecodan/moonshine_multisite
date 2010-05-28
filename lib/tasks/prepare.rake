namespace :db do
  namespace :test do
    namespace :prepare do
      desc "prepares all test databases for all apps on the current stage"
      task :all => :environment do
        Rake::Task["#{Cdm::SERVER}:test:#{Cdm::STAGE}:prepare"].invoke  
      end
    end
  end
end
