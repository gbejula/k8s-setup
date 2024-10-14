#!/bin/bash

install_dependencies() {
	echo -e '\n'
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
	net.ipv4.ip_forward
EOF

sudo sysctl --system

	lsmod | grep br_netfilter
	lsmod | grep overlay
}



install_containerd() {
	echo -e '\n'
	echo 'INSTALLING CONTAINERD'
	echo -e '\n'
	sudo apt-get update
	sudo apt-get install ca-certificates curl -y
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	echo \
  		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  		$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  		sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	sudo apt-get update
	sudo apt install containerd.io -y

	containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | sed 's/sandbox_image = "registry.k8s.io\/pause:3.6"/sandbox_image = "registry.k8s.io\/pause:3.9"/' | sudo tee /etc/containerd/config.toml

	sudo systemctl restart containerd
}

install_kubernetes() {
	echo -e '\n'
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
	echo -e '\n'
	echo 'CHANGE USER'
	echo -e '\n'
	sudo -i bash <<'EOF'
	echo "Running as $(whoami)"
	kubeadm init --pod-network-cidr=10.200.0.0/16 --apiserver-advertise-address=192.68.33.15
EOF
}

create_home() {
	echo -e "\n"
	echo "CREATE HOME"
	echo -e "\n"
	echo "Running as $(whoami)"
	mkdir -p $HOME/.kube
	sudo cp -i /etc/Kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

install_all() {
	install_dependencies
	install_containerd
	install_kubernetes
	install_changeuser
	create_home
}

install_all