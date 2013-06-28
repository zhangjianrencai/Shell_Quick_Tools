#!/usr/bin/ksh

# Revision    : 1.2

# InitialDate : 2009/08/27 12:00:00
# Source      : easyftp.sh
# Author      : BrantChen2008@gmail.com
# Description :  
# 1. This is a great shell script I wrote :)
# 2. It is mainly to help users to automatically download files 
#    which listed in 
#    ftp://${FTPADDR}/${FTP_USERS_PATH}/<login name>/DownloadList_${FTPADDR}_${FTP_USERNAME} file.\
#    And it has much more amazing skills :)
# 3. This script has been tested on AIX/HPUX/Solaris/RedHat.
# 4. It's really cool!
# For more details, please refer to the usage and following "Background" and 
# give a try. :)

# Background  :
# We need download many common stuff(like tools, scripts, license file) at 
# working. But UNIX/Linux are not so easily to get those stuff from FTP in a 
# batch. We are exhausted to type ftp commands to do same work time after time.
# So I have this idea:
# 1. We defined a conf file on FTP;
# 2. We put the stuff's FTP path to the conf file.
# 3. Then we provide FTP credentials to this shell script, then it will download 
#    all files we defined to local.
#    Cautions: It will save your credentials to local as plain text.
# 4. You can upload local files to ftp in a batch. This supports wild chars.
# 5. It even provide edit functions for the conf file on ftp in one option.
#    It means you can add/remove file items from the conf file which on ftp in
#    with one option of this script.  
# 6. Bacically, you need customize some vars in this script for your use.
#    Typically, I marked 4 places in this script that you need to tailor to fit 
#    your requirements. You can search "# Change" to find the places. 


# LastModify  : 2011/03/14 16:11:00
# Comments    : Add chmod command in download_files_from_conf func. 

# TODO:
# 1. Doesn't support ftp upload function with wild char.
# 2. It's better to add support for FTP commands, mget, mput, mkdir, rmdir.
# 3. It's better to check whether the files you want to download have existed 
#    already.


#******************************************************************************
# Copyright: Copyright 2011 Brant Chen (BrantChen2008@gmail.com, 
# or xkdcc@163.com), All Rights Reserved 
#******************************************************************************
      
 
                    
HOSTNAME=`hostname`
# Change [1]
FTPADDR="10.200.108.29"
FTP_GROUP_PATH="/Product"
FTP_GROUP_BUILD_PATH="/Product/02-Build"
# Change [2]
FTP_USERS_PATH="/Brant/FTPSrv/02-Privacy/download/"
# Change [3]
# Make sure there is a DownloadList_file on ftp:
# "DownloadList_${FTPADDR}_${FTP_USERNAME}"      
# Change [4]
# DownloadList_file item should like:
# ${FTP_USERS_PATH}/${FTP_USERNAME}/

OVERWRITE=0
FLAG_U=0
FTP_USERNAME=""
FLAG_P=0
FTP_PASSWORD=""
FLAG_S=0
FLAG_M=0
FLAG_T=0
FLAG_A=0
DOWNLOAD_SEL=""
FLAG_R=0
FLAG_L=0   
FTP_PATH_TO_BE_LIST="/"        # It will be set from CLI option FLAG_L.
FLAG_D=0
DOWNLOAD_TO="./"       # It will be set from CLI option FLAG_D.
FLAG_O=0        
FILES_TO_BE_UPLOAD=""  # It will be set from CLI option FLAG_D.
UPLOAD_TO=""           # It need be set in init_prog.

DOWNLOADLIST_CONF_LOCAL_DIR="/tmp"
# Below vars will be reset in init_prog()
DOWNLOADLIST_CONF_NAME="DownloadList_${FTPADDR}_${FTP_USERNAME}"      
DOWNLOADLIST_CONF_LOCAL_PATH=""               
DOWNLOADLIST_CONF_LOCAL_PATH_WITH_HOSTNAME=""    
DOWNLOADLIST_CONF_FTP_PATH=""     
DOWNLOADLIST_CONF_FTP_PATH_WITH_IP=""

# Should not name CRED_FILE_NAME with ${FTP_USERNAME}
# Because those cred are saved with plain text, if the CRED_FILE_NAME named 
# with ${FTP_USERNAME}, other uses would use other existed cred easily. 
CRED_FILE_NAME="cred_${FTPADDR}"                
CRED_FILE_NAME_WITH_PATH="/tmp/${CRED_FILE_NAME}"    

VERIFY_FTP_CRED="/tmp/verify_ftp_credentials"

 
TMP_DIR="/tmp"
TMPFILE="/tmp/easyftp.tmp"
TMPFILE_FOR_DOWNLOAD_CMD="/tmp/easyftp_cmd_for_download.sh" 
TMPFILE_FOR_UPLOAD_CMD="/tmp/easyftp_cmd_for_upload.sh"

FTP_CMD_GET="get"
FTP_CMD_PUT="put"   
FTP_CMD_BIN="bin"   
FTP_CMD_PROMPT="prompt" 
FTP_CMD_ASCII="ascii"
FTP_CMD_GET_BOOL=0
FTP_CMD_PUT_BOOL=0
FTP_CMD_BIN_BOOL=1
FTP_CMD_PROMPT_BOOL=1
FTP_CMD_ASCII_BOOL=0
            
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

