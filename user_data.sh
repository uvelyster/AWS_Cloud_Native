#!/bin/bash
sudo yum update -y
sudo yum install httpd -y
sudo yum install ruby -y
sudo yum install wget -y
sudo sytemctl start httpd
cd /home/ec2-user
wget https://aws-codedeploy-ap-northeast-1.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo systemctl start codedeploy-agent 
rm install
#sudo amazon-linux-extras install java-openjdk11 -y
sudo yum install java-17-amazon-corretto -y
