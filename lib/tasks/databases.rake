require "#{File.dirname(__FILE__)}/../../lib/rake_helper.rb"
require "#{File.dirname(__FILE__)}/../../lib/multisite_helper.rb"
require "#{File.dirname(__FILE__)}/../../lib/detect_windows.rb"

query_databases
@master_stage = multisite_config_hash[:stages].first

for_dbs(:dump) do |p|
  desc "dumps #{p[:utopian]}"
  task p[:stage] do
    clone :prod => p[:legacy], :file => "tmp/#{p[:utopian]}.sql.gz", :force => (ENV['force'] == 'true')
  end
end

for_dbs(:klone) do |p|
  next if p[:stage] == @master_stage

  if @databases.nil? || @databases.include?(p[:master_legacy].to_s)
    if p[:legacy]
      desc "clones #{p[:master_legacy]} -> #{p[:legacy]}"
      task :"#{p[:stage]}" do
        clone :prod => p[:master_legacy], :dev => p[:legacy]
      end
    end
  end
end

for_dbs(:load) do |p|
  if p[:legacy]
    desc "loads tmp/#{p[:utopian]}.sql.gz to #{p[:legacy]} database"
    task :"#{p[:stage]}" do
      load_dump("tmp/#{p[:utopian]}.sql", p[:legacy])
    end
  end
  namespace :"#{p[:stage]}" do
    desc "loads tmp/#{p[:utopian]}.sql.gz to #{p[:utopian]} database"
    task :utopian do
      load_dump("tmp/#{p[:utopian]}.sql", p[:utopian])
    end
  end
end

for_dbs(:create) do |p|
  if p[:legacy] && p[:legacy] != ''
    desc "create #{p[:legacy]}"
    task :"#{p[:stage]}" do
      puts "[DBG] create #{p[:legacy]}"
      prepare_for_sql
      ActiveRecord::Base.connection.create_database(p[:legacy])
    end
  end

  # define only once
  if p[:stage] == multisite_config_hash[:stages].first
    if (multisite_config_hash[:stages].find{ |stage|  legacy_db_name(p[:server], p[:app], stage) })
      desc "create a database for all #{p[:server]} stages"
      task :stages do
        multisite_config_hash[:stages].each do |stage|
          begin
            Rake::Task["#{p[:app]}:create:#{p[:server]}:#{stage}"].invoke
          rescue
          end
        end
      end
    end
  end
end

namespace :create do
  namespace :server do
    multisite_config_hash[:servers].keys.each do |server|
      desc "create all legacy databases for #{server}"
      task server do
        multisite_config_hash[:apps].keys.each do |app|
          begin
            Rake::Task["#{app}:create:#{server}:apps"].invoke
          rescue
          end
        end
      end
      desc "create all utopian databases for #{server}"
      namespace server do
        task :utopian do
          multisite_config_hash[:apps].keys.each do |app|
            begin
              Rake::Task["#{app}:create:#{server}:apps:utopian"].invoke
            rescue
            end
          end
        end
      end
    end
  end
end

multisite_config_hash[:servers].keys.each do |server|
  namespace server do
    namespace :test do
      multisite_config_hash[:stages].each do |stage|
        next if stage == :test
        namespace stage do
          desc "Prepares all #{server} databases with #{stage} schema."
          task :prepare => :environment do
            require 'uri'
            require 'net/http'
            multisite_config_hash[:apps].each_pair.each do |app, git|
              puts "PREPARE #{server} #{stage} #{app}"
              puts git
              git =~ /github.com\/(.*)\/(.*)\.git/
              if $1 && $2
                server = Cdm::SERVER == "utopian" ? "" : "#{Cdm::SERVER}."
                branch = "#{server}#{stage}"
                url = "http://github.com/#{$1}/#{$2}/raw/#{branch}/db/development_structure.sql"
                puts url
                r = Net::HTTP.get_response(URI.parse(url))
                next if r.class == Net::HTTPNotFound

                # at this point r.body has the SQL to execute - need to load it to the right db
                test_config = ActiveRecord::Base.configurations["#{app}_test"]
                
                tmp_file = File.new("tmp/structure.sql", "w+")
                tmp_file.write(r.body)
                tmp_file.close

                prepare_for_sql('', true)
                load_dump(tmp_file.path, test_config["database"])
              end
            end
          end
        end
      end
    end
  end
end
