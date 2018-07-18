# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/contrib-jessie64"
  config.vm.box_version = "8.11.0"
  config.vm.network "public_network", auto_config: false, bridge: "eth1"
  config.vm.provision "initialize", type: "shell", path: "scripts/sunboot_init", run: "once"
  config.vm.provision "provision", type: "shell", path: "scripts/install_targets", run: "always"

  config.vm.post_up_message = [ "sunboot initialization complete." ]
end
