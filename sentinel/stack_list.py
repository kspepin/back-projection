#!/usr/bin/env python3

# create a list of stack pairs

import sys
import subprocess
from datetime import datetime 
import os

if len(sys.argv) < 4:
    print ('Usage: stack_list.py stackdate(yyyymmdd) max_temporal max_spatial')
    sys.exit(1)

stackdate=sys.argv[1]
maxtemporal=float(sys.argv[2])
maxspatial=float(sys.argv[3])

# julian day for event to stack over
stackjd=datetime.strptime(stackdate, '%Y%m%d').toordinal()+1721424.5
print ('Stack julian day: ',stackjd)

#  get a list of the geocoded slc files
command = 'ls -1 ../*.geo'
print (command)
proc = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True)
(geos, err) = proc.communicate()

#  sort geofiles by date order
geos=geos.split()
names_times=[]

for i in range(0,len(geos)):
    words=str(geos[i],'UTF-8')
    wordstring=str(words)
    char1=wordstring.find('SSV_')
    if char1 < 0:
        char1=wordstring.find('SDV_')
        print ('This is a dual pol acquisition')
    else:
        print ('This is a single pol acquisition')
    if char1 < 0:
        char1=wordstring.find('SSH_')
        if char1 < 0:
            char1=wordstring.find('SDH_')
            print ('This is a dual pol acquisition')
        else:
            print ('This is a single pol acquisition')

    char2=wordstring[char1:].find('T')

    scenedate=words[char1+4:char1+char2]

    jd=datetime.strptime(str(scenedate), '%Y%m%d').toordinal()+1721424.5
    print ('Julian day ',jd)

    names_times.append(str(jd)+' '+str(geos[i]))

#print names_times
sortedgeos=sorted(names_times)
#print (sortedgeos)

#  estimate baseline and create a file for the time-baseline plot
ftb=open('stack_list','w')

# create lists of dates and filenames, write out geolist
geolist=open('geolist','w')
jdfile=open('jdlist','w')
jdlist=[]
for i in range(0,len(sortedgeos)):
    geos[i]=sortedgeos[i].split()[1]
    geolist.write(geos[i].replace('b','',1).replace("'",'')+'\n')

    jdlist.append(float(sortedgeos[i].split()[0]))
    jdfile.write(str(jdlist[i])+'\n')

geolist.close()
jdfile.close()
print (jdlist)
#print (geos)
 
#  call the spatial baseline estimator
print ('Estimating baselines...')
    
for i in range(0,len(jdlist)):
    for j in range(0,i):
        #  spatial baseline estimator
        #        print ('type geos ',type(geos[i]))
        orbtimingi=geos[i].strip().replace('geo','orbtiming').replace('b','',1)
        orbtimingj=geos[j].strip().replace('geo','orbtiming').replace('b','',1)
        #        print ('type orbtiming ',type(orbtimingi),orbtimingi)
        command = '$PROC_HOME/sentinel/geo2rdr/estimatebaseline '+orbtimingi+' '+orbtimingj
        #        command = '$PROC_HOME/sentinel/geo2rdr/estimatebaseline '+geos[i].strip().replace('geo','orbtiming')+' '+geos[j].strip().replace('geo','orbtiming')
        #print (command)
        proc = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True)
        (baseline1, err) = proc.communicate()
        if abs(float(baseline1)) <= maxspatial:
            
            baseline2=abs(jdlist[i]-jdlist[j])
            if baseline2 <= maxtemporal:
                geostri=geos[i].replace('b','',1).replace("'",'')
                geostrj=geos[j].replace('b','',1).replace("'",'')
                # and write out those that span the event
                if (jdlist[j] < stackjd) & (jdlist[i] > stackjd):
                    ftb.write(geostrj+' '+geostri+' '+str(baseline2)+' '+str(baseline1,'UTF-8').strip()+'\n')

print ('stack list written')
ftb.close()
