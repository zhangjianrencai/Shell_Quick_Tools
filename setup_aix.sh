#!/bin/sh

# Revision    : 1.1
# CreateDate  : 2011/05/13 
# Source      : setup_aix.sh
# Author      : BrantChen2008@gmail.com
# Description :  
# This shell script is to help me to initiate a AIX environment automatically  
# to a comfortable working environment by:
#   * partitioning disk
#   * openning nfs_use_reserved_ports for NFS mount
#   * set a nice PS1 look
#   * set ulimit -f to unlimite value
#   * mounting a NFS point
#   * writing all necessary settings to related configuration file.
# Notes       :
# Please note this shell should be running under AIX.

#******************************************************************************
# Copyright: Copyright 2011 Brant Chen (BrantChen2008@gmail.com, 
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

${ECHO} "[INF] change / size to 10G..."
chfs -a size=10G /
${ECHO} "[INF] change /opt size to 10G..."
chfs -a size=10G /opt
${ECHO} "[INF] change /tmp size to 2G..."
chfs -a size=2G /tmp
${ECHO} "[INF] change /var size to 2G..."
chfs -a size=2G /var
${ECHO} "[INF] change /usr size to 10G..."
chfs -a size=10G /usr
${ECHO} "[INF] change /home size to 25G..."
chfs -a size=25G /home
${ECHO} "[INF] make directory: /home/${USER}/build ..."
mkdir -p /home/${USER}/build
${ECHO} "[INF] make directory: /home/${USER}/tmp ..."
mkdir -p /home/${USER}/tmp
${ECHO} "[INF] make directory: /cdrom ..."
mkdir -p /cdrom

nfso -o nfs_use_reserved_ports=1
ret=$?
if [ ${ret} -eq 0 ]; then
  ${ECHO} "[INF] Set nfs_use_reserved_ports to 1: OK." 
else
  ${ECHO} "[ERR] Set nfs_use_reserved_ports to 1: Failed."
fi

ret=`grep nfs_use_reserved_ports=1 /etc/profile  | wc -l`
if [ ${ret} -eq 0 ]; then
  ${ECHO} "nfs_use_reserved_ports=1" >> /etc/profile
  ret=`grep nfs_use_reserved_ports=1 /etc/profile  | wc -l`
  if [ ${ret} -eq 1 ]; then
    ${ECHO} "[INF] Add nfs_use_reserved_ports=1 to /etc/profile: OK." 
  else
    ${ECHO} "[ERR] Add nfs_use_reserved_ports=1 to /etc/profile: Failed."
  fi
else
  ${ECHO} "[INF] You have nfs_use_reserved_ports=1 in /etc/profile already." 
fi

# Set ulimit -f unlimited to current term session
ulimit -f unlimited
# Set ulimit -f unlimited to configure file: /etc/security/limits
# Not easy to judge below command result, because it always return 0.
# No matter if it substitutes string.
perl -i -p -e 's/fsize(\s+)=(\s+)(\d+)/fsize = -1/g' /etc/security/limits

# Set PS1 to current shell
# PS1="\[\u@\h \w\]\\\$ " ---- This works for bash, not ksh. 
# Below is common.
# PS1='[$USER@$HOST $PWD]# ' 
# But it seems it's not easy to set PS1 to the shell you are using.
# Because we can only set PS1 to this script's shell, not the shell you are
# running this script. 

# Add PS1 to /etc/profile and ~/.dtprofile
ret=`grep PS1 /etc/profile | wc -l` 
if [ ${ret} -eq 0 ]; then
  ${ECHO} "export PS1='[\$USER@\$HOST \$PWD]# '" >> /etc/profile
  ret=`grep PS1 /etc/profile | wc -l`
  if [ ${ret} -eq 1 ]; then
    ${ECHO} "[INF] Add PS1 to /etc/profile: OK."
  else 
    ${ECHO} "[ERR] Add PS1 to /etc/profile: Failed."
  fi
else
  ${ECHO} "[INF] You have PS1 in /etc/profile already."
fi

ret=`grep PS1 ~/.dtprofile | wc -l`
if [ ${ret} -eq 0 ]; then
  ${ECHO} "export PS1='[\$USER@\$HOST \$PWD]# '" >> ~/.dtprofile
  ret=`grep PS1 ~/.dtprofile | wc -l`
  if [ ${ret} -eq 1 ]; then
    ${ECHO} "[INF] Add PS1 to ~/.dtprofile: OK."
  else
    ${ECHO} "[ERR] Add PS1 to ~/.dtprofile: Failed."
  fi
else
  ${ECHO} "[INF] You have PS1 in ~/.dtprofile already."
fi

# Add PS1 to ~/.bash_profile
if [ ! -f ~/.bash_profile ]; then
  touch ~/.bash_profile  
fi
ret=`grep PS1 ~/.bash_profile | wc -l`
if [ ${ret} -eq 0 ]; then
  ${ECHO} "export PS1='[\$USER@\$HOST \$PWD]# '" >> ~/.bash_profile
  ret=`grep PS1 ~/.bash_profile | wc -l`
  if [ ${ret} -eq 1 ]; then
    ${ECHO} "[INF] Add PS1 to ~/.bash_profile: OK."
  else
    ${ECHO} "[ERR] Add PS1 to ~/.bash_profile: Failed."
  fi
else
  ${ECHO} "[INF] You have PS1 in ~/.bash_profile already."
fi



ret=`mount | grep 192.168.1.6 | wc -l`
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


