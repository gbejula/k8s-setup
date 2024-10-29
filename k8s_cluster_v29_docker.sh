#!/bin/bash

install_dependencies() {
	echo -e '\n\n\n'
	echo 'INSTALLING DEPENDENCIES'
	echo -e '\n'
	sudo apt-get update
	sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
	overlay
	br_netfilter
EOF

	sudo modprobe overlay
	sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
	net.bridge.bridge-nf-call-iptables = 1
	net.bridge.bridge-nf-call-iptables = 1
	net.ipv4.ip_forward				   = 1
EOF

sudo sysctl --system

	lsmod | grep br_netfilter
	lsmod | grep overlay
}


install_docker() {
    echo -e "\n\n\n"
    echo "INSTALLING DCOKER"
    echo -e "\n"
    # Update the apt package index
    sudo apt-get update
    
    # Install required packages to allow apt to use a repository over HTTPS
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker’s official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the stable repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine, CLI, and containerd
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker

    containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | sed 's/sandbox_image = "registry.k8s.io\/pause:3.6"/sandbox_image = "registry.k8s.io\/pause:3.9"/' | sudo tee /etc/containerd/config.toml

    sudo systemctl restart docker

    # Test the installation
    sudo docker --version
}

install_kubernetes() {
	echo -e '\n\n\n'
	echo 'INSTALLING KUBERNETES'
	echo -e '\n'
	sudo apt-get update

	sudo apt-get install -y apt-transport-https ca-certificates curl gpg

	curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

	echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

	sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
}

install_changeuser() {                            
	echo -e '\n\n\n'
	echo 'CHANGE USER'
	echo -e '\n'
	sudo -i bash <<'EOF'
	echo "Running as $(whoami)"
	apt install socat
	kubeadm init --pod-network-cidr=10.200.0.0/16 --apiserver-advertise-address=xxxxxxxxxxxxxxxx
EOF
}

create_home() {
	echo -e "\n\n\n"
	echo "CREATE HOME"
	echo -e "\n"
	echo "Running as $(whoami)"
	mkdir -p $HOME/.kube
	sudo cp -i /etc/Kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config
	echo -e "\n\n\n"
	kubectl get nodes
}

install_all() {
	install_dependencies
	install_docker
	install_kubernetes
	install_changeuser
	create_home
}

install_all