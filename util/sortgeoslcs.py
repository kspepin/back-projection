#!/usr/bin/env python3
#
# date sort the geo slcs, merging S1A and S1B

import sys
import os
import string

if len(sys.argv) < 1:
    print ('Usage: sortgeoslcs.py geolist')
    sys.exit(0)

geolist = sys.argv[1]

fgeos=open(geolist,'r')
geofiles=fgeos.readlines()
fgeos.close()

#  sort into n-tuples

k=0
geotuple=[]
for geo in geofiles:
    print (geo.split('_'))
    print (geo.split('_')[-1].rstrip())
    geotuple.append(geo.split('_'))
    geotuple[k][-1]=geotuple[k][-1].rstrip()
    print (geotuple[k])
    k=k+1

# sort by date field
slclist=sorted(geotuple, key=lambda slc: slc[6])

#  and write the new geolist
fgeo=open(geolist,'w')

for slc in slclist:
    print ('_'.join(slc))
    fgeo.write('_'.join(slc))
    fgeo.write('\n')

fgeo.close()

