# Create Unattended Ubuntu 18.04 Server Installation ISO

## Automate ubuntu installation and LXD initialization using predefined configuration.

#### ToDo

Borrow heavily from existing projects as to not reinvent the wheel and expedite delivery of a working environment.

#### Instructions

1. Install Ubuntu 18.04 somewhere to build the ISO.
2. Install and configure git client.
3. Clone (or mirror) xstackit/unattended-install
4. Change working dir eg cd xstackit/unattended-install
5. Edit build file and save changes.
6. Edit answers file and save changes.
7. Edit lxdhost file and save changes.
8. Make executable: chmod +x create-iso.sh
9. Now execute: sudo ./create-iso.sh

#### What should create-iso.sh do exactly?

create-iso.sh should:
1. Set important variables using config file
2. Install any necessary packages required to build the ISO successfully.
3. Donwload official Ubuntu 18.04 Server ISO file (currently testing with mini.iso)
4. Amend preseed.cfg file using answers file
5. Amend lxdseed.cfg file using lxdhost file
6. Create ISO in directory specified in config file.

### How To Install Using The Created ISO

Target install host needs MINIMUM two disk volumes: One for root system (ext4) and one for container storage filesystem (currently btrfs or zfs)
Future options may include ability to define multiple pre-initialized storage volumes, seperate /, /home, and /snap volumes.
Mount ISO and install. The entire installation process is automated (unattended).