#******************************************************************************
#  prompt () - determines the flags to use to print
#      a line without a newline char
#
#  *** This function uses the set_echo_var function -${ECHO} to
#    define the prompt function.
#
#  calling signature - prompt "some string"
#  return value - none

case "`${ECHO} 'x\c'`" in
  'x\c')
    prompt()
    {
      ${ECHO} -n "$*"
    }
    ;;
  x)
    prompt()
    {
      ${ECHO} "$*\c"
    }
    ;;
  *)
    prompt()
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
#      *** This function uses the prompt function
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
  prompt "${2} [y,n${Q}] (${1}) "
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
        prompt "[ASK] ${2} [y,n${Q}] (${1}) "
        ;;
      *)
        ${ECHO} ""
        prompt "[ASK] ${ans} is invalid input.  Enter [y,n${Q}] (${1}) "
        ;;
    esac
  done
}

usage ()
{
  $ECHO "     
Version: 1.2
Author:  BrantChen2008@gmail.com
Description:
This shell script is mainly to help users to automatically download files 
which listed in ftp://${FTPADDR}/${FTP_USERS_PATH}/FTP_USERNAME/DOWNLOADLIST_CONF_NAME.

Notes:
1. This script doesn't support download/upload directories recursion.
2. If you just run \"dir <file name>\" but not \"dir <directory name>\",
   then command \"dir ..\" can't work; just please use a absolute path on ftp. 
3. If you want to list a directory named \"bin\", \"ascii\", \"prompt\", please 
   run \"./bin\", \"./ascii\", \"./prompt\" instead.
4. Upload support wild char *. But not support mult input files vars.
   1) When you mean to use "*", please use */* to escape * from CLI.
   2) When you mean to use part_files_name*, please use part_files_name/* 
      to escape * from CLI. 

Usage:
./easyftp.sh -u <FTP_login_name> -p <FTP_password> [Options]

Example:     
  1. easyftp.sh -u chao_chen -p ftppwd -s
     Save your username and password to /tmp/cred_${FTPADDR}. Then you don't
     need to provide the username and password every time. 
  2. easyftp.sh -u brant -p ftppwd -d <local_directory>
     Download all files which listed in 
     ftp://${FTPADDR}/${FTP_USERS_PATH}/${FTP_USERNAME}/DownloadList_${FTPADDR}_FTP_USERNAME 
     file to ./ directory.
  3. easyftp.sh -u brant -p ftppwd -l  <FTP_PATH>
     List all files under FTP_PATH.             
  4. easyftp.sh -u brant -p ftppwd -o local_files  
     easyftp.sh -u brant -p ftppwd -o wild/*
     Upload local_files or wild* to 
     ftp://${FTPADDR}/${FTP_USERS_PATH}/FTP_USERNAME/
  5. easyftp.sh -u brant -p ftppwd -m -t
     Type 
     ftp://${FTPADDR}/${FTP_USERS_PATH}/${FTP_USERNAME}/DownloadList_${FTPADDR}_FTP_USERNAME 
      to screen.   
  6. easyftp.sh -u brant -p ftppwd -m -a /Product/
     Add /Product/ string to 
     ftp://${FTPADDR}/${FTP_USERS_PATH}/${FTP_USERNAME}/DownloadList_${FTPADDR}_FTP_USERNAME
  7. easyftp.sh -u brant -p ftppwd -m -r /Product/
     Remove /Product/ string from 
     ftp://${FTPADDR}/${FTP_USERS_PATH}/${FTP_USERNAME}/DownloadList_${FTPADDR}_FTP_USERNAME
"
}

#******************************************************************************
# Parse user's input
#

parse_parameters ()
{  
  #easyftp.sh -h
  #easyftp.sh -u brant -p ftppwd -s 
  #easyftp.sh [-u brant -p ftppwd] -m <-t>
  #easyftp.sh [-u brant -p ftppwd] -m <-a | -r> <ftp_path>
  #easyftp.sh [-u brant -p ftppwd] -l <ftp_path] 
  #easyftp.sh [-u brant -p ftppwd] -d <local_path>
  #easyftp.sh [-u brant -p ftppwd] -o <local_files> 
  # u 1 p 2 s 4 m 8 t 16 a 32 r 64 d 128 o 256 l 512
  while getopts :u:p:smta:r:l:d:o:h name
  do
    case $name in
      u) FLAG_U=1
         FTP_USERNAME="$OPTARG";;
      p) FLAG_P=2
         FTP_PASSWORD="$OPTARG";;
      s) FLAG_S=4;;
      m) FLAG_M=8;;
      t) FLAG_T=16;;
      a) FLAG_A=32
         DOWNLOAD_SEL="$OPTARG";; 
      r) FLAG_R=64
         DOWNLOAD_SEL="$OPTARG";;    
      d) FLAG_D=128
         DOWNLOAD_TO="$OPTARG";;
      o) FLAG_O=256     
         FILES_TO_BE_UPLOAD="$OPTARG"
         ${ECHO} "FILES_TO_BE_UPLOAD:" ${FILES_TO_BE_UPLOAD};;
      l) FLAG_L=512
         FTP_PATH_TO_BE_LIST="$OPTARG";;
      h) usage
         exit 0;;
      :) ${ECHO} ""
         ${ECHO} "[WARN] Please specify a parameter with this command: $OPTARG
Or view the usage by running: ./easyftp.sh -h
    "
         exit 0;;
      ?) ${ECHO} ""
         ${ECHO} "[ERR] Invalid options: $OPTARG"
         usage
         exit 2;;
    esac
  done  
  
  # If user didn't input FTP_USERNAME and FTP_PASSWORD from CLI,
  # then we should call init_prog again in read_credentials. 
  init_prog
}

#******************************************************************************
# verify_ftp_credentials:
# 1. Verify FTP credentials.   
# Parameters:
# $1. N/A
# returns: 0 for Yes, 1 for No
#
check_ftp_credentials ()
{      
  `ftp -n ${FTPADDR} > ${VERIFY_FTP_CRED} 2>&1 << !
  user ${FTP_USERNAME} ${FTP_PASSWORD} 
  by
  !
  `
  result=`grep incorrect ${VERIFY_FTP_CRED} | wc -l`
  if [ ${result} -eq 0 ]; then
    return 0
  else    
    ${ECHO} "[ERR] Your FTP username or password is error."
    ${ECHO} ""
    exit 1
  fi
}

#******************************************************************************
# read_credentials:
# 1. Read credentials from ${CRED_FILE_NAME_WITH_PATH}
# Parameters:
# $1. N/A 
# returns: 0 for Yes, 1 for No
#
read_credentials ()
{
  if [ ! -f ${CRED_FILE_NAME_WITH_PATH} ]; then
    ${ECHO} "[ERR] FTP credentials file doesn't exist. "
    ${ECHO} "[INF] Please save FTP credentials firstly with -s."
    ${ECHO} ""
    exit 1
  fi  
  FTP_USERNAME=`awk '{ print $1 }' ${CRED_FILE_NAME_WITH_PATH}`
  FTP_PASSWORD=`awk '{ print $2 }' ${CRED_FILE_NAME_WITH_PATH}` 
    
  # After read_credentials, you should call init_prog
  init_prog 
    
  return 0
}

#******************************************************************************
# encap_ftp_credentials_process:
# 1. Encapsulating FTP credentials processes.   
# Parameters:
# $1. N/A 
# returns: 0 for Yes, 1 for No
#
encap_ftp_credentials_process ()
{
  if [ $1 -eq 24 ]  || [ $1 -eq 40  ] || [ $1 -eq 72 ] || [ $1 -eq 128 ] || 
     [ $1 -eq 256 ] || [ $1 -eq 512 ]; then
    read_credentials
    check_ftp_credentials
  elif [ $1 -eq 27 ]  || [ $1 -eq 44  ] || [ $1 -eq 75 ] || [ $1 -eq 131 ] ||
       [ $1 -eq 259 ] || [ $1 -eq 515 ] || [ $1 -eq 7  ]; then
    check_ftp_credentials
  else 
    ${ECHO} "[ERR] Invalid parameters for encap_ftp_credentials_process()."     
    ${ECHO} ""  
    exit 1
  fi             
  
  return 0
}
 
#******************************************************************************
# save_credentials:
# 1. Save FTP username and password to ${CRED_FILE_NAME_WITH_PATH}
# Parameters:
# $1. ${user_option_result}
# returns: 0 for Yes, exit for No   
#
save_credentials ()
{   
  ${ECHO} ""        
  encap_ftp_credentials_process $1
  ret=$?
  if [ ${ret} -eq 0 ]; then    
    ${ECHO} "${FTP_USERNAME} ${FTP_PASSWORD}" >  ${CRED_FILE_NAME_WITH_PATH}
    ${ECHO} "[INF] Save FTP credentials to ${CRED_FILE_NAME_WITH_PATH} successfully."
    ${ECHO} ""              
    return 0
  else
    ${ECHO} "[ERR] Can't save ftp credentials to ${CRED_FILE_NAME_WITH_PATH}."
    exit 1
  fi        
}

#******************************************************************************
# get_download_list_file_from_ftp:
# 1. Get ${DOWNLOADLIST_CONF_NAME} from {FTPADDR}
# Parameters:
# $1. 0, doesn't check if ${DOWNLOADLIST_CONF_NAME} existed at /tmp.
#     1, to check it.
# Notes:
# 1. It do not need to call encap_ftp_credentials_process(). 
# returns: 0 for Yes, 1 for No
#
get_download_list_file_from_ftp ()
{      
  if [ $# -ne 1 ]; then
    ${ECHO} "[ERR][get_download_list_file_from_ftp] Invalid parameter!"       
    ${ECHO} ""  
    exit 1
  fi
  format_val=0 
  
  if [ $1 -eq 1 ]; then     
    if [ -f ${DOWNLOADLIST_CONF_LOCAL_PATH} ]; then
      if confirm y "[WARN] ${DOWNLOADLIST_CONF_LOCAL_PATH_WITH_HOSTNAME} existed.
[ASK] Do you want to get a new one from ${DOWNLOADLIST_CONF_FTP_PATH_WITH_IP} to overwrite it?"
      then   
        #${ECHO} "" 
        #format_val=1
        rm -f ${DOWNLOADLIST_CONF_LOCAL_PATH}
      else          
        ${ECHO} "[INFO] You have chosen No and easyftp.sh exits."    
        ${ECHO} ""  
        exit 0
      fi  
    fi
  fi
  
  `ftp -n ${FTPADDR} > /dev/null 2>&1 << !
  user $FTP_USERNAME $FTP_PASSWORD
  bin
  lcd ${TMP_DIR}            
  cd ${FTP_USERS_PATH}/$FTP_USERNAME/
  get ${DOWNLOADLIST_CONF_NAME}
  by
  !
  `
  if [ -f ${DOWNLOADLIST_CONF_LOCAL_PATH} ]; then
    ${ECHO} "[INF] Download ${DOWNLOADLIST_CONF_FTP_PATH_WITH_IP} to ${DOWNLOADLIST_CONF_LOCAL_PATH_WITH_HOSTNAME} successfully. "
  else
    ${ECHO} "[ERR] Download ${DOWNLOADLIST_CONF_FTP_PATH_WITH_IP} to ${DOWNLOADLIST_CONF_LOCAL_PATH_WITH_HOSTNAME} failed."      
    ${ECHO} ""
    exit 1
  fi
    
  return 0
}

#******************************************************************************
# put_download_list_file_to_ftp:
# 1. Put ${DOWNLOADLIST_CONF_LOCAL_PATH_WITH_HOSTNAME} to 
#    ${DOWNLOADLIST_CONF_FTP_PATH_WITH_IP}
# Parameters:
# $1. N/A     
# Notes:
# 1. It do not need to call encap_ftp_credentials_process(). 
# returns: 0 for Yes, 1 for No.
#
put_download_list_file_to_ftp ()
{     
  if [ ! -f ${DOWNLOADLIST_CONF_LOCAL_PATH} ]; then
    ${ECHO} "[ERR] ${DOWNLOADLIST_CONF_LOCAL_PATH_WITH_HOSTNAME} doesn't exsit."      
    ${ECHO} ""  
    exit 1
  fi   
  `ftp -n ${FTPADDR} > /test 2>&1 << !
  user $FTP_USERNAME $FTP_PASSWORD
  bin
  lcd ${TMP_DIR}            
  cd ${FTP_USERS_PATH}/$FTP_USERNAME/
  put ${DOWNLOADLIST_CONF_NAME} 
  close
  by
  !
  `
  ${ECHO} "[INF] Update ${DOWNLOADLIST_CONF_FTP_PATH_WITH_IP} to ${DOWNLOADLIST_CONF_LOCAL_PATH_WITH_HOSTNAME} successfully."
  return 0 
}

#******************************************************************************
# show_download_txt:
# 1. Display download conf.
# Parameters:
# $1. ${user_option_result}
# returns: 0 for Yes, 1 for No.
#
show_download_conf ()
{          
  ${ECHO} ""
  encap_ftp_credentials_process  $1
  get_download_list_file_from_ftp 1 
  ${ECHO} "[INF] Display:"
  more ${DOWNLOADLIST_CONF_LOCAL_PATH}    
  ${ECHO} ""
  
  return 0  
}

#******************************************************************************
# sort_file:
# 1. Delete duplicated lines in $1 and sort them.
# Parameters:
# $1. filename.
# returns: N/A
#
sort_file ()
{ 
  sort -u $1  > $1.new
  cat $1.new > $1
  rm -f $1.new
   
}

#******************************************************************************
# add_line_to_file:
# 1. Add one line to $1.
# Parameters:
# $1. Filename.
# returns: 0 for Yes, 1 for No
#
add_line_to_file ()
{      
  if [ $# -ne 1 ]; then
    ${ECHO} "[ERR] Invalid parameters for add_line_to_file!"        
    ${ECHO} ""  
    exit 1
  fi          
  lineno_before=`cat $1 | wc -l`
  ${ECHO} ${DOWNLOAD_SEL} >> $1  
               
  lineno_after=`cat $1 | wc -l`
  if [ ${lineno_before} -eq ${lineno_after} ]; then
    ${ECHO} "[ERR] You input a duplicated line. Please check it."    
    ${ECHO} ""  
    exit 1
  fi
  
  return 0
}

#******************************************************************************
# remove_line_from_file:
# 1. Remove one line from $1.
# Parameters:
# $1. Filename.
# returns: 0 for Yes, 1 for No
#
remove_line_from_file ()
{ 
  if [ $# -ne 1 ]; then
    ${ECHO} "[ERR] Invalid parameters for remove_line_from_file!"      
    ${ECHO} ""  
    exit 1
  fi
  
  # First, check whether there is a line matching user's input
  # Escape * character.
  download_sel_tmp=`${ECHO} ${DOWNLOAD_SEL} | sed 's/\*/\\\*/g'`
  find_val=`grep "${download_sel_tmp}" $1 | wc -l`
  if [ ${find_val} -eq 0 ]; then
    ${ECHO} "[WARN] There is no line in $1 matching you input \"${DOWNLOAD_SEL}\". Please check it again."         
    ${ECHO} ""  
    exit 1
  fi
  
  download_sel_new=`${ECHO} ${download_sel_tmp} | sed 's/\//\\\\\//g' `
  cat $1 > ${TMPFILE} 
  sed   "/${download_sel_new}/d" ${TMPFILE} > $1 >&1
  
  rm -f ${TMPFILE}
  
  return 0
}

