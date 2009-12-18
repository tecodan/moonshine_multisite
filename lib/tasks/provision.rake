MOONSHINE_MULTISITE_ROOT = "#{File.dirname(__FILE__)}/../.."
RAILS_ROOT = "#{MOONSHINE_MULTISITE_ROOT}/../../.."
require MOONSHINE_MULTISITE_ROOT + '/lib/multisite_helper.rb'

require 'capistrano/cli'
require 'ftools'

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
  debug "[SH ] #{cmd}"
  system cmd
end

def run_shell_forked(cmd)
  debug "[SH ] #{cmd}"
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
  #@cap_config.load "config/deploy"
  #@cap_config.load :file => "/opt/local/lib/ruby/gems/1.8/gems/capistrano-ext-1.2.1/lib/capistrano/ext/multistage.rb"
  unless @multistage_path
    version = Gem.source_index.find_name('capistrano-ext').first.version.to_s
    @multistage_path = Gem.path.collect{ |p|
    "#{p}/gems/capistrano-ext-#{version}/lib/capistrano/ext/multistage.rb"
    }.find{ |p|
      File.exists?(p)
    }
  end
  @cap_config.load :file => @multistage_path
  @cap_config.find_and_execute_task(stage)
  @cap_config.find_and_execute_task("multistage:ensure")
end

def run_cap(stage, cmd)
  debug "[CAP] #{stage} #{cmd}"
  @cap_config.find_and_execute_task(cmd)
end

def cap_download_private(stage)
  debug "[DBG] Downloading private config files from secure repository"
  run_shell_forked "cap #{stage} moonshine:secure:download_private"
end

def cap_upload_certs(stage)
  debug "[DBG] Uploading private certs to server"
  #run_shell_forked "cap #{stage} moonshine:secure:upload_certs"
  run_cap stage, "moonshine:secure:upload_certs"
end

def provision(server, server_config, legacy)
  debug "[DBG] setup #{server} with #{legacy ? "legacy" : "utopian"} naming"
  debug "[DBG] config #{server_config.inspect}"
  tmp_dir = "#{RAILS_ROOT}/tmp"
  first_app = true
  for app, repo in multisite_config_hash[:apps]
    debug "============================= #{app.to_s.ljust(20, " ")} ============================="
    next if repo.nil? || repo == ''
    app_root = "#{tmp_dir}/#{app}"

    # set up all apps on server
    first = true # first time deploy:setup should run
    multisite_config_hash[:stages].each do |stage|
      cap_stage = "#{server}/#{stage}"
      debug "----------------------------- #{app.to_s.ljust(10, " ")} #{stage.to_s.ljust(10, " ")} ----------------------------"
      # update and make sure this app is supposed to go on this server
      if repo == '' || %x[git ls-remote #{repo} #{server}.#{stage}] == ''
        debug "[WRN] Skipping installation of #{app} on #{server} since no #{server}.#{stage} branch found"
        next
      end
      if legacy && legacy_db_name(server, app, stage).nil?
        debug "[WRN] Skipping installation of #{app} on #{server} since no legacy db name found"
        next
      end
      new_cap cap_stage
      # deploy
      server_moonshine_folder = "#{app_root}/config/deploy/#{server}"
      stage_moonshine_file = "#{server_moonshine_folder}/#{stage}_moonshine.yml"
      if first_app && false
        run_cap cap_stage, "deploy:setup"
        first_app = false
      elsif first
        run_cap cap_stage, "moonshine:setup_directories"
        first = false
      end

      # copy the database file
      @cap_config.set(:shared_config, (@cap_config.fetch(:shared_configs, []) + [ "config/database.yml", "config/database.#{server}.#{app}.#{stage}.yml", "config/moonshine.yml" ]).uniq)
      #
      database_config = "database.#{server}.#{app}.#{stage}.yml"
      db_file = File.read(Rails.root.join("app/manifests/assets/#{legacy ? 'private' : 'public'}/database_configs/#{database_config}"))
      @cap_config.put db_file, "#{@cap_config.fetch(:shared_path)}/config/#{database_config}"
      @cap_config.put db_file, "#{@cap_config.fetch(:shared_path)}/config/database.yml"
      @cap_config.put YAML::dump(@cap_config.fetch(:moonshine_config)), "#{@cap_config.fetch(:shared_path)}/config/moonshine.yml"
      run_cap cap_stage, "shared_config:upload"

      run_cap cap_stage, "deploy"
    end
  end
end
