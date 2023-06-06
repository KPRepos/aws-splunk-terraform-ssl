#!/bin/sh -xe
sudo yum install -y jq
sudo yum install -y mongocli python-pip
sudo amazon-linux-extras install epel -y
sudo yum install -y s3cmd
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo rpm -ivh sess*
sudo rm sess*
sudo yum install letsencrypt -y
