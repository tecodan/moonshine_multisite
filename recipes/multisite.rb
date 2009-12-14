def multisite_config_hash
  return @multisite_config if @multisite_config
  file = "#{File.dirname(__FILE__)}/../moonshine_multisite.yml"
  return {} unless File.exists?(file)
  @multisite_config = YAML.load_file(file)
end

# Sets the key and values in capistrano from the moonshine multisite config
def apply_moonshine_multisite_config(host, stage)
  multisite_config_hash[:servers][host.to_sym].each do |key, value|
    set(key.to_sym, value)
  end
  set :repository, multisite_config_hash[:apps][fetch(:application)]
  set :scm, :svn if !! repository =~ /^svn/
  # Currently there's no way to override the following settings, they're just
  # inherent in moonshine multisite.
  # If someone uses this and wants to override this, we can make a way to 
  # override them in the moonshine_multisite.yml.
  set :deploy_to, "/var/www/#{fetch(:application)}.#{stage}.#{fetch(:domain)}"
  set :branch, "#{host}.#{stage}"
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
  }.flatten
end

def set_stages
  set :stages, get_stages
end
