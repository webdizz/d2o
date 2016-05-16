#!/usr/bin/env bash

echo "==> Run the Docker installation script"
 # yum install -y docker
cat > /etc/yum.repos.d/docker.repo << '__EOF__'
[docker]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
__EOF__

yum -y install docker-engine

echo "==> Create the docker group"
# Add the docker group if it doesn't already exist
groupadd docker

echo "==> Add the connected vagrant to the docker group."
gpasswd -a vagrant docker

mkdir /etc/systemd/system/docker.service.d/
cat > /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/docker daemon -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375 --selinux-enabled --insecure-registry=172.0.0.0/8 --log-level=warn --insecure-registry registry.access.redhat.com --insecure-registry 172.30.0.0/16 --insecure-registry docker-registry.d2o.vgnt
EOF

echo "Add firewall rules"
firewall-cmd --permanent --zone=public --add-port=2375/tcp
firewall-cmd --reload

echo "==> Change limits for docker"
cat >> /etc/security/limits.conf <<EOF
*        hard    nproc           16384
*        soft    nproc           16384
*        hard    nofile          16384
*        soft    nofile          16384
EOF

echo "==> Enabling docker to start on reboot"
systemctl daemon-reload
systemctl enable docker

echo "==> Starting docker"
systemctl start docker

echo "==> Install Docker Compose"
curl -L https://github.com/docker/compose/releases/download/1.7.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/local/bin/dc

 yum install -y htop bash-completion
 curl -L https://raw.githubusercontent.com/docker/docker/master/contrib/completion/bash/docker > /etc/bash_completion.d/docker
 curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose
 curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose > /etc/bash_completion.d/dc

 sed -i -E "s/_docker_compose [^)]+/_docker_compose dc/g" /etc/bash_completion.d/dc
