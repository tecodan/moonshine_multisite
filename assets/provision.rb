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

# add rubygems (so we can add capistrano)
if os == :debian
  system "wget -O - http://backports.org/debian/archive.key | sudo apt-key add -"
  unless system("grep lenny-backports /etc/apt/sources.list")
    system "echo \"deb http://www.backports.org/debian lenny-backports main contrib non-free\" | sudo tee -a /etc/apt/sources.list"
    system "sudo apt-get update"
  end
  system "sudo apt-get install -q -y -t lenny-backports rubygems"
else
  system "sudo apt-get update"
  system "sudo apt-get install rubygems"
end

# add rake, git (which will install ruby as well)
if os == :debian || os == :ubuntu
  system "sudo apt-get install -q -y git-core libopenssl-ruby1.8 rake git-core"
  unless system("gem list --local | grep capistrano")
    system "sudo gem install capistrano capistrano-ext --no-rdoc"
  end
end

# cap
unless system("gem list --local | grep capistrano")
  system "sudo gem install capistrano capistrano-ext --no-rdoc"
end

# utility replace with your settings
utility_dir = 'utility'
utility_repo = 'git://repo'
utility_branch = 'server.stage'
if File.directory?(utility_dir)
  Dir.chdir utility_dir
  system "sudo git pull"
else
  system "sudo git clone #{utility_repo}"
  Dir.chdir utility_dir
  system "sudo git checkout -b #{utility_branch} origin/#{utility_branch}"
end

# special case for colinux -- put /var/www on the windows drive
if system("uname -r | grep co") && system("df | grep /mnt/win")
  system "sudo apt-get remove -q -y latext2html" # latex2html puts stuff in /var/www
  system "sudo mkdir /mnt/win/www"
  system "sudo ln -s /mnt/win/www /var/www"
end

# provision
system "sudo cp config/database_root.yml.sample database_root.yml" unless File.exists?('config/database_root.yml')
system "rake -f vendor/plugins/moonshine_multisite/lib/tasks/provision.rake provision:this:dev"

# install cap again with the new gems
system "sudo gem install capistrano capistrano-ext --no-rdoc"
