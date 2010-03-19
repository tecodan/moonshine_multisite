def pull_asset(remote, local)
  basename = File.basename(remote)
  dirname = File.dirname(remote)
  run "cd #{dirname} && tar -czf #{basename}.tar.gz #{basename}"
  download "#{remote}.tar.gz", "#{local}.tar.gz"
  cmd = "cd #{File.dirname(local)} && tar xfz #{local}.tar.gz"
  puts cmd
  system cmd
end

task :pull_assets do
  role :app, 'pat.powertochange.org'
  set :user, 'deploy'
  set :host, 'pat.powertochange.org'

  pull_asset '/var/www/pat.powertochange.org/shared/public/event_groups',
    '/var/www/pat.powertochange.org/shared/public/event_groups'
end
