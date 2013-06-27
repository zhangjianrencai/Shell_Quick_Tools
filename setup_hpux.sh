#!/bin/sh

# Revision    : 1.1
# CreateDate  : 2011/05/13 
# Source      : setup_hpux.sh
# Author      : BrantChen2008@gmail.com
# Description :  
# This shell script is to help me to initiate a HPUX environment automatically  
# to a comfortable working environment by:
#   * making regular directory structure
#   * set a nice PS1 look
#   * mounting a NFS point
#   * ftp to hard code ftp server and download needed HPUX installation packages
#     and install all of them
#   * writing all necessary settings to related configuration file.
# Notes       :
# Please note this shell script should be running under HPUX.

#******************************************************************************
# Copyright: Copyright 2012 Brant Chen (BrantChen2008@gmail.com, 
# or xkdcc@163.com), All Rights Reserved 
#******************************************************************************
                        
case "`uname -s`" in
  Darwin | FreeBSD)
    ECHO="echo -e"
    ;;
  Linux*)
    unset POSIXLY_CORRECT
    ECHO="/bin/echo -e"
    ;;
  SunOS*)
    ECHO="/usr/bin/echo"
    ;;
  *)
    ECHO="echo"
    ;;
esac

USER="brant"

if [ $# -ne 2 ] && [ $# -ne 2 ]; then
  ${ECHO} "[ERR] Please provide ftp username and password! For example: ./setup_hpux.sh your_ftp_account your_password"
  exit 1
fi 

ftp_user=$1
ftp_user_pwd=$2

${ECHO} "[INF] make directory: /home/${USER}/build ..."
mkdir -p /home/${USER}/build
${ECHO} "[INF] make directory: /home/${USER}/tmp ..."
mkdir -p /home/${USER}/tmp
${ECHO} "[INF] make directory: /cdrom ..."
mkdir -p /cdrom

# Skip set ulimit -f to unlimited, since it's default settings.

# Set PS1 to current shell
# PS1="\[\u@\h \w\]\\\$ " ---- This works for bash, not ksh. 
# Below is common.
# PS1='[$USER@$HOST $PWD]# ' 
# But it seems it's not easy to set PS1 to the shell you are using.
# Because we can only set PS1 to this script's shell, not the shell you are
# running this script. 

# When you login it read from /etc/profile
# Add PS1 to /etc/profile 
ret=`grep PS1 /etc/profile | wc -l` 
if [ ${ret} -eq 0 ]; then
  ${ECHO} "export USER=`whoami`" >> /etc/profile
  ${ECHO} "export HOSTNAME=`hostname`" >> /etc/profile
  ${ECHO} "export PS1='[\$USER@\$HOSTNAME \$PWD]# '" >> /etc/profile
  ret=`grep PS1 /etc/profile | wc -l`
  if [ ${ret} -eq 1 ]; then
    ${ECHO} "[INF] Add PS1 to /etc/profile: OK."
  else 
    ${ECHO} "[ERR] Add PS1 to /etc/profile: Failed."
  fi
else
  ${ECHO} "[INF] You have PS1 in /etc/profile already."
fi

# It's not necessary to add for /.dtprofile

# This is just for bash 
# Add PS1 to ~/.bash_profile
if [ ! -f ~/.bash_profile ]; then
  touch ~/.bash_profile  
fi
ret=`grep PS1 ~/.bash_profile | wc -l`
if [ ${ret} -eq 0 ]; then
  ${ECHO} "export PS1='[\\u@\\h \$PWD]# '" >> ~/.bash_profile
  ret=`grep PS1 ~/.bash_profile | wc -l`
  if [ ${ret} -eq 1 ]; then
    ${ECHO} "[INF] Add PS1 to ~/.bash_profile: OK."
  else
    ${ECHO} "[ERR] Add PS1 to ~/.bash_profile: Failed."
  fi
else
  ${ECHO} "[INF] You have PS1 in ~/.bash_profile already."
fi
              
ret=`mount | grep 1192.168.1.6 | wc -l`
if [ ${ret} -eq 0 ]; then
  mount 192.168.1.6:/02-Build /mnt
  ret=`mount | grep 192.168.1.6 | wc -l`
  if [ ${ret} -eq 1 ]; then
    ${ECHO} "[INF] Mount 192.168.1.6:/02-Build to /mnt: OK."
  else
    ${ECHO} "[ERR] Mount 192.168.1.6:/02-Build to /mnt: Failed."
  fi
else
  ${ECHO} "[INF] You have mount 192.168.1.6:/02-Build already."
fi

# Create an account named test for testing purpose.
useradd -g users -d /home/test -s /sbin/sh -m test 
${ECHO} "[INF] Please use passwd to change password of the account named test."
            
# Get bash related depot from 192.168.1.6 and install all of them
ftp -n 192.168.1.6 << !
user $ftp_user $ftp_user_pwd
bin
prompt
cd /Products/Tools/Tools_For_HPUX/hpux-11.31-bash/
get bash-4.1.007-ia64-11.31.depot.gz
get gettext-0.18-ia64-11.31.depot.gz
get libiconv-1.13.1-ia64-11.31.depot.gz
get popt-1.13-ia64-11.31.depot.gz
get termcap-1.3.1-ia64-11.31.depot.gz
by
!

ls *.gz |xargs gunzip 
swinstall -s ./bash-4.1.007-ia64-11.31.depot \*
swinstall -s ./gettext-0.18-ia64-11.31.depot \*
swinstall -s ./libiconv-1.13.1-ia64-11.31.depot \*
swinstall -s ./popt-1.13-ia64-11.31.depot \*
swinstall -s ./termcap-1.3.1-ia64-11.31.depot \*




