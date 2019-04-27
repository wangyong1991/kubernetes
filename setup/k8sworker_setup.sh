# 重置kubeadm
echo "----------------重置系统环境--------------------"
sudo kubeadm reset

# 重置iptables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
sudo sysctl net.bridge.bridge-nf-call-iptables=1

# 重置网卡信息
sudo ip link del cni0
sudo ip link del flannel.1

# 关闭防火墙
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# 禁用SELINUX
setenforce 0

# vim /etc/selinux/config
sudo sed -i "s/SELINUX=.*/SELINUX=disable/g" /etc/selinux/config

# 关闭系统的Swap方法如下:
# 编辑`/etc/fstab`文件，注释掉引用`swap`的行，保存并重启后输入:
sudo swapoff -a #临时关闭swap
sudo sed -i 's/.*swap.*/#&/' /etc/fstab 

echo "----------------检查Docker是否安装--------------------"
sudo yum list installed | grep 'docker-ce'
if [  $? -ne 0 ];then
	echo "Docker未安装"
	echo "----------------安装 Docker--------------------"
	# 卸载docker
	sudo yum remove -y $(rpm -qa | grep docker)
	# 安装docker
	sudo yum install -y yum-utils device-mapper-persistent-data lvm2
	sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
	sudo yum install -y docker-ce
	# 重启docker
	sudo systemctl enable docker
	sudo systemctl restart docker
else
	echo "Docker已安装"
fi

echo "----------------修改yum源--------------------"
# 修改为aliyun yum源
cat <<EOF > kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

sudo mv kubernetes.repo /etc/yum.repos.d/

# 查看可用版本
# sudo yum list --showduplicates | grep 'kubeadm\|kubectl\|kubelet'
# 安装 kubeadm, kubelet 和 kubectl
echo "----------------移除kubelet kubeadm kubectl--------------------"
sudo yum remove -y kubelet kubeadm kubectl


echo "----------------删除残留配置文件--------------------"
# 删除残留配置文件
modprobe -r ipip
lsmod
sudo rm -rf ~/.kube/
sudo rm -rf /etc/kubernetes/
sudo rm -rf /etc/systemd/system/kubelet.service.d
sudo rm -rf /etc/systemd/system/kubelet.service
sudo rm -rf /usr/bin/kube*
sudo rm -rf /etc/cni
sudo rm -rf /opt/cni
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/etcd

echo "----------------配置cni--------------------"
# 配置cni
sudo mkdir -p /etc/cni/net.d/

cat <<EOF > 10-flannel.conflist
{
  "name": "cbr0",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}
EOF
sudo mv 10-flannel.conflist /etc/cni/net.d/

echo "----------------安装 cni/kubelet/kubeadm/kubectl--------------------"
# 安装 cni/kubelet/kubeadm/kubectl
sudo yum install -y kubernetes-cni-0.6.0-0.x86_64 kubelet-1.13.1 kubeadm-1.13.1 kubectl-1.13.1 --disableexcludes=kubernetes
# 重新加载 kubelet.service 配置文件
sudo systemctl daemon-reload

echo "----------------启动 kubelet--------------------"
# 启动 kubelet
sudo systemctl enable kubelet
sudo systemctl restart kubelet

sudo sysctl net.bridge.bridge-nf-call-iptables=1

echo "----------------启用 ipv6--------------------"
# 启用 ipv6
sudo sed -i 's\ipv6.disable=1\ipv6.disable=0\g' /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

echo "----------------安装完成，重启机器--------------------"
sudo reboot