# v/zee-rho-00

# Setup Ubuntu Cloud Image

# XStackIt 2019 - MIT License

## [bionic-snapd-lxd-btrfs-docker-portainer]

### Description

Ubuntu Cloud Images do not require an installation procedure, only configuration.

bionic-server-cloudimg-amd64-setup.sh:

1. Detect and address hypervisor quirks. (vmware only atm)
2. Purge LXD installed via Apt.
3. Install LXD from Snap.
4. Initialize LXD using preseed configuration.
5. LXD preseed selects LXD managed btrfs on block device.
6. Fix LXD local DNS resolution for containers.
7. Launch an ubuntu:bionic image to host Docker.
8. Install and configure Docker in LXD container.
9. Install and configure Portainer.io in Docker LXD container.
10. Update and upgrade packages for LXD host and containers.
11. Take LXD managed snapshot of Docker LXD container.
12. Cleanup and  Reboot Ubuntu Cloud Image.

Less than 10 min setup on fast hardware with fast inet.

### Compatibility

##### Windows 10 Pro + VMware WS Pro 15
 - bionic-server-cloudimg-amd64.ova = working
 - open vm, preseed the public key in prompt, leave the rest default
 - ssh -i ~/.ssh/id_rsa ubuntu@<look at vmware console for IP>
 - use ssh tunnel to access portainer @ 9000:L<lxd container ip>:9000
 - browse to: http://localhost:9000 and configure portainer
 - DO NOT UPGRADE THE VM! Breaks for me every time.

##### Windows 10 Pro + Hyper-V
 - bionic-server-cloudimg-amd64.vhd = not working
 - extract VHD (32GB!), new vm, select vhd, can edit and convert to dynamic sizing, reduces image size to 1-2GB
 - needs user-data and meta-data to make this work. found a solution not sure if it works yet.

##### Ubuntu Desktop + KVM = untested
 - next target after Hyper-V

##### AWS EC2 = untested
 - will probably work but assign $lxd_btrfs_blockdev to something appropriate like maybe /dev/xvdf

### Instructions

1. Fetch bionic-server-cloudimg-amd64-setup.sh
2. Make executable. (chmod +x bionic-server-cloudimg-amd64-setup.sh)
3. Execute setup.sh (./bionic-server-cloudimg-amd64-setup.sh)

The default 'ubuntu' account has a NOPASSWD directive in sudoers, so sudo is used a lot throughout the script but not used to execute 'bionic-server-cloudimg-amd64-setup.sh'. 

### ToDo
 - Append authorized_keys from URL
 - Append authorized_keys from string
 - More sanity checks
 - Do something about all the sleep-iness
 - Find a (better) way to check if a container exists
 - iptables rules
 - print pertinent info

### Notes
Thank You GitHub Developer Support!