#******************************************************************************
# add_new_download_list_to_conf:
# 1. Add one new download selection to download conf.  
# Parameters:
# $1. user_opt_result.
# returns: 0 for Yes, 1 for No
#
add_new_download_list_to_conf ()
{             
  ${ECHO} ""
  encap_ftp_credentials_process  $1    
  get_download_list_file_from_ftp 0      
  add_line_to_file ${DOWNLOADLIST_CONF_LOCAL_PATH}  
  put_download_list_file_to_ftp    
  
  ${ECHO} ""
  
  return 0  
}
 
#******************************************************************************
# remove_download_list_from_conf:
# 1. Remove one new download selection to download conf.      
# Parameters:
# $1. user_opt_result.
# returns: 0 for Yes, 1 for No
#
remove_download_list_from_conf ()
{             
  ${ECHO} ""
  encap_ftp_credentials_process  $1
  get_download_list_file_from_ftp 0  
  remove_line_from_file ${DOWNLOADLIST_CONF_LOCAL_PATH}
  sort_file ${DOWNLOADLIST_CONF_LOCAL_PATH}
  put_download_list_file_to_ftp
  
  ${ECHO} ""  
  
  return 0  
}

#******************************************************************************
# download_files_from_conf:
# 1. Download files which listed in download conf.      
# Parameters:
# $1. user_opt_result.
# returns: 0 for Yes, 1 for No
#
download_files_from_conf ()
{                 
  ${ECHO} ""
  encap_ftp_credentials_process $1
  
  get_download_list_file_from_ftp 0  
  
  ${ECHO} "[INF] Here comes the downloadlist:"
  more ${DOWNLOADLIST_CONF_LOCAL_PATH}    
  ${ECHO} ""
  
  ${ECHO} "ftp -n ${FTPADDR} << EOF" > ${TMPFILE_FOR_DOWNLOAD_CMD}  
  ${ECHO} "user ${FTP_USERNAME} ${FTP_PASSWORD}" >> ${TMPFILE_FOR_DOWNLOAD_CMD} 
  ${ECHO} "bin" >> ${TMPFILE_FOR_DOWNLOAD_CMD}            
  ${ECHO} "prompt" >> ${TMPFILE_FOR_DOWNLOAD_CMD}         
  ${ECHO} "lcd" ${DOWNLOAD_TO} >> ${TMPFILE_FOR_DOWNLOAD_CMD}
  
  # In order to check whether every files downloaded well, 
  # we use a simple loop to download every line in  DownloadList.txt
  
  while read LINE
  do        
    ${ECHO} "cd  `dirname ${LINE}`" >> ${TMPFILE_FOR_DOWNLOAD_CMD}    
    ${ECHO} "mget `basename ${LINE}`" >> ${TMPFILE_FOR_DOWNLOAD_CMD}       
  done < ${DOWNLOADLIST_CONF_LOCAL_PATH} 
  
  ${ECHO} "close" >> ${TMPFILE_FOR_DOWNLOAD_CMD}
  ${ECHO} "bye" >> ${TMPFILE_FOR_DOWNLOAD_CMD}   
  ${ECHO} "EOF" >> ${TMPFILE_FOR_DOWNLOAD_CMD}
  
  chmod 755 ${TMPFILE_FOR_DOWNLOAD_CMD}
  # Run ftp commands
  ${TMPFILE_FOR_DOWNLOAD_CMD} 2>&1 > /dev/null   
  
  #case "`uname -s`" in
  #  Linux*)
  #    sed -i '/^[Please,KERBEROS]/d' ${TMPFILE_FOR_DOWNLOAD_LOG}        
  #    ;;
  #  *)
  #    ;;
  #esac    
  
  # TODO: Should check whether everything in DOWNLOADLIST_CONF_LOCAL_PATH were 
  # downloaded successfully.
  
  # Change permission to 755 simply  
  chmod 755 ${DOWNLOAD_TO}/*
  
  ${ECHO} "[INF] You can check FTP commands at" ${TMPFILE_FOR_DOWNLOAD_CMD}"."        
  ${ECHO} ""  
  
  return 0  
}

#******************************************************************************
# upload_files_from_local:
# 1. Upload files to ftp://${FTPADDR}/${UPLOAD_TO} by default. 
# Parameters:
# $1. user_opt_result.
# returns: 0 for Yes, 1 for No
#
upload_files_from_local ()
{               
  ${ECHO} ""
  encap_ftp_credentials_process  $1      
  
  # 1.
  # Escape * in FILES_TO_BE_UPLOAD, because user use "part_file_name/*" format.
  # We need change "part_file_name/*" to "part_file_name*"
  # If not use "part_file_name/*" but use "part_file_name*" directly in CLI,
  # parse_parameters func will change it to a nearest matched filename from 
  # current directory.
  # 2. 
  # If you want upload all files, please use */* from CLI.
  # This scenario can't use /* to escape *.
  FILES_TO_BE_UPLOAD=`${ECHO} ${FILES_TO_BE_UPLOAD} | sed 's/\///g'`
  
  ${ECHO} "ftp -n ${FTPADDR} << EOF" > ${TMPFILE_FOR_UPLOAD_CMD}  
  ${ECHO} "user ${FTP_USERNAME} ${FTP_PASSWORD}" >> ${TMPFILE_FOR_UPLOAD_CMD} 
  ${ECHO} "bin" >> ${TMPFILE_FOR_UPLOAD_CMD}            
  ${ECHO} "prompt" >> ${TMPFILE_FOR_UPLOAD_CMD}        
  ${ECHO} "cd" ${UPLOAD_TO} >> ${TMPFILE_FOR_UPLOAD_CMD}         
  ${ECHO} "mput" ${FILES_TO_BE_UPLOAD} >> ${TMPFILE_FOR_UPLOAD_CMD}         
  ${ECHO} "prompt" >> ${TMPFILE_FOR_UPLOAD_CMD}        
  ${ECHO} "close" >> ${TMPFILE_FOR_UPLOAD_CMD}
  ${ECHO} "bye" >> ${TMPFILE_FOR_UPLOAD_CMD}   
  ${ECHO} "EOF" >> ${TMPFILE_FOR_UPLOAD_CMD}     
  
  chmod 755 ${TMPFILE_FOR_UPLOAD_CMD}
  # Run ftp commands
  ${TMPFILE_FOR_UPLOAD_CMD} 2>&1 > /dev/null
  
  ${ECHO} "[INF] Completed."    
  ${ECHO} "[INF] You can check FTP commands at" ${TMPFILE_FOR_UPLOAD_CMD}"."     
  ${ECHO} ""  
  return 0  
}

