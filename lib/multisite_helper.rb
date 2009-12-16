require 'yaml'
require 'erb'

def utopian_db_name(server, app, stage)
  "#{server || 'server'}.#{app || 'app'}.#{stage || 'stage'}"
end

def legacy_db_name(server, app, stage)
  return 'legacy_db_name' unless server && app && stage
  hash_path = [ :servers, server, :db_names, app, stage ]
  path_so_far = multisite_config_hash
  for next_segment in hash_path
    if path_so_far[next_segment]
      path_so_far = path_so_far[next_segment]
    else
      return nil
    end
  end
  path_so_far
end

def multisite_config_hash
  return @multisite_config if @multisite_config
  file = "#{File.dirname(__FILE__)}/../moonshine_multisite.yml"
  return {} unless File.exists?(file)
  @multisite_config = YAML.load(ERB.new(File.read(file)).result)
end

# Sets the key and values in capistrano from the moonshine multisite config
# Also sets @moonshine_config as a hash of moonshine values (similar to what
# would be gotten from a moonshine.yml)
def apply_moonshine_multisite_config(server, stage)
  domain = multisite_config_hash[:servers][server.to_sym][:domain]
  # give some nice defaults
  @moonshine_config = {
    :server_only => server,
    :stage_only => stage,
    :repository => multisite_config_hash[:apps][fetch(:application)],
    :scm => if (!! repository =~ /^svn/) then :svn else :git end,
    :branch => "#{server}.#{stage}"
  }
  @moonshine_config.merge! multisite_config_hash[:servers][server.to_sym]
  # tie the multisite_config_hash back to the instance variabled one
  multisite_config_hash[:servers][server.to_sym] = @moonshine_config
  @moonshine_config.each do |key, value|
    set(key.to_sym, value)
  end
  deploy_to = "/var/www/#{fetch(:application)}.#{stage}.#{fetch(:domain)}"
  set :deploy_to, deploy_to
  @moonshine_config[:deploy_to] = deploy_to
end

# Assumes that your capistrano-ext stages are actually in "host/stage", then
# extracts the host and stage and goes to apply_moonshine_multisite_config
def apply_moonshine_multisite_config_from_cap
  fetch(:stage).to_s =~ /(.*)\/(.*)/
  apply_moonshine_multisite_config $1, $2
end

def get_stages
  multisite_config_hash[:servers].keys.collect { |host|
    multisite_config_hash[:stages].collect{ |stage|
      "#{host}/#{stage}"
    }
  }.flatten + (multisite_config_hash[:legacy_stages].collect(&:to_s) || [])
end

def set_stages
  set :stages, get_stages
end
