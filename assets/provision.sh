#!/bin/sh

# deploy user
sudo useradd -g deploy -m -d /home/deploy -k /etc/skel deploy
echo "provide a password for the deploy user"
sudo passwd deploy
echo "deploy  ALL=(ALL) ALL" | sudo tee -a /etc/sudoers

# setup environment
wget -O - http://backports.org/debian/archive.key | sudo apt-key add -
echo "deb http://www.backports.org/debian lenny-backports main contrib non-free" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install ruby-full git-core libopenssl-ruby1.8 openssh-server make libmysqlclient15-dev
sudo apt-get install -t lenny-backports rubygems
sudo gem install capistrano capistrano-ext rails mysql --no-rdoc

# c4c_utility
git clone git://github.com/andrewroth/c4c_utility.git
cd c4c_utility
git checkout -b c4c.dev origin/c4c.dev

# provision
/var/lib/gems/1.8/bin/rake provision:c4c:utopian HOSTS=127.0.0.1
rake provision:p2c:utopian HOSTS=127.0.0.1 skipsetup=true

# pull databases
cd /var/www/utility.local
mv config/database_root.yml.sample database_root.yml
cap pull:dbs:utopian
