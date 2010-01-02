#!/bin/sh
wget -O - http://backports.org/debian/archive.key | sudo apt-key add -
echo "deb http://www.backports.org/debian lenny-backports main contrib non-free" | sudo tee -a /etc/apt/sources.list
sudo apt-get update

sudo apt-get install ruby-full git-core libopenssl-ruby1.8 openssh-server
sudo apt-get install -t lenny-backports rubygems

sudo gem install capistrano capistrano-ext rails mysql

git clone git://github.com/andrewroth/c4c_utility.git
cd c4c_utility
git checkout -b c4c.dev origin/c4c.dev

/var/lib/gems/1.8/bin/rake provision:c4c:utopian HOSTS=127.0.0.1
/var/lib/gems/1.8/bin/rake provision:p2c:utopian HOSTS=127.0.0.1 skipsetup=true

cap pull:dbs:utopian