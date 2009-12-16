MOONSHINE_MULTISITE_ROOT = "#{File.dirname(__FILE__)}/../.."
RAILS_ROOT = "#{MOONSHINE_MULTISITE_ROOT}/../../.."
require MOONSHINE_MULTISITE_ROOT + '/lib/multisite_helper.rb'

require 'capistrano/cli'

namespace :moonshine do
  namespace :multisite do
    namespace :provision do
      multisite_config_hash[:servers].each do |server, server_config|
        desc "Provision the #{server} server"
        task server do
          provision(server, server_config, false)
        end
      end
    end
  end 
end

# fix rake collisions with capistrano
undef :symlink
undef :ruby
undef :install

def run_shell(cmd)
  puts "[SH ] #{cmd}"
  system cmd
end

def run_shell_forked(cmd)
  puts "[SH ] #{cmd}"
  if fork.nil?
    exec(cmd)
    #Kernel.exit!
  end
  Process.wait
end

def new_cap(stage)
  # save password
  if @cap_config
    @password = @cap_config.fetch(:password)
  end
  @cap_config = Capistrano::Configuration.new
  Capistrano::Configuration.instance = @cap_config
  @cap_config.logger.level = Capistrano::Logger::TRACE
  if @password
    @cap_config.set(:password, @password)
  else
    @cap_config.set(:password) { Capistrano::CLI.password_prompt }
  end
  @cap_config.load "Capfile"
  #@cap_config.load :file => "vendor/plugins/moonshine_multisite/recipes/multistage"
  @cap_config.find_and_execute_task(stage)
  @cap_config.find_and_execute_task("multistage:ensure")
end

def run_cap(stage, cmd)
  @cap_config.find_and_execute_task(cmd)
end

def cap_download_private(stage)
  puts "[DBG] Downloading private config files from secure repository"
  run_shell_forked "cap #{stage} moonshine:secure:download_private"
end

def cap_upload_certs(stage)
  puts "[DBG] Uploading private certs to server"
  #run_shell_forked "cap #{stage} moonshine:secure:upload_certs"
  run_cap stage, "moonshine:secure:upload_certs"
end

def provision(server, server_config, local)
  puts "[DBG] setup #{server} config #{server_config.inspect}"
  tmp_dir = "#{RAILS_ROOT}/tmp"
  first_app = true
  for app, repo in multisite_config_hash[:apps]
    puts "========================    SITE    #{app.to_s.ljust(11, " ")} ========================"
    next if repo.nil? || repo == ''
    app_root = "#{tmp_dir}/#{app}"
    # checkout
    skipping = false
    unless File.directory? app_root
      run_shell "git clone #{repo} #{app_root}"
    end
    Dir.chdir app_root
    ENV['skip_hooks'] = 'true'
    # set up all apps on server
    first = true # first time deploy:setup should run
    multisite_config_hash[:stages].each do |stage|
      cap_stage = "#{server}/#{stage}"
      puts "------------------------ #{app.to_s.ljust(10, " ")} #{stage.to_s.ljust(10, " ")} ------------------------"
      run_shell "git pull"
      # update and make sure this app is supposed to go on this server
      if !run_shell("git checkout #{server}.#{stage}")
        if !run_shell("git checkout -b #{server}.#{stage} origin/#{server}.#{stage}")
          puts "[WRN] Skipping installation of #{app} on #{server} since no #{server}.#{stage} branch found"
          next
        end
      end
      new_cap cap_stage
      # deploy
      server_moonshine_folder = "#{app_root}/config/deploy/#{server}"
      stage_moonshine_file = "#{server_moonshine_folder}/#{stage}_moonshine.yml"
      if first_app
        run_cap cap_stage, "deploy:setup"
        first_app = false
      elsif first
        run_cap cap_stage, "moonshine:setup_directories"
        first = false
      else
        run_cap cap_stage, "deploy"
      end
    end
  end
end
