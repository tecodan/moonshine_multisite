require File.dirname(__FILE__) + "/../../recipes/multisite_helpers.rb"

class MoonshineMultisiteDefaultConfigsGenerator < Rails::Generator::Base
  def manifest
    if ARGV.length == 0
      return record do |m|
      end
    end

    app = ARGV.first.to_sym
    generate_private = (ARGV.second == 'private')
    visibility = generate_private ? 'private' : 'public'

    record do |m|
      m.directory "app/manifests"
      m.directory "app/manifests/templates"
      m.directory "app/manifests/templates/#{visibility}"
      m.directory "app/manifests/templates/#{visibility}/database_configs"
      multisite_config_hash[:servers].each do |server, config|
        multisite_config_hash[:stages].each do |stage|
          stage = stage.to_sym
          dest = "app/manifests/templates/#{visibility}/database_configs/database.#{server}.#{stage}.yml"
          if generate_private
            if config[:db_names] && config[:db_names][app] && config[:db_names][app][stage]
              database = config[:db_names][app][stage]
            else
              next
            end
          else
            database = "#{server}.#{stage}"
          end
          m.template "database.yml.erb", dest, :assigns => { :database => database }
        end
      end
    end
  end
end
