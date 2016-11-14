#!/bin/bash
# Gokhan MANKARA gokhan@mankara.org
# ZFS, short form of Zettabyte Filesystem is an advanced and highly scalable filesystem.
# You can see how to install ZFS on RHEL & CentOS based distributions from the offical zfsonlinux.org
# repository.

function zfs_check_install() {
	check_disk="$(fdisk -l 2>/dev/null |grep "Disk" | grep '/dev/sd[a-z]\|/dev/sd[a-z][1-9]' | grep -v 'identifier' | wc -l)"

	if [ ! $check_disk -gt 1 ]; then
        echo "INFO" "No Disk Found For Zfs Configuration. Exiting"
        exit 1
	fi

	echo "Checking zfs installation and zfs list output"
	sleep 1
	
	check_zfs_rpm="$(test $(rpm -qa |grep zfs | wc -l) -gt 0; echo $?)"
	
	if [[ "$check_zfs_rpm" != "0" ]]; then
	    echo "Zfs Rpm Not Found, Install First"
	    exit 1
	fi
	
	check_zfs_list="$(test $(zfs list 2>/dev/null | grep -i "no data sets availabe" | wc -l) -gt 0; echo $?)"
	
	if [[ "$check_zfs_list" != "1" ]]; then
	    zfs list
	    rpm -qa |grep kernel
	    echo "Kernel versions may not same, please update kernel, kernel-headers and kernel-devel to be same"
	    exit 1
	fi
}

function zfs_create_pools () {
    echo ''
    echo "Disks: "
    fdisk -l 2>/dev/null |grep "Disk" | grep '/dev/sd[a-z]\|/dev/sd[a-z][1-9]' | grep -v 'identifier'
    echo ''
    echo "Partitions: "
    fdisk -l 2>/dev/null | grep '/dev/sd[a-z]\|/dev/sd[a-z][1-9]' | grep -v "Disk"

    read -p "Which disk do you want to use ( /dev/sdb ):  " disk
    if [[ "$disk" == "" ]]; then
        zfs_create_pools
    else
        check_partition_exits="$(test $(fdisk -l 2>/dev/null | grep $disk | grep -v "Disk" | wc -l) -gt 0; echo $?)"

        if [[ "$check_partition_exits" != "0" ]]; then
            #parted -s $disk mklabel gpt unit TB  mkpart primary 0 0 2>/dev/null
            parted -s $disk mklabel gpt unit TB 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "INFO" "parted $disk"
            else
                echo ''
                echo -e "\e[31mDisk May be Wrong!!! Check Again..: $disk \e[0m"
                zfs_create_pools
            fi
        else
            echo ''
            echo -e "\e[31mDisk May be Using For Root Partition!!! Check Again..: $disk \e[0m"
            zfs_create_pools
        fi
    fi

    partition=$(fdisk -l 2>/dev/null | grep $disk | grep -v "Disk" | awk '{print $1}')

    check_mount_partition="$(test $(umount $partition 2>/dev/null | grep "not mounted" | wc -l) -gt 0; echo $?)"

	if [[ "$check_mount_partition" != "1" ]]; then
        umount $partition
        if [ $? -eq 0 ]; then
            echo "INFO" "umount $partition"
        else
            echo "ERROR" "umount $partition"
        fi
	fi

    check_zfs_pools="$(test $(zfs list | wc -l) -gt 0; echo $?)"

	if [[ "$check_zfs_pools" != "0" ]]; then
        zpool create zfs0 $disk
        if [ $? -eq 0 ]; then
            echo "INFO" "zpool create zfs0 $disk"
        else
            echo "ERROR" "zpool create zfs0 $disk"
            zfs_create_pools
        fi

        zfs create zfs0/index
        if [ $? -eq 0 ]; then
            echo "INFO" "zfs create zfs0/index"
        else
            echo "ERROR" "zfs create zfs0/index"
        fi
	fi

    get_index_mountpoint="$(zfs get mountpoint | grep zfs0/index | awk '{ print $3}')"

    if [[ "$get_index_mountpoint" != "legacy" ]]; then

        zfs set mountpoint=legacy zfs0/index
        if [ $? -eq 0 ]; then
            echo "INFO" "zfs set mountpoint=legacy zfs0/index"
        else
            echo "ERROR" "zfs set mountpoint=legacy zfs0/index"
        fi
    fi

	read -p "Please write zfs0/index output path ( Default: /opt/zfs_output/index ):  " zfs_index_path

	if [ "$zfs_index_path" == "" ]; then
        zfs_path_index="/opt/zfs_output/index"

        if [ -d $zfs_path_index ]; then
            echo "Directory Exits. Backuping Folder"
            today_time=`date +"%Y%m%d%H%M%S"`
            mv $zfs_path_index "$zfs_path_index"_$today_time
            if [ $? -eq 0 ]; then
                echo "INFO" "mv $zfs_path_index "$zfs_path_index"_$today_time"
            else
                echo "ERROR" "mv $zfs_path_index "$zfs_path_index"_$today_time"
            fi
        fi

        mkdir -p "$zfs_path_index"
        if [ $? -eq 0 ]; then
            echo "INFO" "mkdir -p "$zfs_path_index""
        else
            echo "ERROR" "mkdir -p "$zfs_path_index""
        fi

        check_fstab="$(test $(cat /etc/fstab | grep "zfs0/index" | wc -l) -gt 0; echo $?)"

        if [[ "$check_fstab" != "0" ]]; then
            echo "zfs0/index $zfs_path_index  zfs  defaults  0  0" >> /etc/fstab
            if [ $? -eq 0 ]; then
                echo "INFO" "echo zfs0/index $zfs_path_index  zfs  defaults  0  0 >> /etc/fstab"
            else
                echo "ERROR" "echo zfs0/index $zfs_path_index  zfs  defaults  0  0 >> /etc/fstab"
            fi
        fi

        mount -a
        if [ $? -eq 0 ]; then
            echo "INFO" "mount -a"
        else
            echo "ERROR" "mount -a"
        fi
    else
        if [ -d $zfs_path ]; then
            echo "Directory Exits. Backuping Folder"
            today_time=`date +"%Y%m%d%H%M%S"`

            mv $zfs_path "$zfs_path"_$today_time
            if [ $? -eq 0 ]; then
                echo "INFO" "mv $zfs_path "$zfs_path"_$today_time"
            else
                echo "ERROR" "mv $zfs_path "$zfs_path"_$today_time"
            fi
        fi

        mkdir -p "$zfs_path"
        if [ $? -eq 0 ]; then
            echo "INFO" "mkdir -p "$zfs_path""
        else
            echo "ERROR" "mkdir -p "$zfs_path""
        fi

        check_fstab="$(test $(cat /etc/fstab | grep "zfs0/index" | wc -l) -gt 0; echo $?)"

        if [[ "$check_fstab" != "0" ]]; then
            echo "zfs0/index $zfs_path/index  zfs  defaults  0  0" >> /etc/fstab
            if [ $? -eq 0 ]; then
                echo "INFO" "echo zfs0/index $zfs_path/index  zfs  defaults  0  0 >> /etc/fstab"
            else
                echo "ERROR" "echo zfs0/index $zfs_path/index  zfs  defaults  0  0 >> /etc/fstab"
            fi
        fi

        mount -a
        if [ $? -eq 0 ]; then
            echo "INFO" "mount -a"
        else
            echo "ERROR" "mount -a"
        fi
    fi
}

