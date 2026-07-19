#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)" > /var/www/html/index.html
