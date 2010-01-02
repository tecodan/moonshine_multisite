# deploy user
system "sudo groupadd deploy"
system "sudo useradd -g deploy -m -d /home/deploy -k /etc/skel -s /bin/bash deploy"
system "echo \"provide a password for the deploy user\""
system "sudo passwd deploy"
system "echo \"deploy  ALL=(ALL) ALL\" | sudo tee -a /etc/sudoers"

# setup environment
system "wget -O - http://backports.org/debian/archive.key | sudo apt-key add -"
system "echo \"deb http://www.backports.org/debian lenny-backports main contrib non-free\" | sudo tee -a /etc/apt/sources.list"
system "sudo apt-get update"
system "sudo apt-get install ruby-full git-core libopenssl-ruby1.8 openssh-server make libmysqlclient15-dev"
system "sudo apt-get install -t lenny-backports rubygems"
system "sudo gem install capistrano capistrano-ext rails mysql --no-rdoc"

# c4c_utility
system "git clone git://github.com/andrewroth/c4c_utility.git"
system "cd c4c_utility"
system "git checkout -b c4c.dev origin/c4c.dev"

# provision
system "/var/lib/gems/1.8/bin/rake provision:c4c:utopian HOSTS=127.0.0.1"
system "sudo gem install capistrano capistrano-ext # install cap again since now REE gems is installed"
system "rake provision:p2c:utopian HOSTS=127.0.0.1 skipsetup=true"

# pull databases
system "cd /var/www/utility.local/current"
system "mv config/database_root.yml.sample database_root.yml"
system "cap pull:dbs:utopian"