#******************************************************************************
# check_key_word:
# 1. Check ${user_input_path} to judge whether the first word matches 
#    ${FTP_CMD_GET}, ${FTP_CMD_PUT}, ${FTP_CMD_BIN} and ${FTP_CMD_PROMPT}.   
# Parameters:
# $1. ${user_input_path}.
# returns: 0 for Yes, 1 for No
#
check_key_word ()
{       
  if [ $# -ne 1 ]; then
    ${ECHO} "[ERR] Invalid parameters for check_key_word!"       
    ${ECHO} ""  
    exit 1
  fi
  
  if [ "$1" = "${FTP_CMD_GET}" ]; then
    FTP_CMD_GET_BOOL=1
  elif [ "$1" = "${FTP_CMD_PUT}" ]; then
    FTP_CMD_PUT_BOOL=1
  elif [ "$1" = "${FTP_CMD_BIN}" ]; then
    FTP_CMD_BIN_BOOL=1  
    FTP_CMD_ASCII_BOOL=0        
  elif [ "$1" = "${FTP_CMD_ASCII}" ]; then
    FTP_CMD_ASCII_BOOL=1        
    FTP_CMD_BIN_BOOL=0 
  elif [ "$1" = "${FTP_CMD_PROMPT}" ]; then
    if [ ${FTP_CMD_PROMPT_BOOL} -eq 0 ]; then
      FTP_CMD_PROMPT_BOOL=1      
    else                         
      FTP_CMD_PROMPT_BOOL=0                             
    fi      
  else
      return 1  
  fi
  return 0
}

#******************************************************************************
# print_ftp_stats:
# 1. When user input ftp command, bin/prompt/ascii, show the status.
# Parameters:
# $1. ${user_input_path}.
# returns: N/A
#
print_ftp_stats ()
{
  if [ ${FTP_CMD_BIN_BOOL} -eq 1 ]; then      
    ${ECHO} "You are in Binary mode."
  fi        
  # Please pay attention to the -1 judegement.
  # Because the ~ operator can change 0 to -1. 
  if [ ${FTP_CMD_PROMPT_BOOL} -eq 1 ]; then      
    ${ECHO} "Interactive mode on."
  else      
    ${ECHO} "Interactive mode off."
  fi   
  if [ ${FTP_CMD_ASCII_BOOL} -eq 1 ]; then      
    ${ECHO} "You are in ASCII mode."
  fi
}            

#******************************************************************************
# list_files_on_ftp: (OMYLADYGAGA, WHAT A COMPLECATED FUNC I WROTE O(∩_∩)O~ )
# 1. List files under ${FTP_PATH_TO_BE_LIST} 
#    path.
# returns: 0 for Yes, 1 for No
#
list_files_on_ftp ()
{             
  ${ECHO} ""
  encap_ftp_credentials_process  $1
              
  user_input_path=${FTP_PATH_TO_BE_LIST}    
  # $more_than_first_time, after first time input, need check the path whether is a abs 
  # or relative path.
  previous_path="" 
  first_words_valid=0            
  
  first_char=`echo | awk '{ print substr("'"$user_input_path"'",0,1) }'`
  if [ "${first_char}" != "/" ]; then 
    ${ECHO} "[INFO] The path you pass to -l must be started with /."
    ${ECHO} "[INFO] Or you can input Keywords, like home, nb70build, opsbuild."
    ${ECHO} "[INFO] Please refer to usage for more details."    
    ${ECHO} "" 
    exit 1 
  fi                      
                   
  # If the input is q, exit;
  # if not, list files under $user_input_path or do cmd_prompt.
  until [ "${user_input_path}" == "q" ]
  do   
    execute_ftp_cmd_bool=0
    if [ "${user_input_path}" != "" ]; then  # Users input something                  
      # To get word count of $user_input_path, if >1, judge the first
      # word whether is a key word, like get, put, bin
      get_cmd_number=`${ECHO} ${user_input_path} | wc -w`
      if [ ${get_cmd_number} -gt 1 ]; then
        first_word=`${ECHO} ${user_input_path} | awk '{ print $1}' ` 
        check_key_word ${first_word}
        key_words_valid=$? 
        if [ ${key_words_valid} -eq 0 ]; then          
          if [ ${FTP_CMD_BIN_BOOL} -eq 1 ]; then cmd_bin="bin"; else cmd_bin=""; fi
          if [ ${FTP_CMD_PROMPT_BOOL} -eq 1 ]; then cmd_prompt="prompt"; else cmd_prompt=""; fi
          if [ ${FTP_CMD_GET_BOOL} -eq 1 ]; then cmd_get="mget"; else cmd_get=""; fi
          if [ ${FTP_CMD_PUT_BOOL} -eq 1 ]; then cmd_put="mput"; else cmd_put=""; fi  
          if [ ${FTP_CMD_ASCII_BOOL} -eq 1 ]; then cmd_ascii="mput"; else cmd_ascii=""; fi 
          filelist=`${ECHO} ${user_input_path} | sed "s/${first_word}/""/" `
          #${ECHO} "filelist:${filelist}"
          
          # Only if FTP_CMD_PUT_BOOL==1 or FTP_CMD_GET_BOOL==1, goto below branch            
          if [ ${FTP_CMD_GET_BOOL} -eq 1 ]; then       
            # Notes: it's not necessary to check every file which get/put is not a directory!
            `ftp -n ${FTPADDR} >> ${TMPFILE} 2>&1 << EOF
            user ${FTP_USERNAME} ${FTP_PASSWORD}
            ${cmd_bin} 
            ${cmd_prompt}   
            ${cmd_ascii}
            cd  ${previous_path}
            ${cmd_get} ${filelist}
            close  
            bye              
            EOF
            `
            execute_ftp_cmd_bool=1
          fi
          if [ ${FTP_CMD_PUT_BOOL} -eq 1 ]; then  
            `ftp -n ${FTPADDR} >> ${TMPFILE} 2>&1 << EOF
            user ${FTP_USERNAME} ${FTP_PASSWORD}
            ${cmd_bin} 
            ${cmd_prompt}   
            ${cmd_ascii}
            cd  ${previous_path}
            ${cmd_put} ${filelist}
            close  
            bye      
            EOF
            `
            ${ECHO} "ftp -n ${FTPADDR}  << EOF" > ${TMPFILE} 2>&1
            ${ECHO} "user ${FTP_USERNAME} ${FTP_PASSWORD}" >> ${TMPFILE} 2>&1
            ${ECHO} "${cmd_bin}"           >> ${TMPFILE} 2>&1
            ${ECHO} "${cmd_prompt}"        >> ${TMPFILE} 2>&1
            ${ECHO} "${cmd_ascii}"         >> ${TMPFILE} 2>&1 
            ${ECHO} "cd  ${previous_path}" >> ${TMPFILE} 2>&1
            ${ECHO} "${cmd_put} ${filelist}"   >> ${TMPFILE} 2>&1
            ${ECHO} "close"                >> ${TMPFILE} 2>&1
            ${ECHO} "bye"                  >> ${TMPFILE} 2>&1
            ${ECHO} "EOF"                  >> ${TMPFILE} 2>&1
            execute_ftp_cmd_bool=1
          fi
          
          print_ftp_stats      
          execute_ftp_cmd_bool=1
          
        else    
          execute_ftp_cmd_bool=0       
        fi                                    
      elif [ ${get_cmd_number} -eq 1 ]; then # just list directory  
        # If the input is bin/prompt/ascii, do nothing
        # So be carefull, if you want to go to bin directory, please input 
        # ./bin or ./prompt or ./ascii
        
        # Here it's not necessary to check the return value of check_key_word. 
        check_key_word ${user_input_path}        
        
        if [ ! "${user_input_path}" = "bin" ] && 
           [ ! ${user_input_path} = "prompt" ] && 
           [ ! ${user_input_path} = "ascii" ]; then          
          #first_char=`${ECHO} ${user_input_path:0:1}`
          #Above line only pass on RedHat Ksh. Not on Solaris10 & AIX5.3           
          first_char=`${ECHO} | awk '{ print substr("'"$user_input_path"'",0,1) }'`
          
          # If first_char is /, you don't need to add previous_path to it.
          if [ "${first_char}" != "/" ] && [ "${first_char}" != "" ]; then 
            user_input_path="${previous_path}/${user_input_path}"
          else
            # if $user_input_path is abs path, it's better to reset 
            # ${previous_path} to blank, otherwise the ${previous_path} is more 
            # and more long.
            previous_path=""    
          fi  
          
          `ftp -n ${FTPADDR} > ${TMPFILE} 2>&1 << EOF
          user ${FTP_USERNAME} ${FTP_PASSWORD}
          dir ${user_input_path}                   
          by
          EOF
          `     
          execute_ftp_cmd_bool=2        
        else               
          # You should still set execute_ftp_cmd_bool to 1, in case user_input_path
          # is bin/prompt, to avoid next warning:
          # ${ECHO} "[WARN] You maybe input a wrong command, please try again." 
          if [ "${user_input_path}" = ${FTP_CMD_BIN} ]    || [ "${user_input_path}" = ${FTP_CMD_PROMPT} ] ||
             [ "${user_input_path}" = ${FTP_CMD_PROMPT} ] || [ "${user_input_path}" = ${FTP_CMD_ASCII} ]; then                  
            print_ftp_stats
          fi
          execute_ftp_cmd_bool=3   
        fi 
      else
        execute_ftp_cmd_bool=0        
      fi
    fi   
    #${ECHO} "3 user_input_path:${user_input_path}"
    #${ECHO} "3 previous_path:${previous_path}"    
    
    # if command parse successfully ($execute_ftp_cmd_bool==1), 
    # you need process the result file.
    # if ${execute_ftp_cmd_bool} -eq 1,
    # means [ ! "${user_input_path}" = "bin" ] && [ ! "${user_input_path}" = "prompt" ] && [ ! "${user_input_path}" = "ascii" ].
    # if ${execute_ftp_cmd_bool} -eq 2, means just list dir. 
    if [ ${execute_ftp_cmd_bool} -eq 1 ] || [ ${execute_ftp_cmd_bool} -eq 2 ]; then  
      # Delete the 1,2,3 lines on Linux platforms.
      case "`uname -s`" in
      Linux*)
        sed -i '/^[Please,KERBEROS]/d' ${TMPFILE}        
        ;;
      *)
        ;;
      esac 
      
      more ${TMPFILE} 
      
      # Save new path to be used next time, only if execute_ftp_cmd_bool==2 
      if [ ${execute_ftp_cmd_bool} -eq 2 ]; then
        previous_path=${user_input_path}
      fi 
    elif [ ${execute_ftp_cmd_bool} -eq 3 ] ; then     # If it's a key word or list dir.      
      ${ECHO} ""
    else
      ${ECHO} "[WARN] You maybe input a wrong command, please try again."
    fi 
        
    ${ECHO} ""
    prompt "[ASK] Continue[q, ftp_path]:"     
    #read answer and if it is empty, loop
    read user_input_path  
    if [ "${user_input_path}" == "q" ]; then   
      ${ECHO} ""
      exit 1 
    fi        
    ${ECHO} ""
  done    
  
  ${ECHO} ""   
  
  return 0  
}

