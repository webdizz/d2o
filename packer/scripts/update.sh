#!/bin/bash -eux
echo "==> Applying updates"
yum -y update
yum install -y net-tools telnet htop
# reboot
echo "Rebooting the machine..."
reboot
sleep 60
