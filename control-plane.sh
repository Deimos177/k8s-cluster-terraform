export DEBIAN_FRONTEND=noninteractive sudo apt -y upgrade
sudo apt update
sudo apt install -y net-tools
sudo netstat -tulpn | grep "6443\|2379\|2380\|10250\|10259\|10257"
sudo ufw allow 10257/tcp
sudo ufw allow 6443/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 2379/tcp
sudo ufw allow 2380/tcp
sudo ufw allow 10257/tcp
sudo apt install -y systemd-timesyncd
sudo timedatectl set-ntp true
sudo timedatectl status
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
sudo apt-get update && sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo swapoff -a
sudo sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo kubeadm init --pod-network-cidr 192.168.0.0/16
sleep 20
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
echo "alias k="kubectl"" >> /home/ubuntu/.bashrc
echo "alias apply="kubectl apply -f"" >> /home/ubuntu/.bashrc
echo "alias delete="kubectl delete"" >> /home/ubuntu/.bashrc
export do="--dry-run=client -o yaml"
export now="--force --grace-period 0"
sudo tee /home/ubuntu/.vimrc > /dev/null <<EOF
set tabstop=2
set expandtab
set shiftwidth=2
set number
EOF
sudo chmod 400 /home/ubuntu/.ssh/workers.pem
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh/workers.pem
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
./get_helm.sh