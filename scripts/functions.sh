#!/bin/bash

# sunboot functions.sh
CDROM=/cdrom

. /vagrant/scripts/utils.sh

function cdrom_detect() {
    if [ -f $CDROM/.cdtoc ]; then
        if [ $(grep PRODNAME $CDROM/.cdtoc | cut -d '=' -f 2 | tr a-z A-Z) = "SOLARIS" ]; then 
            SOLARIS=1
            SUNOS=0
            SOLARIS_VERSION=$(grep PRODVERS $CDROM/.cdtoc | cut -d '=' -f 2)
            echo "Found Solaris $SOLARIS_VERSION"
        fi
    elif [ -f $CDROM/avail_arches ]; then
        SUNOSTMP=$(grep sunos $CDROM/avail_arches | head -1)
        if [[ $SUNOSTMP =~ sunos\.(.*)$ ]]; then
                SUNOS_VERSION="${BASH_REMATCH[1]}"
                SUNOS=1
                SOLARIS=0
                echo "Found SunOS $SUNOS_VERSION"
        fi
    else
        error_exit "Unable to detect SunOS or Solaris on the CD-ROM."
    fi
}

function cdrom_select_arch_sunos() {
    # Read version/architecture info
    if [ -f $CDROM/_copyright ]; then
        echo "--------------------------------------"
        sed -e '/^$/,$d' $CDROM/_copyright
        echo "--------------------------------------"
    fi

    if [ -f $CDROM/avail_arches ]; then
        echo "Available architectures on this media:"
        cat $CDROM/avail_arches
    fi

    # select architecture
    case $TARGETARCH in
        sun4*)
            SELECTEDARCH=$(grep sun4.$TARGETARCH $CDROM/avail_arches)
            SELECTEDVERSION=$(expr $SELECTEDARCH : ".*\.sunos\.\(.*\)$")
            ;;
        *)
            error_exit "Target arch $TARGETARCH is not supported for CD-ROM releases."
            ;;
    esac

    echo "Detected version: $SELECTEDVERSION"
    echo "Selected architecture: $SELECTEDARCH"

    if ! grep -q $TARGETARCH $CDROM/avail_arches; then
        error_exit "This media does not support the $TARGETARCH architecture specified in the target."
    fi
}