function zfs_configure () {
    read -p "Do you want to active compression for zfs0/index? [ Yy / Nn ]: " yn
    case $yn in
        [Yy]* )
            zfs set compression=on zfs0/index
            if [ $? -eq 0 ]; then
                echo "INFO" "zfs set compression=on zfs0/index"
            else
                echo "ERROR" "zfs set compression=on zfs0/index"
            fi
        ;;
        [Nn]* )
            exit 0
        ;;
        * ) echo "Please answer yes or no.";;
    esac

    read -p "Do you want to limit arc size to 8 Gb? [ Yy / Nn ]: " yn
    case $yn in
        [Yy]* )
            zfs_conf="/etc/modprobe.d/zfs.conf"

            if [ ! -f "$zfs_conf" ]; then
                touch /etc/modprobe.d/zfs.conf

                if [ $? -eq 0 ]; then
                    echo "INFO" "touch /etc/modprobe.d/zfs.conf"
                else
                    echo "ERROR" "touch /etc/modprobe.d/zfs.conf"
                fi
            fi

            check_modprobe_zfs="$(test $(cat /etc/modprobe.d/zfs.conf | grep "zfs_arc_max" | wc -l) -gt 0; echo $?)"
            if [[ "$check_modprobe_zfs" != "0" ]]; then
                echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf
                if [ $? -eq 0 ]; then
                    echo "INFO" "echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf"
                else
                    echo "ERROR" "echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf"
                fi
            fi
        ;;
        [Nn]* )
            exit 0
        ;;
        * ) echo "Please answer yes or no."
        ;;
    esac
}


while true; do
    read -p "WARNING. These configuration may damage the system. \
Do you want to continue? [ Yy / Nn ]: " yn
    case $yn in
        [Yy]* )
            zfs_check_install
            zfs_create_pools
            zfs_configure
            break
        ;;
        [Nn]* )
            break
        ;;
        * )
            echo "Please answer yes or no."
        ;;
    esac
done

