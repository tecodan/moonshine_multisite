#!/bin/bash

ruby_output="$(which ruby)"

if [ -z "$ruby_output" ]; then
    sudo apt-get install ruby
fi

rm provision.rb
wget http://github.com/andrewroth/moonshine_multisite/raw/ministry_hacks/assets/provision.rb
sudo ruby provision.rb
