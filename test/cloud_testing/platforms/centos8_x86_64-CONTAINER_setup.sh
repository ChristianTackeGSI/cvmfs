#!/bin/sh

# source the common platform independent functionality and option parsing
script_location=$(dirname $(readlink --canonicalize $0))
. ${script_location}/common_setup.sh

# install CernVM-FS RPM packages
echo "installing RPM packages... "
install_rpm "$CONFIG_PACKAGES"
install_rpm $CLIENT_PACKAGE

[ "x$SERVICE_CONTAINER" != "x" ] || die "fail (service container missing)"
mkdir -p /tmp/cvmfs-service-container
cp -v $SERVICE_CONTAINER /tmp/cvmfs-service-container/docker.tar.gz || \
  die "fail (planting service container)"

# Singularity is in epel
echo "enabling epel yum repository..."
install_from_repo epel-release    || die "fail (install epel-release)"

# Container runtimes and tools
install_from_repo singularity     || die "fail (install singularity)"
install_from_repo runc            || die "fail (install runc)"
install_from_repo fuse-overlayfs  || die "fail (install fuse-overlayfs)"
install_from_repo podman          || die "fail (install podman)"
install_from_repo jq              || die "fail (install jq)"

sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install docker-ce --nobest -y || die "fail (install docker-ce)"
sudo firewall-cmd --zone=public --add-masquerade --permanent
sudo firewall-cmd --reload

# Make docker available to sftnight
sudo mkdir /usr/lib/systemd/system/docker.socket.d
echo "[Socket]" | sudo tee /usr/lib/systemd/system/docker.socket.d/10-sftnight.conf
echo "SocketGroup=sftnight" | sudo tee -a /usr/lib/systemd/system/docker.socket.d/10-sftnight.conf
sudo systemctl daemon-reload

sudo systemctl start docker            || die "fail (starting docker)"
docker ps                              || die "fail (accessing docker)"

install_rpm https://ecsft.cern.ch/dist/cvmfs/builddeps/minikube-1.9.2-0.x86_64.rpm || die "fail (install minikube)"

sudo curl -o /usr/bin/kind \
  https://ecsft.cern.ch/dist/cvmfs/builddeps/kind-v0.8.1 || die "fail (download kind)"
sudo chmod +x /usr/bin/kind                              || die "fail (activate kind)"
kind version                                             || die "fail (install kind)"

# install packages to deploy CSI driver
install_from_repo git     || die "fail (install git)"
install_from_repo golang  || die "fail (install golang)"

# setup environment
echo -n "setting up CernVM-FS environment..."
sudo cvmfs_config setup                          || die "fail (cvmfs_config setup)"
sudo mkdir -p /var/log/cvmfs-test                || die "fail (mkdir /var/log/cvmfs-test)"
sudo chown sftnight:sftnight /var/log/cvmfs-test || die "fail (chown /var/log/cvmfs-test)"
sudo systemctl start autofs                      || die "fail (systemctl start autofs)"
sudo cvmfs_config chksetup > /dev/null           || die "fail (cvmfs_config chksetup)"
echo "done"

disable_systemd_rate_limit
