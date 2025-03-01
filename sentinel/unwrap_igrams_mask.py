#!/usr/bin/env python3

#  unwrap_igrams - unwrap set of interferograms

import sys
ver=sys.version_info

    


    


import os
import sys
import math

if len(sys.argv) < 3:
    print ('Usage: unwrap_igrams_mask.py intlist len <lowpass box size=1>')
    sys.exit(1)

filelist=sys.argv[1]
width=sys.argv[2]
box=1
if len(sys.argv)>3:
    box=sys.argv[3]

print (filelist,width,box)

fsbas=open(filelist,'r')
sbas=fsbas.readlines()
for line in sbas:
    words=line.split()
    intfile=words[0]
    print ('intfile: ',intfile)
    # lowpass filter a bit to aid unwrapping if desired
    unwfile=intfile.replace('int','unw')
    lowpassfile=intfile.replace('int','int.lowpass')
    cfile=intfile.replace('int','cc')
    if abs(float(box)-1) > 0.1:
        ret=os.system('$PROC_HOME/ps/lowpass '+intfile+' '+width+' '+box)
        ret=os.system('$PROC_HOME/bin/snaphu '+lowpassfile+' '+width+' -d -o '+unwfile+' -c '+cfile+' -M mask.raw --mcf')
    else:
        ret=os.system('$PROC_HOME/bin/snaphu '+intfile+' '+width+' -d -o '+unwfile+' -c '+cfile+' -M mask.raw --mcf')

sys.exit()

