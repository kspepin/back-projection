#!/usr/bin/env python3
#
#  do files in a list exist
#

import sys
import os
import string
import time
import subprocess

if len(sys.argv) < 2:
    print "Usage: doeslistexist.py filelist"
    sys.exit(0)

filelist=sys.argv[1]

fd=open(filelist,'r')
files=fd.readlines()
fd.close()

for file in files:
    infile=file.strip()
    if not os.path.exists(infile):
        print ('No file ',infile)

print (type(files))
files.sort()

for i in range(len(files)-1):
    if files[i] == files[i+1]:
        print (files[i], files[i+1])
