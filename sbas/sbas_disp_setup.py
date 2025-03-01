#!/usr/bin/env python3

#  sbas_disp_setup.py - create auxiliary files for displacement direct inversion

import sys
from datetime import datetime
import string
import os
import math

if len(sys.argv) < 3:
    print 'Usage: sbas_disp_setup.py sbas_list geolist'
    sys.exit(1)

sbas_list=sys.argv[1]
geo_list=sys.argv[2]

fgeo=open(geo_list,'r')
geo=fgeo.readlines()

slctime=list(float(i) for i in range(0, len(geo)))
deltatime=list(float(i) for i in range(0, len(geo)))
k=0
for line in geo:
    words=line.split()
#    print words[-1]
    slc=words[-1]
    first=slc.find('20')
    slcname=slc[first:first+8]
    slcyear=slcname[0:4]
    slcmon=slcname[4:6]
    slcday=slcname[6:8]
    jd=datetime.strptime(slcname, '%Y%m%d').toordinal()+1721424.5
    slctime[k] = jd #int(slcyear)+float(int(slcmon))/12.+float(int(slcday))/360.
    if k > 0:
        deltatime[k] = slctime[k]-slctime[k-1]
        #deltatime[k] = round((float(slctime[k])-float(slctime[k-1]))*360.)
      #  print k,slctime,deltatime,'\n'
    k=k+1

print
print 'slctime ',slctime
print 'deltime ',deltatime

ftimedeltas=open('timedeltas.out','w')  # save time intervals between slcs
for i in range(1,len(deltatime)):
    ftimedeltas.write(str(deltatime[i])+'\n')

fsbas=open(sbas_list,'r')
sbas=fsbas.readlines()

fbperp=open('Bperp.out','w')
fdeltime=open('deltime.out','w')
fA=open('A.out','w')

id=0
for line in sbas:
    words=line.split()
    file0=words[0]
    file1=words[1]
    timebaseline=words[2]
    spacebaseline=words[3]

#  get a short name for file0 and file1 files
    first=file0.find('20')
    file0name=file0[first:first+8]
    file0year=file0name[0:4]
    file0mon=file0name[4:6]
    file0day=file0name[6:8]
    slc1time=datetime.strptime(file0name, '%Y%m%d').toordinal()+1721424.5

    first=file1.find('20')
    file1name=file1[first:first+8]
    file1year=file1name[0:4]
    file1mon=file1name[4:6]
    file1day=file1name[6:8]
    slc2time=datetime.strptime(file1name, '%Y%m%d').toordinal()+1721424.5

    iprint=0
    if iprint==1:
        print file0
        print file0name
        print file1
        print file1name
        print timebaseline
        print spacebaseline
        print file0year+' '+file0mon+' '+file0day+' '+str(slc1time)+'\n'

    # spatial baseline to Bperp.out
    fbperp.write(spacebaseline+'\n')

    # temporal baseline to deltime.out
    id=id+1
    fdeltime.write(str(id)+' '+timebaseline+' '+str(slc1time)+' '+str(slc2time)+'\n')

    # time interval matrix to A.out
    # which slc for file0 and file1?
    k=0
    for line in geo:
        words=line.split()
        slc=words[-1]
        first=slc.find('20')
        slcname=slc[first:first+8]
        if slcname == file0name:
            kfile0=k
        if slcname == file1name:
            kfile1=k
        k=k+1

    times=list(float(0) for i in range (0,len(geo)))
#    print kfile0,' ',kfile1
    if kfile0 < kfile1:
        for i in range(kfile0,kfile1):
            times[i]=deltatime[i+1]
    if kfile0 > kfile1:
        for i in range(kfile1,kfile0):
            times[i]=-deltatime[i+1]
    for i in range(0,len(times)-1):
        if i == kfile0:
            fA.write('-1 ')
        else:
            if i==kfile1:
                fA.write('1 ')
            else:
                fA.write('0 ')
    fA.write('\n')
fA.close()

sys.exit()