function cdrom_select_arch_solaris() {
    if [ -f $CDROM/Copyright ]; then
        echo "--------------------------------------"
        sed -e '/Copyright/,$ d' -e '/^$/d' $CDROM/Copyright
        echo "--------------------------------------"
    fi

    if [ -d $CDROM/archinfo ]; then
         echo "Available architectures on this media:"
        ls -1 $CDROM/archinfo
    fi

    if [ -d $CDROM/export/exec/kvm/*.$TARGETARCH.* ]; then
        SELECTEDARCH=$(basename $CDROM/export/exec/kvm/*.$TARGETARCH.*)
        SELECTEDVERSION=$(expr $SELECTEDARCH : "[a-zA-Z0-9]*\.$TARGETARCH\.\(.*\)")
        echo "Detected version: $SELECTEDVERSION"
        echo "Selected architecture: $SELECTEDARCH"
    else
        error_exit "This media does not support the $TARGETARCH architecture specified in the target."
    fi
}

function cdrom_select_arch() {
    if [ $SOLARIS -eq 1 ]; then
        cdrom_select_arch_solaris
    elif [ $SUNOS -eq 1 ]; then
        cdrom_select_arch_sunos
    fi
}

function cdrom_mount() {
    # mount the cdrom, checking if it's already mounted
    lmount=$(mount | grep $CDROM | cut -d ' ' -f 1)
    if [ ! -z $lmount ]; then
        # check if this is the CDROM we want
        lfile=$(losetup -l -n -O NAME,BACK-FILE | grep $lmount | cut -d ' ' -f 2-)
        if [ $lfile != "/vagrant/sunos/$INSTALLMEDIAPATH" ]; then
            umount $lmount || error_exit "Failed to unmount existing CD-ROM"
            losetup -d $lmount || error_exit "Failed to unconfigure loop device"
            losetup -r -P /dev/loop0 /vagrant/sunos/$INSTALLMEDIAPATH || error_exit "Failed to configure loop device"
            mount -o ro /dev/loop0 $CDROM || error_exit "Failed to mount CD-ROM"
        fi
    else
        losetup -d /dev/loop0 >/dev/null 2>&1
        losetup -r -P /dev/loop0 /vagrant/sunos/$INSTALLMEDIAPATH || error_exit "Failed to configure loop device"
        mount -o ro /dev/loop0 $CDROM || error_exit "Failed to mount CD-ROM"
    fi
}

function cdrom_unmount() {
    umount /dev/loop0
    losetup -d /dev/loop0
}

function cdrom_copy_miniroot() {
    # copy from disc if we don't already have a copy
    if [ ! -d /export/miniroot/$SELECTEDARCH ]; then
        mkdir -p /export/miniroot/$SELECTEDARCH

        # different steps if Solaris vs. SunOS

        if [ $SUNOS -eq 1 ]; then
            losetup -r /dev/loop1 $CDROM/export/exec/kvm/$TARGETARCH_sunos_*/miniroot_$TARGETARCH
            mount -o ro,ufstype=sun /dev/loop1 /mnt
            rsync -a /mnt/ /export/miniroot/$SELECTEDARCH
            umount /mnt
            mv /export/miniroot/$SELECTEDARCH/boot.$TARGETARCH /export/miniroot/$SELECTEDARCH/boot
        elif [ $SOLARIS -eq 1 ]; then
            pushd $CDROM/export/exec/kvm/$SELECTEDARCH
            find . -depth -print | cpio -pdm /export/miniroot/$SELECTEDARCH >/dev/null 2>&1
            popd
            AARCH=$(expr $SELECTEDARCH : "\(.*\)\.$TARGETARCH\.$SELECTEDVERSION")
            pushd $CDROM/export/exec/$AARCH.$SELECTEDVERSION/lib/fs/nfs
            if [ -f inetboot.$SELECTEDARCH ]; then
                cp inetboot.$SELECTEDARCH /export/miniroot/$SELECTEDARCH/inetboot
            elif [ -f inetboot ]; then
                cp inetboot /export/miniroot/$SELECTEDARCH/inetboot
            else
                error_exit "Could not find Solaris bootloader."
            fi
            popd
        else
            error_exit "Unknown operating system."
        fi

    fi
    if [ -d /export/root/$TARGETNAME ]; then
        echo "Root directory /export/root/$TARGETNAME already exists, not overwriting."
        exit 1
    fi
    mkdir -p /export/root/$TARGETNAME
    rsync -a /export/miniroot/$SELECTEDARCH/ /export/root/$TARGETNAME
}

function cdrom_install_diskless() {
    # for SunOS 4.1.4 (possibly any 4.1.x CD-ROM release) this should do:
    # if new version/arch combo, extract proto root to /export/proto/arch_sunos_version
    # create new /export/root dir for target host from proto
    # untar distribution on top
    # move /usr into /export/exec/version_arch
    # configure hostname, network, etc in target root

    if [ $SOLARIS -eq 1 ]; then error_exit "Solaris not yet supported"; fi

    ARCHTMP=sunos_$(echo $SELECTEDVERSION | tr . _)

    if [ -z $SELECTEDARCH ]; then
        echo "No distribution architecture has been selected."
        exit 1
    fi

    if [ ! -d /export/proto/$SELECTEDARCH ]; then 
        mkdir -p /export/proto/$SELECTEDARCH
        pushd /export/proto/$SELECTEDARCH
        tar xf $CDROM/export/exec/proto_root_$ARCHTMP
        # untar kvm, sys
        mkdir -p usr/kvm
        pushd usr/kvm 
        tar xf $CDROM/export/exec/kvm/${TARGETARCH}_${ARCHTMP}/kvm
        tar xf $CDROM/export/exec/kvm/${TARGETARCH}_${ARCHTMP}/sys
        popd 
        pushd usr 
        # untar rest of distribution sets here (in export/exec/sun4_sunos_4_1_4)
        for tarfile in $CDROM/export/exec/*sunos*/* $CDROM/export/share/*/* ; do
            echo "Extracting \"$(basename $tarfile)\" set..."
            tar xf $tarfile
        done
        popd 
        
        cp usr/kvm/stand/{kadb,vmunix} .
        cp usr/kvm/stand/boot.$TARGETARCH ./boot
        cp usr/kvm/boot/* ./sbin
        cp usr/stand/sh ./sbin
        cp usr/bin/hostname ./sbin
        popd 

        if [ -d /export/exec/$SELECTEDARCH ]; then rm -rf /export/exec/$SELECTEDARCH; fi
        mv /export/proto/$SELECTEDARCH/usr /export/exec/$SELECTEDARCH
        mkdir -p /export/proto/$SELECTEDARCH/usr
    fi

    # create new install for $TARGETNAME

    ROOT=/export/root/$TARGETNAME

    if [ -d $ROOT ]; then
        echo "Existing root for \"$TARGETNAME\" exists, moving it to $ROOT.old"
        rm -rf $ROOT.old
        mv $ROOT $ROOT.old
    fi
    
    mkdir -p $ROOT
    rsync -a /export/proto/$SELECTEDARCH/ $ROOT

    pushd $ROOT 

    # customize for our target

    # edit hosts, hostname.xxx, fstab
    printf "$TARGETADDR $TARGETNAME\n$SERVERADDR $SERVERNAME\n" >> etc/hosts
    echo "$TARGETNAME" > etc/hostname.le0
    cat << EOF > etc/fstab
$SERVERNAME:$ROOT / nfs rw 0 0
$SERVERNAME:/export/exec/$SELECTEDARCH /usr nfs ro 0 0
$SERVERNAME:/export/home /home nfs rw 0 0
EOF
    # todo: find out how to make sunos respect subnet netmask

    # patch/run MAKEDEV std pty0 pty1 pty2 win0 win1 win2
    pushd dev 
    sed -e 's#^PATH=.*$#PATH=/vagrant/shims:$PATH#' MAKEDEV > MAKEDEV.sunboot && chmod u+x MAKEDEV.sunboot
    ./MAKEDEV.sunboot std pty0 pty1 pty2 win0 win1 win2 >/dev/null
    popd 
    # move 'yp' dir out of place
    mv var/yp var/yp.disabled
    popd

    echo "$SELECTEDARCH" > $ROOT/.sunboot

}

# setup NFS exports
function configure_nfs() {
    # setup swap space for client
    rm -f /export/swap/$TARGETNAME
    dd if=/dev/zero of=/export/swap/$TARGETNAME bs=1M count=$TARGETSWAPSIZE >/dev/null 2>&1

    cat << EOF >> /etc/exports
/export/root/$TARGETNAME $TARGETADDR(rw,sync,no_root_squash,no_subtree_check)
/export/swap/$TARGETNAME $TARGETADDR(rw,sync,no_root_squash,no_subtree_check)
EOF

    exportfs -ra
}

# Setup rarp, bootparams and rsh
function config_boot() {
    ETHER=$(normal_ether $TARGETETHER)
    BOOTPARAMS="root=$SERVERNAME:/export/root/$TARGETNAME swap=$SERVERNAME:/export/swap/$TARGETNAME"
    BOOTPROGRAM="boot"

    if [ $SOLARIS -eq 1 ]; then
        BOOTPROGRAM="inetboot"
        if [ $INSTALLMETHOD = "DISKFUL" ]; then
            BOOTPARAMS="root=$SERVERNAME:/export/root/$TARGETNAME install=$SERVERNAME:$CDROM"
        fi
    fi

    if [ $SUNOS -eq 1 ]; then
        echo "$TARGETNAME root" > /root/.rhosts
    fi
        
    # todo - remove existing entries before blindly adding them
    echo "$TARGETNAME $BOOTPARAMS" >> /etc/bootparams
    echo "$ETHER $TARGETNAME" >> /etc/ethers
    echo "$TARGETADDR $TARGETNAME" >> /etc/hosts
    arp -s $TARGETADDR $ETHER

    # Link bootloader
    IPHEX=$(iphex $TARGETADDR)
    pushd /srv/tftp 
    cp -f /export/root/$TARGETNAME/$BOOTPROGRAM ./$BOOTPROGRAM.$SELECTEDARCH
    ln -s $BOOTPROGRAM.$SELECTEDARCH $IPHEX
    ln -s $BOOTPROGRAM.$SELECTEDARCH $IPHEX.$(echo $TARGETARCH | tr a-z A-Z)
    popd

    systemctl restart bootparamd
}
