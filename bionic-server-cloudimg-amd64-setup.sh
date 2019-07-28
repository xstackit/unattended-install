#!/usr/bin/env bash
# Setup Ubuntu Cloud Image
# XStackIt 2019 - MIT License
#
# [bionic-snapd-lxd-btrfs-docker-portainer]
#
# Description
# Ubuntu Cloud Images do not require an installation procedure, only configuration.
#
# bionic-server-cloudimg-amd64-setup.sh:
#
# 1. Detect and address hypervisor quirks. (vmware only atm)
# 2. Purge LXD installed via Apt.
# 3. Install LXD from Snap.
# 4. Initialize LXD using preseed configuration.
# 5. LXD preseed selects LXD managed btrfs on block device.
# 6. Fix LXD local DNS resolution for containers.
# 7. Launch an ubuntu:bionic image to host Docker.
# 8. Install and configure Docker in LXD container.
# 9. Install and configure Portainer.io in Docker LXD container.
# 10. Update and upgrade packages for LXD host and containers.
# 11. Take LXD managed snapshot of Docker LXD container.
# 12. Cleanup and  Reboot Ubuntu Cloud Image.
#
# Less than 10 min setup on fast hardware with fast inet.
#
# Compatibility
# Windows 10 Pro + VMware WS Pro 15
# - bionic-server-cloudimg-amd64.ova = working
# - open vm, preseed the public key in prompt, leave the rest default
# - ssh -i ~/.ssh/id_rsa ubuntu@<look at vmware console for IP>
# - use ssh tunnel to access portainer @ 9000:L<lxd container ip>:9000
# - browse to: http://localhost:9000 and configure portainer
# - DO NOT UPGRADE THE VM! Breaks for me every time.
# Windows 10 Pro + Hyper-V
# - bionic-server-cloudimg-amd64.vhd = not working
# - extract VHD (32GB!), new vm, select vhd, can edit and convert to dynamic sizing, reduces image size to 1-2GB
# - needs user-data and meta-data to make this work. found a solution not sure if it works yet.
# Ubuntu Desktop + KVM = untested
# - next target after Hyper-V
# AWS EC2 = untested
# - will probably work but assign $lxd_btrfs_blockdev to something appropriate like maybe /dev/xvdf
#
# ToDo
# - Append authorized_keys from URL
# - Append authorized_keys from string
# - More sanity checks
# - Do something about all the sleep-iness
# - Find a (better) way to check if a container exists
# - iptables rules
# - print pertinent info

# for testing
lxd_trust_password='insecure'

# for testing
lxd_btrfs_blockdev=/dev/sdb

# not implemented
authorized_key_url=''

echo 'Configuring Ubuntu Cloud Image...'

fail_message='Please report FAIL messages!'

# update apt repos
sudo apt update

# upgrade system packages
sudo apt-get upgrade -y

## boot nice for VMware

# if vmware guest update /etc/default/grub
[ $(lspci|grep -c VMware) > 1 ] && sudo sed -i s/GRUB_CMDLINE_LINUX_DEFAULT=/GRUB_CMDLINE_LINUX_DEFAULT='"console=ttyS0 ds=nocloud"'"\n"#GRUB_CMDLINE_LINUX_DEFAULT=/ /etc/default/grub

# if vmware guest persist grub config
[ $(lspci|grep -c VMware) > 1 ] && sudo update-grub

## SXE LXD ^_^

# purge LXD if installed by apt
[ -d "/var/lib/lxd" ] && sudo apt-get remove -y --purge $(dpkg --get-selections|grep 'lx[c\|d]'|cut -f1 -) || echo "LXD not installed with apt, moving along..."

# update snap repos
sudo snap refresh

# install LXD via snap if not already installed
[ -d "/var/snap/lxd" ] && echo "LXD already installed via snap, moving along..." || sudo snap install lxd --channel=stable

# prompt user to create and attach secondary volume for btrfs
[ ! -b $lxd_btrfs_blockdev ] && echo -n 'ADD SECOND VOLUME TO VM NOW AND WAIT!! DO NOT REBOOT!! ...'
while [ ! -b $lxd_btrfs_blockdev ]; do
    echo -n '.'
    sleep 3
done
[ -b $lxd_btrfs_blockdev ] && echo "OK! Found $lxd_btrfs_blockdev"
sleep 3

# Initialize LXD
echo -n 'Initializing LXD...'
cat <<EOF | sudo lxd init --preseed
config:
  core.https_address: '[::]:8443'
  core.trust_password: $lxd_trust_password
networks:
- config:
    ipv4.address: auto
    ipv4.nat: "true"
    ipv6.address: auto
    ipv6.nat: "true"
  description: "default lxd bridge"
  managed: true
  name: lxdbr0
  type: bridge
storage_pools:
- config:
    source: $lxd_btrfs_blockdev
  description: "default lxd storage"
  name: default
  driver: btrfs
profiles:
- config: {}
  description: Default LXD profile
  devices:
    eth0:
      name: eth0
      nictype: bridged
      parent: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
