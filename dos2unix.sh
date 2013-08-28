#!/bin/sh

# Revision    : 1.1
# CreateDate  : 2011/07/07
# Source      : dos2unix.sh
# Author      : BrantChen2008@gmail.com
# Description :  
# This shell script is to convert files (you can customize the file filter 
# pattern in code) which are in dos file format to unix file format 
# automatically.
# Notes       :
# 1. Please note this shell should be running under Linux.  No test on other OS.

# Cautions    :
# The script will overwrite original files with unix file format.   

#******************************************************************************
# Copyright: Copyright 2011 Brant Chen (BrantChen2008@gmail.com, 
# or xkdcc@163.com), All Rights Reserved 
#******************************************************************************
    

for file in `find . -name "*.tst" -o -name "*.pm" -o -name "*.pl" -o -name "*.in" -o -name "*.txt"` ; do
  tmp=$file".sed"
  have_dos_sign=`grep -l "^M" $file | wc -l`
  if [ $have_dos_sign -ge 1 ] ; then
    sed "s/^M//" $file > $tmp 
    rm -f $file && cp $tmp $file && rm -f $tmp
    echo "file [$file] has been changed.\n"
  fi
done
   
