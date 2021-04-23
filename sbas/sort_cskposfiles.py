#!/usr/bin/env python3

# sort the position file list

import sys
ver=sys.version_info

    


    

import os

if len(sys.argv) < 2:
    print 'Usage: sort_cskposfiles.py posfilelist'
    sys.exit(1)

poslist=sys.argv[1]
ierr=os.system('mv '+poslist+' '+poslist+'.orig')

fpos=open(poslist+'.orig','r')

fsort=open(poslist,'w')

poss=fpos.readlines()
fpos.close()
date=[None]*len(poss)
both=date
for i in range(0,len(poss)):
    words=poss[i].split()
    name=words[-1]
    first=name.find('20')
    date[i]=name[first:first+8]
    print '1 ',words
    pos=poss[i]
    eol=pos.find('\n')
    both[i]=date[i]+pos[0:eol]

print both
possort=sorted(both)

for i in range(0,len(poss)):
    entry=possort[i]
    print entry
    #first=entry.find(' ')
    newpos=entry[8:]
    fsort.write(newpos+'\n')

fsort.close()
