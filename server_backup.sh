#!/bin/sh

# Backup folder to network share script
# Created by Andrey Romanov '2013

# Paths to programs
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

MOUNT_CMD=$(which mount.cifs)

# Setting initial variables:
S="$(date +%s)" # start time
UID_ROOT=0 # root uid
server_name=$(/bin/hostname)
#source_path='/etc' # directories for backuping
source_path='/bin /boot /etc /home /lib /lib64 /mnt/redmine_files /opt /root /sbin /selinux /usr /var' # directories for backuping
mount_path='/mnt/backup'
mount_server='/backup/Configuration'
mail_to='admin@contoso.com'
arch_path="$mount_path/$server_name/"
arch_path_net="$mount_server/$server_name/" # real network path to share
error_log='/tmp/bkp_error.log'
files_log='./bkp_files.log'
curr_date=$(date +%Y%m%d)
curr_time=$(date +%H%M%S)
bkp_name="$arch_path$curr_date""_$(hostname)_backup_full_$curr_time.tar.gz"
bkp_name_incr="$arch_path$curr_date""_$(hostname)_backup_diff_$curr_time.tar.gz"
bkp_name_net="$arch_path_net$curr_date""_$(hostname)_backup_full_$curr_time.tar.gz" # real network path to backup
bkp_name_net_incr="$arch_path_net$curr_date""_$(hostname)_backup_diff_$curr_time.tar.gz" # real network path to backup

echo "$source_path backup script started..."


# Run as super user check
if [ "$UID" -ne "$UID_ROOT" ]; then
        echo "This script need to run with super user privileges"
        logger "$0 - Runned without super user privileges"
        exit 100 # need run with su privileges
fi


# Send current datetime to local log file
echo "" >> $error_log
date >> $error_log


# Mounting network share & creating subdirs if needed
echo "Creating directory $mount_path for mounting network share."

if [ -d $mount_path ]; then
        echo "Already present."
else
        if (mkdir -p $mount_path 2>> "$error_log") then
                echo "Done!"
        else
                echo "Can't create directory $mount_path for mounting.  See /var/log/syslog"
                logger "$0 - Can't create directory $mount_path for mounting (mkdir error)"
                exit 101 # can't create directory for mounting
        fi
fi

echo "Mounting $mount_server in $mount_path."
if !(cat /proc/mounts | grep $mount_server | grep $mount_path > /dev/null 2> /dev/null) then
        if ($MOUNT_CMD -o username=netbackup,password=t4ylx97 $mount_server $mount_path 2>> "$error_log") then
                echo "Done!"
        else
                echo "Cannot mount network share $mount_server to $mount_path.  See /var/log/syslog"
                logger "$0 - Can't mount network share $mount_server to $mount_path (mount.smbfs error)"
                exit 102 # can't mount network share

        fi
else
        echo "Already mounted."
fi

echo "Creating $arch_path subdir for backups compressing."
if [ -d $arch_path ]; then
        echo "Already present."
else
        if (mkdir -p $arch_path 2>> "$error_log") then
                echo "Done!"
        else
                echo "Can't create directory $arch_path for backups compressing.  See /var/log/syslog"
                logger "$0 - Can't create directory $arch_path for backups compressing (mkdir error)"
                exit 103 # can't create directory for backups compressing
        fi
fi


# Compressing backup
if [ "$1" = "--incr" ] ; then
        TAR_STR="tar -cvjpS --ignore-failed-read --one-file-system --recursion --totals -f $bkp_name_incr -g /root/meta/backup_meta.snar $source_path"
        echo "Compressing incremental $source_path to $bkp_name_net_incr"
else
        TAR_STR="tar -cvjpS --level=0 --ignore-failed-read --one-file-system --recursion --totals -f $bkp_name -g /root/meta/backup_meta.snar $source_path"
        echo "Compressing full $source_path to $bkp_name_net"
fi

#if ($TAR_STR >> "$error_log") then
if ($TAR_STR | tee $files_log) then
        echo "Done!"
else
        echo "Compression error. See /var/log/syslog"
        logger "$0 - Can't compress $source_path to directory $source_path (tar error)"
        exit 104 # tar compression error
fi

report=$( cat $files_log | wc -l)


# Unmounting network share
echo "Unmounting $mount_server."
if !(umount -f $mount_path > /dev/null 2> "$error_log") then
        echo "Error!"
else
        echo "Done!"
fi

S="$(($(date +%s)-S))" # stop time
TimeString=$(printf "%02d hours %02d minutes %02d seconds\n" \
        "$((S/3600))" "$((S/60%60))" "$((S%60))")

#echo "$report files from $source_path archived to $bkp_name_net in $TimeString"

# Mail sending
echo "Send mail to $mail_to"
if [ "$1" = "--incr" ] ; then
        echo "$report files from $source_path archived to $bkp_name_net_incr in $TimeString" | \
                        mail -a "FROM: $server_name mail daemon <backup@contoso.com>" \
                        -s "$server_name - differential backup report: $source_path" "$mail_to"
else
        echo "$report files from $source_path archived to $bkp_name_net in $TimeString" | \
                        mail -a "FROM: $server_name mail daemon <backup@contoso.com" \
                        -s "$server_name - full backup report: $source_path" "$mail_to"
fi


exit 0 # without errors
