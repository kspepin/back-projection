#!/usr/bin/env python3


import sys
import string
import os
import math

if len(sys.argv) < 1:
    print ('Usage: rscgeometry.py demrsc_file ')
    sys.exit(1)
    

rscfile=sys.argv[1]

# get info from rsc file
rsc=open(rscfile,'r')
words=rsc.readline()
demwidth=words.split()[1]
words=rsc.readline()
demlength=words.split()[1]
words=rsc.readline()
demxfirst=words.split()[1]
words=rsc.readline()
demyfirst=words.split()[1]
words=rsc.readline()
xstep=words.split()[1]
words=rsc.readline()
ystep=words.split()[1]
rsc.close()

min_lat=float(demyfirst)+(int(demlength)-1)*float(ystep)
max_lat=float(demyfirst)
min_lon=float(demxfirst)
max_lon=float(demxfirst)+(int(demwidth)-1)*float(xstep)

print('    <LatLonBox>'+"\n")
print('        <north> '+str(min_lat)+' </north>'+"\n")
print('        <south> '+str(max_lat)+' </south>'+"\n")
print('        <east> '+str(max_lon)+' </east>'+"\n")
print('        <west> '+str(min_lon)+' </west>'+"\n")
print('    </LatLonBox>'+"\n")

