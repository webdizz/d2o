# -*- mode: ruby -*-
# vi: set ft=ruby :

tld = "vgnt"
windows = (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil

required_plugins = %w( vagrant-vbguest vagrant-vbox-snapshot)
vm_ip = "192.168.33.77"

if windows
  required_plugins << 'vagrant-hostmanager'
  required_plugins << 'vagrant-multi-putty'
else
  required_plugins << 'landrush'
end

required_plugins.each do |plugin|
  system "vagrant plugin install #{plugin}" unless Vagrant.has_plugin? plugin
end

Vagrant.configure(2) do |config|
  config.vm.box = "webdizz/openshift-origin"
  config.vm.box_version = ">= 1.0"
  config.vbguest.auto_update = true

  config.vm.network "private_network", ip: vm_ip

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.memory = "2024"
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  if windows
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = true
    config.hostmanager.aliases = %w(fabric8.#{tld} jenkins.#{tld} gogs.#{tld} nexus.#{tld} hubot-web-hook.#{tld} letschat.#{tld} kibana.#{tld} taiga.#{tld} fabric8-forge.#{tld})
  else
    config.landrush.enabled = true
    config.landrush.tld = tld
    config.landrush.host_ip_address = vm_ip
  end

  config.vm.provision "shell",
    privileged: true,
    run: "always",
    inline: "hostname d2o.vgnt"

  config.vm.provision "shell",
    privileged: true,
    run: "once",
    path: "packer/scripts/openshift-origin-installation.sh"

  $script = <<SCRIPT
    docker pull buildpack-deps:trusty-curl
    docker pull httpd
    docker pull nginx
SCRIPT

  config.vm.provision "shell",
    privileged: true,
    run: "once",
    inline: $script

    config.vm.post_up_message = "
    export DOCKER_HOST=tcp://#{vm_ip}:2375
    export KUBERNETES_DOMAIN=d2o.#{tld}
    oc login https://#{vm_ip}:8443/
    "
end
