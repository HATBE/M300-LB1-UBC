# (c) Aaron Gensetter, 2021
# Part from "Ultra Bad Cloud (UBC)"

nodes_config = (JSON.parse(File.read("nodes.json")))['nodes'] # Select nodess

Vagrant.configure(2) do |config|

  config.vm.box = "ubuntu/focal64" # Ubuntu 20.04

  nodes_config.each do |node| 
    node_name = node[0] # name of node 
    node_values = node[1] # content of node

    config.vm.define node_name do |config|
      # configures all forwarding ports in JSON array
      ports = node_values['ports']
      ports.each do |port|
        config.vm.network :forwarded_port, host:  port['host'], guest: port['guest'], id: port[':id']
      end

      config.vm.hostname = node_name
      config.vm.network :private_network, ip: node_values['ip'] # IP Adress

      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", node_values['memory']] # set VM memory
        vb.customize ["modifyvm", :id, "--name", node_name] # set VM Name
        vb.cpus = node_values['cpu']
      end

      config.vm.provision :shell, :path => node_values['script'], args: node_values['args'] # set installation script
    end
  end
end