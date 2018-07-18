sunboot
-------

sunboot makes it easy to get an operating system running on Sun hardware. This is the sister project to a similar utility for Silicon Graphics computers called [irixboot](https://github.com/halfmanhalftaco/irixboot).

## Contents

- [How it works](#howitworks)
- [Features](#features)
- [Requirements](#requirements)
- [Configuration](#configuration)
  - [Vagrantfile](#config_vagrant)
  - [sunboot-settings](#sunboot-settings)
  - [targets](#config_targets)
- [Security](#security)
- [Operating System-specific Examples](#examples)
  - [Diskless SunOS 4.1.4 on SPARCstation IPC](#sunos_ipc)
  - [Diskful Solaris 2.3 on SPARCclassic](#sol_classic)
- [Maintenance](#maint)
- [License](#license)


## <a name="howitworks"></a>How it works

Sun hardware was designed with the network in mind and nearly every Sun machine I've come across has baked-in support for booting from Ethernet devices. The code in PROM knows enough to be able to initialize the ethernet adapter and send a broadcast request for its IP address via RARP. Once the machine has its IP address it sends a request via TFTP (UDP port 69) to the address that replied to RARP for a file whose name is the hexadecimal representation of the IP address. This file is the bootloader (often called 'boot' or 'inetboot') and is loaded into RAM and executed.

The bootloader program knows how to use RPC to call BOOTPARAMS and retrieve information about which filesystems to mount via NFS. It contains enough code to download the kernel via NFS. Control is then passed over to the kernel which then brings the system up the rest of the way.

Later hardware supports the more modern DHCP for booting but most machines can fall back to RARP/TFTP.

---

## <a name="features"></a>Features

- Simple configuration
- Supports multiple simultaneous clients running different OS versions
- Diskless-client install & autoconfiguration
- Remote install for diskful-client systems
    - Emulates remote tape and CD-ROM devices as install sources
    - Supports netbooting the miniroot environment for formatting local disks and running the installer
- Supports both SunOS and Solaris (diskless support for Solaris is in the works)
- Boots (probably) any RARP/TFTP/BOOTPARAMS/NFS capable Sun workstation and operating system 

This project is in its early stages so right now it only supports the following:

- Only SunOS 4.1.4 (Solaris 1.1.2) and Solaris 2.3 have been tested at this point.
- CD-based operating systems (SunOS 4.1.x, Solaris)
- Diskful (remote install) and Diskless support for SunOS 4.1.x
- Diskful (remote install) support for Solaris

### Planned features

- Diskless Solaris installs
- Tape-based SunOS installs (including pre-SPARC systems)
- Non-Sun OS support (netbsd, Linux)
- Centralized user/group/host management (yp/NIS/NIS+)
- Support for installing sunboot on other non-x86 systems (Raspberry Pi, etc.)

---

## <a name="requirements"></a> Requirements

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://www.vagrantup.com/)

Hardware-wise, any virtualization-capable Intel-based computer should work. VirtualBox and Vagrant support Linux, MacOS and Windows.

---

## <a name="configuration"></a>Configuration

sunboot has configuration distributed in a few locations. To fully configure sunboot, the following will need to be edited to suit your environment:

- [Vagrantfile](#vagrantfile)
- [sunboot-settings](#sunboot-settings)
- [targets directory](#config_targets)

### <a name="vagrantfile"></a> Vagrantfile

First, the `Vagrantfile` has one item that needs to be configured: the bridge interface. sunboot must be bridged to (not NAT-ed) to the network where the Sun machine(s) are connected. This is to support the broadcast traffic required to bring these machines up. Fill in your network interface name (can be determined with `VBoxManage list bridgedifs`, the `Name` is the field it looks for). In this example, `eth1` is the interface to be bridged. If this is not filled out, Vagrant will ask at startup which interface to use.

```ruby
  config.vm.network "public_network", auto_config: false, bridge: "eth1"
```

### <a name="sunboot-settings"></a> sunboot-settings

The next configuration step is the server configuration. This contains the hostname, IP address, netmask and gateway of the server. This should be chosen to not interfere with existing machines on the bridged network and be outside of any DHCP address ranges that may be present on the network.

```bash
# General environment settings

SERVERNAME=sunboot
SERVERADDR=10.94.42.7
NETMASK=255.255.255.0
GATEWAY=10.94.42.1
```

### <a name="config_targets"></a> targets directory

Files in this directory specify the settings for individual machines to enable netbooting for.

Example:

```bash
# SPARCstation IPC SunOS 4.1.4 Diskless Install Example

TARGETARCH=sun4c
TARGETNAME=hobbes
TARGETETHER=8:0:20:a:7d:8f
TARGETADDR=10.94.42.208
TARGETSWAPSIZE=64

# options: DISKLESS or DISKFUL
INSTALLMETHOD=DISKLESS

# options: CDROM or TAPE
INSTALLMEDIA=CDROM

# path (within 'sunos' directory) to the install CD-ROM or directory that contains 'tape1', 'tape2', etc. dirs
INSTALLMEDIAPATH=solaris1.1.2.iso
```

`TARGETARCH` should be set to the correct kernel architecture required for your machine.

Examples:

- Sun-2 machines are always `sun2`
- Sun-3 machines are either `sun3` or later 68030-based machines are `sun3x`
- Early SPARC machines are `sun4`, while SPARCstation 1-era machines are `sun4c`. Machines based on the multiprocessor-capable architecture (SPARCstation 10, 20 and relatives) are `sun4m`.
  - There are some fairly esoteric derivatives of these such as `sun4d`, `sun4e`, `sun4u1` and `sun4us`
- UltraSPARC I, II, III and IV machines are `sun4u`
- UltraSPARC T1 and later are `sun4v`

`TARGETSWAPSIZE` is the size of the swapfile allocated to the machine, in megabytes. A general rule of thumb is RAM * 2.

A `DISKFUL` install will configure the machine to boot into the installer for the operating system media provided. For SunOS 4.1.x this will boot the machine into `miniroot` and boot to a shell where one can run `format` to label local disks and then `suninstall` to perform an installation. For Solaris this will boot into the graphical installer if a keyboard is present.

A `DISKFUL` install tries to emulate a full install of the operating system. Currently this is only supported for SunOS 4.1.x. All of the available software sets are extracted to disk and exported via NFS. The operating system is customized per the target configuration to set the IP address and hostname.

Install media should be placed in the provided `sunos` directory. Paths specified in `INSTALLMEDIAPATH` are relative to this directory.

---

## <a name="security"></a>Security

sunboot configures the virtual machine in a way that is inherently insecure. The boot process was designed in an era where the network was considered fully trusted so security on the modern Linux-based operating system that sunboot uses must be bypassed in several cases to make things work.

It is recommended to airgap or at minimum heavily firewall the network that sunboot is configured on.

- `rsh` is enabled and allows passwordless root login to SunOS diskful installs. This is required to support remote media access.
- read-write NFS exports are restricted by IP address only, there is no other authentication in place which means other machines on the network could potentially access NFS on these exports as root or any other user without restriction. Static ARP entries are entered on the sunboot VM to mitigate.

The sunboot VM does require internet access during `vagrant up` in order to download the required Debian packages. After the initial configuration is complete it can be disconnected from the internet.

---

## <a name="examples"></a> Operating System-specific Examples

### <a name="sunos_ipc"></a> Diskless SunOS 4.1.4 on a SPARCstation IPC

Using the following target configuration, here are the steps to start up sunboot and boot the SPARCstation. 

`targets/hobbes`:

```bash
# SPARCstation IPC SunOS 4.1.4 Diskless Install Example

TARGETARCH=sun4c
TARGETNAME=hobbes
TARGETETHER=8:0:20:a:7d:8f
TARGETADDR=10.94.42.208
TARGETSWAPSIZE=64

# options: DISKLESS or DISKFUL
INSTALLMETHOD=DISKLESS

# options: CDROM or TAPE
INSTALLMEDIA=CDROM

# path (within 'sunos' directory) to the install CD-ROM or directory that contains 'tape1', 'tape2', etc. dirs
INSTALLMEDIAPATH=solaris1.1.2.iso
```

On host machine:
```
$ git clone https://github.com/halfmanhalftaco/sunboot.git
$ cd sunboot
$ vi Vagrantfile sunboot-settings targets/hobbes            # edit the configurations
$ vagrant up
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Importing base box 'debian/contrib-jessie64'...
==> default: Matching MAC address for NAT networking...
==> default: Checking if box 'debian/contrib-jessie64' is up to date...
==> default: Setting the name of the VM: sunboot_default_1531929476572_79046
==> default: Clearing any previously set network interfaces...
==> default: Preparing network interfaces based on configuration...
    default: Adapter 1: nat
    default: Adapter 2: bridged
==> default: Forwarding ports...
    default: 22 (guest) => 2222 (host) (adapter 1)
==> default: Running 'pre-boot' VM customizations...
==> default: Booting VM...
<snip>
==> default: Mounting shared folders...
    default: /vagrant => F:/src/sunboot
==> default: Running provisioner: initialize (shell)...
    default: Running: C:/Users/sunboot/AppData/Local/Temp/vagrant-shell20180718-6128-1w9bupk
    default: Renaming machine to 'sunboot'...
    default: Installing packages...
    default: Adjusting kernel settings...
    default: Enable rdate service...
    default: Creating server directories...
    default: Configuring NFS daemons...
    default: Setting up rsh shims...
    default: Configuring bridge interface...
    default: sunboot initialization complete.
==> default: Running provisioner: provision (shell)...
    default: Running: C:/Users/sunboot/AppData/Local/Temp/vagrant-shell20180718-6128-3rk3gf
    default: --------------------------------------
    default: Installing target "hobbes"...
    default: --------------------------------------
    default: Mounting CD-ROM image...
    default: Found SunOS 4.1.4
    default: --------------------------------------
    default: SunOS 4.1.4 SUNBIN
    default: sun4c, sun4, sun4m
    default: CD-ROM (boot format) 1 of 1
    default: 258-4662
    default: Solaris(R) 1.1.2
    default: Sun-4(TM), Sun-4c, Sun-4m, SPARC(R)
    default: Part Number: 258-4662
    default: CD-ROM (1 of 1) ISO 9660 format
    default: --------------------------------------
    default: Available architectures on this media:
    default: sun4.sun4c.sunos.4.1.4
    default: sun4.sun4.sunos.4.1.4
    default: sun4.sun4m.sunos.4.1.4
    default: Detected version: 4.1.4
    default: Selected architecture: sun4.sun4c.sunos.4.1.4
    default: Creating diskless install...
    default: Extracting "debugging" set...
    default: Extracting "demo" set...
    default: Extracting "games" set...
    default: Extracting "graphics" set...
    default: Extracting "install" set...
    default: Extracting "networking" set...
    default: Extracting "openwindows_demo" set...
    default: Extracting "openwindows_fonts" set...
    default: Extracting "openwindows_programmers" set...
    default: Extracting "openwindows_users" set...
    default: Extracting "rfs" set...
    default: Extracting "security" set...
    default: Extracting "shlib_custom" set...
    default: Extracting "sunview_demo" set...
    default: Extracting "sunview_programmers" set...
    default: Extracting "sunview_users" set...
    default: Extracting "system_v" set...
    default: Extracting "text" set...
    default: Extracting "tli" set...
    default: Extracting "user_diag" set...
    default: Extracting "usr" set...
    default: Extracting "uucp" set...
    default: Extracting "versatec" set...
    default: Extracting "manual" set...
    default: --------------------------------------
    default: Install complete for "hobbes".
    default: --------------------------------------

==> default: Machine 'default' has a post `vagrant up` message. This is a message
==> default: from the creator of the Vagrantfile, and not from Vagrant itself:
==> default:
==> default: ["sunboot initialization complete."]

```

At this stage the server is now ready to boot the target machine. From the target machine, all that should be required is a `boot net` command. The following is the output from the serial console:

```
not nvramrc
SPARCstation IPC, No keyboard.
ROM Rev. 1.6, 32 MB memory installed, Serial #687503.
Ethernet address 8:0:20:a:7d:8f, Host ID: 520a7d8f.


Testing
Type b (boot), c (continue), or n (new command mode)
>n
ok boot net
Booting from: le(0,0,0)
1ee00 Using IP Address 10.94.42.208 = 0A5E2AD0
hostname: hobbes
domainname: (none)
server name 'sunboot'
root pathname '/export/root/hobbes'
root on sunboot:/export/root/hobbes fstype nfs
Boot: vmunix
Size: 1343488+218832+131992 bytes
SunOS Release 4.1.4 (GENERIC) #2: Fri Oct 14 11:08:06 PDT 1994
Copyright (c) 1983-1993, Sun Microsystems, Inc.
mem = 32768K (0x2000000)
avail mem = 30531584
Ethernet address = 8:0:20:a:7d:8f
cpu = Sun 4/40
zs0 at obio 0xf1000000 pri 12
zs1 at obio 0xf0000000 pri 12
fd0 at obio 0xf7200000 pri 11
audio0 at obio 0xf7201000 pri 13
sbus0 at SBus slot 0 0x0
dma0 at SBus slot 0 0x400000
esp0 at SBus slot 0 0x800000 pri 3
esp0: Warning- no devices found for this SCSI bus
le0 at SBus slot 0 0xc00000 pri 5
dma1 at SBus slot 1 0x81000
esp1 at SBus slot 1 0x80000 pri 3
esp1: Warning- no devices found for this SCSI bus
lebuffer0 at SBus slot 1 0x40000
le1 at SBus slot 1 0x60000 pri 5
cgsix0 at SBus slot 2 0x0 pri 7
cgsix0: screen 1152x900, single buffered, 1M mappable, rev 6
bwtwo0 at SBus slot 3 0x0 pri 7
hostname: hobbes
domainname: (none)
root on sunboot:/export/root/hobbes fstype nfs
swap on sunboot:/export/swap/hobbes fstype nfs size 65536K
dump on sunboot:/export/swap/hobbes fstype nfs size 65524K

<some garbage on the line snipped>

hobbes login: root
Jul 18 16:23:52 hobbes login: ROOT LOGIN console
Last login: Wed Jul 18 16:17:19 from 10.94.42.30
SunOS Release 4.1.4 (GENERIC) #2: Fri Oct 14 11:08:06 PDT 1994
hobbes#

```


### <a name="sol_classic"></a> Diskful install of Solaris 2.3 on a SPARCclassic

`targets/ssx`:

```bash
# SPARCclassic Solaris 2.3 Diskful Install Example

TARGETARCH=sun4m
TARGETNAME=ssx
TARGETETHER=8:0:20:5:61:c2
TARGETADDR=10.94.42.209
TARGETSWAPSIZE=64

# options: DISKLESS or DISKFUL
INSTALLMETHOD=DISKFUL

# options: CDROM or TAPE
INSTALLMEDIA=CDROM

# path (within 'sunos' directory) to the install CD-ROM or directory that contains 'tape1', 'tape2', etc. dirs
INSTALLMEDIAPATH=solaris_2.3_sparc.iso
```

```
$ git clone https://github.com/halfmanhalftaco/sunboot.git
$ cd sunboot
$ vi Vagrantfile sunboot-settings targets/ssx              # edit the configurations
$ vagrant up
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Importing base box 'debian/contrib-jessie64'...
==> default: Matching MAC address for NAT networking...
==> default: Checking if box 'debian/contrib-jessie64' is up to date...
==> default: Setting the name of the VM: sunboot_default_1531931457995_66060
==> default: Clearing any previously set network interfaces...
==> default: Preparing network interfaces based on configuration...
    default: Adapter 1: nat
    default: Adapter 2: bridged
==> default: Forwarding ports...
    default: 22 (guest) => 2222 (host) (adapter 1)
==> default: Running 'pre-boot' VM customizations...
==> default: Booting VM...
<snip>
==> default: Mounting shared folders...
    default: /vagrant => F:/src/sunboot
==> default: Running provisioner: initialize (shell)...
    default: Running: C:/Users/sunboot/AppData/Local/Temp/vagrant-shell20180718-20392-1ylgzm6
    default: Renaming machine to 'sunboot'...
    default: Installing packages...
    default: Adjusting kernel settings...
    default: Enable rdate service...
    default: Creating server directories...
    default: Configuring NFS daemons...
    default: Setting up rsh shims...
    default: Configuring bridge interface...
    default: sunboot initialization complete.
==> default: Running provisioner: provision (shell)...
    default: Running: C:/Users/sunboot/AppData/Local/Temp/vagrant-shell20180718-20392-1yn3bxy
    default: --------------------------------------
    default: Installing target "ssx"...
    default: --------------------------------------
    default: Mounting CD-ROM image...
    default: Found Solaris 2.3
    default: --------------------------------------
    default: Solaris(TM) 2.3 Hardware: 8/94, Binary
    default: SPARC SUNBIN
    default: CD-ROM (Rockridge Format)
    default: Part Number: 258-4455
    default: --------------------------------------
    default: Available architectures on this media:
    default: sparc.sol5.Solaris_2.3
    default: sparc.sol6.Solaris_2.3
    default: sparc.sun4c.Solaris_2.3
    default: sparc.sun4d.Solaris_2.3
    default: sparc.sun4e.Solaris_2.3
    default: sparc.sun4m1.Solaris_2.3
    default: sparc.sun4m.Solaris_2.3
    default: sparc.sun4.Solaris_2.3
    default: Detected version: Solaris_2.3
    default: Selected architecture: sparc.sun4m.Solaris_2.3
    default: Copying sun4m miniroot to /export/root/ssx
    default: Configuring NFS exports...
    default: Configuring bootparams...
    default: --------------------------------------
    default: Install complete for "ssx".
    default: --------------------------------------

==> default: Machine 'default' has a post `vagrant up` message. This is a message
==> default: from the creator of the Vagrantfile, and not from Vagrant itself:
==> default:
==> default: ["sunboot initialization complete."]

```

Serial console:
```
SPARCclassic, No Keyboard
ROM Rev. 2.12, 72 MB memory installed, Serial #190146.
Ethernet address 8:0:20:5:61:c2, Host ID: 8002e6c2.



Type  help  for more information
ok boot net
Boot device: /iommu/sbus/ledma@4,8400010/le@4,8c00000   File and args:
hostname: ssx
domainname: (none)
root server: sunboot
root directory: /export/root/ssx
SunOS Release 5.3 Version Generic [UNIX(R) System V Release 4.0]
Copyright (c) 1983-1993, Sun Microsystems, Inc.
WARNING: TOD clock not initialized -- CHECK AND RESET THE DATE!
Configuring the /devices directory
Configuring the /dev directory
The system is coming up.  Please wait.

What type of terminal are you using?
 1) ANSI Standard CRT
 2) DEC VT52
 3) DEC VT100
 4) Heathkit 19
 5) Lear Siegler ADM31
 6) PC Console
 7) Sun Command Tool
 8) Sun Workstation
 9) Televideo 910
 10) Televideo 925
 11) Wyse Model 50
 12) Other
Type the number of your choice and press Return:3
starting rpc services: rpcbind sysidnis


Do you want to configure this system as a client of a name service?  If so,
which name service do you want to use?  If you do not want to use a name
service select `none' and consult your Install documentation.



                          lqqqqqqqqqqqqqqqqqqqqqqqqqk
                          x>NIS+ Client             x
                          x NIS (formerly yp) Clientx
                          x None - use /etc files   x
                          mqqqqqqqqqqqqqqqqqqqqqqqqqj




Use the arrow keys to select an item. (CTRL-n next, CTRL-p previous)

Press Return to continue.

Does this workstation's network have sub-networks?



                                     lqqqqk
                                     x>No x
                                     x Yesx
                                     mqqqqj




Use the arrow keys to select an item. (CTRL-n next, CTRL-p previous)

Press Return to continue.

This is your default netmask value.  You may change it if necessary, but the
format must remain as four numbers separated by periods.


                         lqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
                         x                            x
                         x Netmask:  255.255.255.0___ x
                         x                            x
                         mqqqqqqqqqqqqqqqqqqqqqqqqqqqqj




Press Return to continue.

Is the following information correct?

Name service:  none
Network is sub-netted:  Yes
Netmask:  255.255.255.0



                          lqqqqqqqqqqqqqqqqqqqqqqqqqk
                          x No, re-enter informationx
                          x>Yes, continue           x
                          mqqqqqqqqqqqqqqqqqqqqqqqqqj




Use the arrow keys to select an item. (CTRL-n next, CTRL-p previous)

Press Return to continue.

< time zone selection screens, etc. snipped >

lqqqqqqqqqqqqqqqqqqqqqqqqqqq[ Solaris Installation ]qqqqqqqqqqqqqqqqqqqqqqqqqqqk
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x  ( Quick Install... )                                                        x
x                                                                              x
x  ( Custom Install... )                                                       x
x                                                                              x
x  ( Exit Install... )                                                         x
x                                                                              x
x  ( Help... )                                                                 x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
tqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqu
x <Return> Select; <Tab> Next Field; <F1> Help                                 x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
```

---

## Maintenance

Since sunboot supports diskless clients you probably don't want to be destroying/recreating the VM very often. There's a couple commands built in that help add new clients and remove old ones.

To run these commands you'll need to log into the Vagrant VM with `vagrant ssh`.

### Commands

- `sudo target_rm <target_name>`
   - This will remove all of the install artifacts for the given target, including its NFS exports, root filesystem, etc. It does *not* remove the target configuration file or the generic miniroot/exec/protoroot environment for the target's operating system.
   - This is particularly recommended for SunOS diskful targets after the OS has been installed to disable root rsh capability to the boot server.
- `sudo install_targets`
    - Run this command to reprocess all the target files in the `targets` directory. It skips any targets that already have root filesystems in place (in `/export/root/<targethostname>`)
- `sudo mount_media <target_name>`
    - When multiple machines are configured for diskful installs, the correct install media may not be ready for the client. Run this to ensure that the appropriate media for this target is configured.

---

## License
The MIT License

Copyright 2018 Andrew Liles

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.