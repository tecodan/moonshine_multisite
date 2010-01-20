MOONSHINE_MULTISITE_ROOT = "#{File.dirname(__FILE__)}/../.."
RAILS_ROOT = "#{MOONSHINE_MULTISITE_ROOT}/../../.."
require MOONSHINE_MULTISITE_ROOT + '/lib/multisite_helper.rb'
require MOONSHINE_MULTISITE_ROOT + '/lib/rake_helper.rb'

task :aliases do
  multisite_config_hash[:apps].keys.each do |app|
    host = env['host'] || 127.0.0.1
    aliass = "#{app}.local"
    unless system("grep #{aliass} /etc/hosts")
      system "echo '127.0.0.1\t#{aliass}' >> /etc/hosts"
      puts "Add #{aliass}"
    end
  end
end