EOF

echo 'OK'
sleep 5

# check to see if LXD was installed
have_lxd=0
test_lxd=$(lxd > /dev/null 2>&1; echo $?)
[ "$test_lxd" == "127" ] && echo 'FAIL: LXD was not installed.' || have_lxd=1

# fix container DNS resolution if LXD installed
if [ $have_lxd == 1 ]; then
    # get ip of lxdbr0
    lxdbridge_ip=$(ip address show lxdbr0|grep 'inet '|cut -d: -f2|awk '{ print $2}'|sed "s/\/24//")
    sudo mkdir /etc/systemd/resolved.conf.d
    sudo touch /etc/systemd/resolved.conf.d/lxdbr0.conf
    echo '[Resolve]' | sudo tee /etc/systemd/resolved.conf.d/lxdbr0.conf
    echo "DNS=$lxdbridge_ip" | sudo tee -a /etc/systemd/resolved.conf.d/lxdbr0.conf
    echo 'Domains=lxd' | sudo tee -a /etc/systemd/resolved.conf.d/lxdbr0.conf
fi

# got butter?
have_btrfs=0
test_btrfs=$(sudo btrfs filesystem show | awk '/ path /{print $NF}')
[ ! $test_btrfs == $lxd_btrfs_blockdev ] && echo 'FAIL: LXD did not setup btrfs.' || have_btrfs=1

# can create container?
if [ $have_lxd == 1 ] && [ $have_btrfs == 1 ]; then

    echo '### LAUNCH ###'

    # create container
    lxc launch ubuntu:bionic dockerhost -c security.nesting=true

    sleep 10

    echo '### DOCKERENV ###'

    # docker host help
    lxc exec dockerhost -- touch /.dockerenv

    echo '### PUB KEYS ###'

    # push ubuntu/.ssh/authorized_keys to container
    [ -f /home/ubuntu/.ssh/authorized_keys ] && lxc file push /home/ubuntu/.ssh/authorized_keys dockerhost/home/ubuntu/.ssh/

    echo '### CONTAINER RESTART ###'

    # restart container
    lxc restart dockerhost

    sleep 5

    echo '### CAT DOCKERHOST.SH ###'

cat << EOF > dockerhost.sh
#!/usr/bin/env bash
# setup Docker in LXD container
sudo apt update
sudo apt-get upgrade -y
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt-get install -y docker-ce
EOF

    echo '### PUSH DOCKERHOST.SH ###'

    # push script to container
    lxc file push dockerhost.sh dockerhost/root/

    echo '### CHMOD DOCKERHOST.SH ###'

    # make script executable
    lxc exec dockerhost -- chmod +x /root/dockerhost.sh

    echo '### EXEC DOCKERHOST.SH ###'

    # execute script in container
    lxc exec dockerhost -- /root/dockerhost.sh

    sleep 2

    echo '### RESTART DOCKERHOST ###'

    # restart container
    lxc restart dockerhost

    sleep 4

    echo '### APT AUTOREMOVE ###'

    # autoremove unused packages
    lxc exec dockerhost -- sudo apt-get autoremove -y

    echo '### APT AUTOCLEAN ###'

    # clean repos of uninstalled packages
    lxc exec dockerhost -- sudo apt-get autoclean

    echo '### CAT PORTAINER.SH ###'

    # portainer test

cat << EOF > portainer.sh
#!/usr/bin/env bash
# setup portainer.io
docker volume create portainer_data
docker run -d --restart unless-stopped -p 8000:8000 -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer
docker container ls --all
EOF

    echo '### PUSH PORTAINER.SH ###'

    # push script to container
    lxc file push portainer.sh dockerhost/root/

    echo '### CHMOD PORTAINER.SH ###'

    # make script executable
    lxc exec dockerhost -- chmod +x /root/portainer.sh

    echo '### EXEC PORTAINER.SH ###'

    # execute script in container
    lxc exec dockerhost -- /root/portainer.sh

    sleep 5

    echo '### LS DOCKER CONTAINER ###'

    # how did it go
    lxc exec dockerhost -- docker container ls --all

    echo '### RESTART DOCKERHOST 2 ###'

    # restart container
    lxc restart dockerhost

    echo '### CLEANUP SH ON DOCKERHOST ###'

    # rm script in container
    lxc exec dockerhost -- rm /root/dockerhost.sh
    sleep 1
    lxc exec dockerhost -- rm /root/portainer.sh
    sleep 1

    # firewall setup

    echo '### DOCKERHOST SNAP ###'

    # take a picture of all the work
    lxc snapshot dockerhost first-snapshot

else
    echo "Something went wrong. $fail_message"
fi

## install additional packages

# ipset because huge lists of IP should not go in iptables rules
sudo apt-get install -y ipset

## cleanup

# autoremove unused packages
sudo apt-get autoremove -y

# clean repos of uninstalled packages
sudo apt-get autoclean

# clean all
sudo apt-get clean

# make the landing stick!
sudo reboot

exit 0