#******************************************************************************
# init_prog:
# 1. Init some vars.
# 2. Called by encap_ftp_credentials_process only.
# returns: 0 for Yes, 1 for No
#
init_prog ()
{                          
  DOWNLOADLIST_CONF_NAME="${DOWNLOADLIST_CONF_NAME}${FTP_USERNAME}"      
  DOWNLOADLIST_CONF_LOCAL_PATH="${DOWNLOADLIST_CONF_LOCAL_DIR}/${DOWNLOADLIST_CONF_NAME}"              
  DOWNLOADLIST_CONF_LOCAL_PATH_WITH_HOSTNAME="${HOSTNAME}:/tmp/${DOWNLOADLIST_CONF_NAME}" 
  DOWNLOADLIST_CONF_FTP_PATH="${FTP_USERS_PATH}/${DOWNLOADLIST_CONF_NAME}"    
  DOWNLOADLIST_CONF_FTP_PATH_WITH_IP="FTP://${FTPADDR}${FTP_USERS_PATH}/${DOWNLOADLIST_CONF_NAME}"
  UPLOAD_TO="${FTP_USERS_PATH}/${FTP_USERNAME}" 
}

#******************************************************************************
# main
#        
main ()
{          
  parse_parameters "$@"
   
  #easyftp.sh -h
  #easyftp.sh -u brant -p ftppwd -s 
  #easyftp.sh [-u brant -p ftppwd] -m <-t>
  #easyftp.sh [-u brant -p ftppwd] -m <-a | -r> <ftp_path>  
  #easyftp.sh [-u brant -p ftppwd] -d <local_path>
  #easyftp.sh [-u brant -p ftppwd] -o <local_files>
  #easyftp.sh [-u brant -p ftppwd] -l <path_on_ftp> 
  # u 1 p 2 s 4 m 8 t 16 a 32 r 64 d 128 o 256 l 512
  # Get user options
  user_opt_result=`echo $(( ${FLAG_U} | ${FLAG_P} | ${FLAG_S} | ${FLAG_M} | \
  ${FLAG_L} | ${FLAG_A} | ${FLAG_R} | ${FLAG_D} | ${FLAG_O} | ${FLAG_T}))`
  
  if [ ${user_opt_result} -eq 7 ]; then
    save_credentials ${user_opt_result}
  elif [ ${user_opt_result} -eq 24 ] || [ ${user_opt_result} -eq 27 ]; then    # -m -a
    show_download_conf ${user_opt_result}
  elif [ ${user_opt_result} -eq 40 ] || [ ${user_opt_result} -eq 43 ]; then    # -m -a
    add_new_download_list_to_conf ${user_opt_result}
  elif [ ${user_opt_result} -eq 72 ] || [ ${user_opt_result} -eq 75 ]; then    # -m -r 
    remove_download_list_from_conf ${user_opt_result}
  elif [ ${user_opt_result} -eq 128 ] || [ ${user_opt_result} -eq 131 ]; then  # -d
    download_files_from_conf ${user_opt_result}
  elif [ ${user_opt_result} -eq 256 ] || [ ${user_opt_result} -eq 259 ]; then  # -o
    upload_files_from_local ${user_opt_result}
  elif [ ${user_opt_result} -eq 512 ] || [ ${user_opt_result} -eq 515 ]; then  # -l
    list_files_on_ftp ${user_opt_result}
  else
    ${ECHO} "[WARN] You may input error options, please refer to usage below:"
    usage
  fi 
  
}

################################### MAIN ######################################


main $@


