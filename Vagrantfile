# -*- mode: ruby -*-
# vi: set ft=ruby :

$configureCommon=<<-SHELL

  # apt-get update
  # apt-get upgrade -y

  ## cni plugins
  mkdir -p /opt/cni/bin
  curl -sSL https://github.com/containernetworking/plugins/releases/download/v0.7.5/cni-plugins-amd64-v0.7.5.tgz | tar xzf - -C /opt/cni/bin

  
  route add -net 192.168.90.0/24 gw 192.168.33.1
  cat <<EOF > /etc/rc.local
#!/bin/sh -e
#
route add -net 192.168.90.0/24 gw 192.168.33.1

exit 0
EOF
  chmod 0755 /etc/rc.local

  # for kube-proxy (iptables)
  #
  echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf
  modprobe br_netfilter
  sysctl -p

SHELL

$configureMaster=<<-SHELL

  # Store private network IP address in variable
  IPADDR=$(ip a show enp0s8 | grep "inet " | awk '{print $2}' | cut -d / -f1)

  # Deploy k3s, turn off flannel, specify private IP as kubelet's IP, disable loadbalancer and traefik
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--no-flannel --no-deploy=servicelb --no-deploy=traefik --node-ip=${IPADDR}" sh -

  ## Deploy flannel, custom file with updated iface name and k3s network cidr
  kubectl apply -f /vagrant/kube-flannel.yml

  ## Place token for agent registration in shared folder
  cp /var/lib/rancher/k3s/server/node-token /vagrant/token
  
  curl -s https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml >  /root/metallb.yaml
  sed  -i '1i ---' /root/metallb.yaml
  cat << EOF > /root/metallb_configmap.yaml
---  
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    peers:
    - my-asn: 64522
      peer-asn: 64512
      peer-address: 192.168.33.1
      peer-port: 179
      router-id: 192.168.33.1
    address-pools:
    - name: my-ip-space
      protocol: bgp
      avoid-buggy-ips: true
      addresses:
      - 192.168.90.192/26
EOF
  kubectl apply -f /root/metallb.yaml
  kubectl apply -f /root/metallb_configmap.yaml
  # deployment
  kubectl run source-ip-app --image=k8s.gcr.io/echoserver:1.4
  kubectl expose deployment source-ip-app --name=loadbalancer --port=80 --target-port=8080 --type=LoadBalancer
  kubectl get svc loadbalancer
  kubectl patch svc loadbalancer -p '{"spec":{"externalTrafficPolicy":"Local"}}'
  
SHELL

$configureNode=<<-SHELL

  export K3S_TOKEN=$(cat /vagrant/token)
  export K3S_URL=https://192.168.33.11:6443
  # Store private network IP address in variable
  IPADDR=$(ip a show enp0s8 | grep "inet " | awk '{print $2}' | cut -d / -f1)

  ## Deploy k3s, turn off flannel, specify private IP as kubelet's IP
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--no-flannel --node-ip=${IPADDR}" sh -

SHELL

$configureRouter=<<-SHELL

  apt-get update
  apt-get install -y curl bird

  mv /etc/bird/bird.conf /etc/bird/bird.conf.original

  cat <<EOF > /etc/bird/bird.conf 
router id 192.168.33.1;
protocol direct {
  interface "lo"; # Restrict network interfaces BIRD works with
}
protocol kernel {
  persist; # Don't remove routes on bird shutdown
  scan time 20; # Scan kernel routing table every 20 seconds
  import all; # Default is import all
  export all; # Default is export none
}

# This pseudo-protocol watches all interface up/down events.
protocol device {
  scan time 10; # Scan interfaces every 10 seconds
}

protocol bgp peer2 {
  local as 64512;
  neighbor 192.168.33.11 as 64522;
  import all;
  export all;
}
protocol bgp peer1 {
  local as 64512;
  neighbor 192.168.33.12 as 64522;
  import all;
  export all;
}
protocol bgp peer3 {
  local as 64512;
  neighbor 192.168.33.13 as 64522;
  import all;
  export all;
}
EOF

  service bird restart
  echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/55-kubeadm.conf
  sysctl -p /etc/sysctl.d/55-kubeadm.conf

SHELL

$configureClient=<<-SHELL

  route add -net 192.168.90.0/24 gw 192.168.90.1
  cat <<EOF > /etc/rc.local
#!/bin/sh -e
#
route add -net 192.168.90.0/24 gw 192.168.90.1

exit 0
EOF
  chmod 0755 /etc/rc.local

SHELL

Vagrant.configure(2) do |config|

  # node_num=3
  node_num=2

  (1..node_num).each do |i|
    if i == 1 then
      vm_name="master"
    else
      vm_name="node#{i-1}"
    end

    config.vm.define vm_name do |s|

      s.vm.hostname=vm_name
      s.vm.box="ubuntu/bionic64"
      private_ip="192.168.33.#{i+10}"
      private_ip = "192.168.33.#{i+10}"
      s.vm.network "private_network",
                   ip: private_ip,
                   netmask: "255.255.255.0",
                   auto_config: true,
                   virtualbox__intnet: "k3s-metallb-net"
      s.vm.provision "shell", inline: $configureCommon

      if i == 1 then
        # For Master
        s.vm.provision "shell", inline: $configureMaster
      else
        # For Nodes
        s.vm.provision "shell", inline: $configureNode
      end
    end
  end

  config.vm.define "router" do |router|
    router.vm.box = "ubuntu/bionic64"
    router.vm.network "public_network", bridge: "en0: Wi-Fi (Wireless)", ip: "192.168.1.200"
    router.vm.network "private_network",
                       ip: "192.168.33.1",
                       netmask: "255.255.255.0",
                       auto_config: true,
                       virtualbox__intnet: "k3s-metallb-net"
    router.vm.network "private_network",
                       ip: "192.168.90.1",
                       netmask: "255.255.255.0",
                       auto_config: true,
                       virtualbox__intnet: "client-metallb-net"
     router.vm.host_name = "router"
     router.ssh.insert_key = false
     router.vm.provision "shell", inline: $configureRouter                       
     router.vm.provider "virtualbox" do |v|
       v.customize ["modifyvm", :id, "--ostype", "Debian_64"]
       v.cpus = 1
       v.memory = 512
     end
  end
  
  config.vm.define "client" do |client|
    client.vm.box = "ubuntu/bionic64"
    client.vm.network "private_network",
                       ip: "192.168.90.10",
                       netmask: "255.255.255.0",
                       auto_config: true,
                       virtualbox__intnet: "client-metallb-net"
     client.vm.host_name = "client"
     client.ssh.insert_key = false
     client.vm.provision "shell", inline: $configureClient                       

     client.vm.provider "virtualbox" do |v|
       v.customize ["modifyvm", :id, "--ostype", "Debian_64"]
       v.cpus = 1
       v.memory = 512
     end
  end

end