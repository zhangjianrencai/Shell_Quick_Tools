#!/bin/sh

# Revision    : 1.2
# CreateDate  : 2009/08/27 12:00:00 
# Source      : batch_ftp.sh
# Author      : BrantChen2008@gmail.com
# Description :  
# This shell script is to help users to automatically download the files you defined in the embeded ftp script.
# (FTP script started from Line No. 198 around, you can start from there quickly)
# For more details, please refer to the code :)

#******************************************************************************
# Copyright: Copyright 2009 Brant Chen (BrantChen2008@gmail.com, or xkdcc@163.com), All Rights Reserved 
#******************************************************************************
g_overwrite=0

case "`uname -s`" in
  FreeBSD)
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

#******************************************************************************
#  Prompt () - determines the flags to use to print
#      a line without a newline char
#
#  *** This function uses the set_echo_var function -${ECHO} to
#    define the Prompt function.
#
#  calling signature - Prompt "some string"
#  return value - none

case "`${ECHO} 'x\c'`" in
  'x\c')
    Prompt()
    {
      ${ECHO} -n "$*"
    }
    ;;
  x)
    Prompt()
    {
      ${ECHO} "$*\c"
    }
    ;;
  *)
    Prompt()
    {
      ${ECHO} -n "$*"
    }
    ;;
esac

#******************************************************************************
#  confirm () - Takes three parameters:
#         1: "y" or "n" to be displayed as the default
#         2:  a prompt string to be displayed to the user
#         3:  help text string (optional)
#
#      *** This function uses the Prompt function
#        which uses the set_echo_var function - ${ECHO}.
#
#  calling signature:  confirm y "some string" [ "help text" ]
#          or
#        confirm n "some string" [ "help text" ]
#
#  returns:    0 for Yes, 1 for No

confirm ()
{
  help=${3}
  Q=""
  if [ -n "${help}" ]; then
    Q=",?"
  fi
  Prompt "${2} [y,n${Q}] (${1}) "
  valid=0
  until [ ${valid} -ne 0 ]
  do
    #read ans and if it is empty, initialize it with the default
    read ans
    : ${ans:=${1}}

    case "${ans}" in
      Y*|y*)
        valid=1
        return 0 ;;
      N*|n*)
        valid=1
        return -1 ;;
      ?*)
        ${ECHO} ""
        ${ECHO} ${help}
${ECHO} ""
        Prompt "[ASK] ${2} [y,n${Q}] (${1}) "
        ;;
      *)
        ${ECHO} ""
        Prompt "[ASK] ${ans} is invalid input.  Enter [y,n${Q}] (${1}) "
        ;;
    esac
  done
}

usage ()
{
  $ECHO "
Description:
This shell script is to help users to automatically download/upload the files you customized in the embeded ftp script.
(FTP script started from Line No. 198 around, you can start from there quickly)
For more details, please customize the code easily and give a try.
Enjoy :)

<BrantChen2008@gmail.com>

Usage:
./batch_ftp.sh <ftp_user_name> <ftp_user_password> [local_directory]
Example:
  1. batch_ftp.sh brant ftppwd 
     Download/Upload all files per your ftp commands you customized in this script with ftp account brant, password is ftppwd.
  2. batch_ftp.sh brant ftppwd /download_directory 
     Download/Upload all files per your ftp commands you customized in this script with ftp account brant, password is ftppwd. The download folder set as your specified basically.
"
}

get_abspath ()
{
  D=`dirname "$1"`
  B=`basename "$1"`
  abspath="`cd \"$D\" 2>/dev/null && pwd || echo \"$D\"`/$B"
  echo $abspath
}

makedir ()
{
  if [ $# -ne 1 ]; then
    ${ECHO} "[ERR] [makedir] Invalid parameter!"
  fi

  if [ -d $1 ]; then
    ${ECHO} "[WARM] ${1} already existed."

    if [ g_overwrite -eq 1 ]; then
      ${ECHO} "[INFO] Remove ${1} (include all sub-directories/files under it) and get the latest version."
      rm -fr  ${1}
      ${ECHO} "[INFO] Create directory ${1}..."
      mkdir ${1}
    elif confirm y "[INFO] It seems you have some directories/files which downloaded by ftp_get_files.sh existed already.
[ASK] Do you want to remove all directories/files under ${1} and to get the latest ones?"
    then
      g_overwrite=1
      ${ECHO} "[INFO] Remove ${1} and to get the latest version."
      rm -fr  ${1}
      ${ECHO} "[INFO] Create directory ${1}..."
      mkdir ${1}
    else
      g_overwrite=0
      ${ECHO} "[INFO] You have chosen NO and script will not update all files under ${1}."
    fi
  else
    ${ECHO} "[INFO] Create directory ${1}..."
    mkdir ${1}
  fi

  return 0
}

if [ $# -ne 3 ] && [ $# -ne 2 ]; then
  ${ECHO} "[ERR] Please refer to Usage!"
  usage
  return -1
fi 

ftp_user=$1
ftp_user_pwd=$2
if [ $# -eq 3 ]; then
  download_dir=$3
else
  download_dir=$(pwd)
fi

if [ ! -d ${download_dir} ]; then
  ${ECHO} "[INFO] The directory for downloading doesn't exist."
  ${ECHO} "[INFO] Create directory: ${download_dir}"
  mkdir ${download_dir}
fi

download_dir=$(get_abspath ${download_dir})

# Now you can customize your files in to following FTP script wity FTP commands.
ftp -n xxx.xxx.xxx.xxx << !
user $ftp_user $ftp_user_pwd
bin
prompt
lcd ${download_dir} 
cd <your_path> 
get <your target file> 


by
!

chmod -R 755 ${download_dir}/*

${ECHO} ""
${ECHO} "[INF] Done."
${ECHO} ""

