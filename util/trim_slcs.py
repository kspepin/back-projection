#!/usr/bin/env python3

#  trim_slcs - subset slc files as done in ps_sbas_igrams

import string
import os
import sys
import math

if len(sys.argv) < 6:
    print 'Usage: trim_slcs.py geolist dem_rsc_file xstart ystart xsize ysize'
    sys.exit(1)

geolist=sys.argv[1]
demrscfile=sys.argv[2]
xstart=sys.argv[3]
ystart=sys.argv[4]
xsize=sys.argv[5]
ysize=sys.argv[6]
xlooks=1
ylooks=1

# rsc file for extracted portion
frsc=open('dem.rsc','w')

# dem params
rsc=open(demrscfile,'r')
words=rsc.readline()
demwidth=words.split()[1]
frsc.write(words.replace(demwidth,str(int(xsize)/int(xlooks)))) # width
words=rsc.readline()
demlength=words.split()[1]
frsc.write(words.replace(demlength,str(int(ysize)/int(ylooks)))) #length
wordsxfirst=rsc.readline()
wordsyfirst=rsc.readline()
wordsxstep=rsc.readline()
demxstep=wordsxstep.split()[1]
wordsystep=rsc.readline()
demystep=wordsystep.split()[1]
xstep=str(float(demxstep)*int(xlooks))
ystep=str(float(demystep)*int(ylooks))
demxfirst=wordsxfirst.split()[1]
xfirst=str(float(demxfirst)+(int(xstart)-1)*float(demxstep))
frsc.write(wordsxfirst.replace(demxfirst,xfirst)) # x_first
demyfirst=wordsyfirst.split()[1]
yfirst=str(float(demyfirst)+(int(ystart)-1)*float(demystep))
frsc.write(wordsyfirst.replace(demyfirst,yfirst)) # y_first
frsc.write(wordsxstep.replace(demxstep,xstep)) # x_step
frsc.write(wordsystep.replace(demystep,ystep)) # y_step
words=rsc.readline()
frsc.write(words) # x_unit
words=rsc.readline()
frsc.write(words) # y_unit
words=rsc.readline()
frsc.write(words) # z_offset
words=rsc.readline()
frsc.write(words) # z_scale
words=rsc.readline()
frsc.write(words) # projection
rsc.close()

# geolist read in

geofiles=[]
fgeo=open(geolist,'r')
geo=fgeo.readlines()
for line in geo:

    inslcfile=line.rstrip()
    slcfile=line.replace('../','').rstrip()

    print 'slc file ',' ',inslcfile,' ',slcfile
    print demwidth,xstart,ystart,xsize,ysize

    command='$PROC_HOME/util/subsetmph '+inslcfile+' '+slcfile+' '+demwidth+' '+xstart+' '+ystart+' '+xsize+' '+ysize
    print (command)
    ret = os.system(command)

sys.exit()

