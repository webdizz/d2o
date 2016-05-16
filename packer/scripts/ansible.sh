#!/bin/bash -eux

echo "==> Installing Epel repository"
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
echo "==> Installing Ansible"
yum update -y
yum install -y python-devel python2-devel libyaml python-setuptools python2-devel python-simplejson tar unzip git
pip install paramiko PyYAML Jinja2 httplib2
yum -y install  ansible1.9
