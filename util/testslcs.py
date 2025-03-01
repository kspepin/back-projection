#!/usr/bin/env python3
#
# date sort the geo slcs, merging S1A and S1B

import sys
import os
import string
import subprocess

if len(sys.argv) < 2:
    print 'Usage: testslcs.py len <xloc=width/2> <yloc=xloc>'
    sys.exit(0)

width = sys.argv[1]
xloc=str(int(int(width)/2))
yloc=xloc
if len(sys.argv) > 2:
    xloc=sys.argv[2]
if len(sys.argv) > 3:
    yloc=sys.argv[3]

command = 'ls -1 *.geo'
#print (command)
proc = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True)
(geos, err) = proc.communicate()
geolist=geos.split('\n')

#print (geolist)

f=open('mvcommand','w')
for geo in geolist:
#    print (geo)
    command = '~/util/testcomplex '+geo.rstrip()+' '+width+' '+xloc+' '+yloc
#    print (command)
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True)
    (ret, err) = proc.communicate()
    if ret.find('0.00000000')>-1:
        print (str(ret.find('0.00000000'))+' '+geo.rstrip()+' '+ret)
        f.write('mv zips/'+geo.rstrip().replace('.geo','.zip')+' .\n')
#    ret = os.system(command)

f.close()
