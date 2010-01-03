if RUBY_PLATFORM['linux']
  issue = File.read "/etc/issue"
  os = :debian if issue['Debian']
  os = :ubuntu if issue['Ubuntu']
elsif RUBY_PLATOFRM['darwin']
  os = :osx
end

# deploy user
unless system("grep deploy /etc/passwd")
  system "sudo groupadd deploy"
  system "sudo useradd -g deploy -m -d /home/deploy -k /etc/skel -s /bin/bash deploy"
  system "echo \"provide a password for the deploy user\""
  system "sudo passwd deploy"
  system "echo \"deploy  ALL=(ALL) ALL\" | sudo tee -a /etc/sudoers"
end

# setup environment
if os == :debian
  system "wget -O - http://backports.org/debian/archive.key | sudo apt-key add -"
  unless system("grep lenny-backports /etc/apt/sources.list")
    system "echo \"deb http://www.backports.org/debian lenny-backports main contrib non-free\" | sudo tee -a /etc/apt/sources.list"
  end
end

if os == :debian || os == :ubuntu
  system "sudo apt-get update"
  system "sudo apt-get -q -y install ruby-full git-core libopenssl-ruby1.8 openssh-server make libmysqlclient15-dev"
end
if os == :debian
  system "sudo apt-get -q -y install -t lenny-backports rubygems" 
elsif os == :ubuntu
  system "sudo apt-get -q -y install rubygems"
end
unless system("gem list --local | grep capistrano")
  system "sudo gem install capistrano capistrano-ext rails mysql --no-rdoc"
end

# utility replace with your settings
utility_dir = 'c4c_utility'
utility_repo = 'git://github.com/andrewroth/c4c_utility.git'
utility_branch = 'c4c.dev'
if File.directory?(utility_dir)
  Dir.chdir utility_dir
  system "sudo git pull"
else
  system "sudo git clone #{utility_repo}"
  Dir.chdir utility_dir
  system "sudo git checkout -b #{utility_branch} origin/#{utility_branch}"
end

# provision
system "sudo cp config/database_root.yml.sample database_root.yml" unless File.exists?('config/database_root.yml')
system "/var/lib/gems/1.8/bin/rake provision:this:dev HOSTS=127.0.0.1"
