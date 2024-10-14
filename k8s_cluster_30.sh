#!/bin/bash

install_dependencies() {
	echo -e "\n"
	echo "INSTALLING DEPENDENCIES"
	echo -e "\n"
	sudo swapoff -a
	# sysctl params required by setup, params persist across reboots
	cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
	net.ipv4.ip_forward = 1
EOF

	# Apply sysctl params without reboot
	sudo sysctl --system	
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

	curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

	echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

	sudo apt-get update -y
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
}

install_changeuser() {                            
	echo -e '\n'
	echo 'CHANGE USER'
	echo -e '\n'
	sudo -i bash <<'EOF'
	echo "Running as $(whoami)"
	apt install socat
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