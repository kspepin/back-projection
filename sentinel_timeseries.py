#!/usr/bin/env python3
#
#
#  sentinel_timeseries.py -- create time series from list of sentinel file names
#
#

import os
import subprocess
import sys
import time

print ( "\n"+"Generate Sentinel-1 Timeseries"+"\n")
if len(sys.argv)<2:
    looksac='10'
    looksdn='10'
else:
    looksac=str(sys.argv[1])
    looksdn=looksac
    if len(sys.argv)>2:
        looksdn=str(sys.argv[2])

#print ('Looks across and down: ',looksac,looksdn)

if len(sys.argv)<4:
    timebaseline='1000'
    spatialbaseline='1000'
else:
    timebaseline=str(sys.argv[3])
    spatialbaseline=timebaseline
    if len(sys.argv)>4:
        spatialbaseline=str(sys.argv[4])
print ('You are creating a stack with looks '+looksac+', '+looksdn+' and baselines '+timebaseline+', '+spatialbaseline+'\n\n')
time.sleep(3)

# first run the .geo stack generator
command = '$PROC_HOME/sentinel_terminal.py'
print (command)
ret = os.system(command)

#  get back to the data area
ret = os.chdir('mydata')

#  merge any mutifile track/frame pairs
command = '$PROC_HOME/util/merge_slcs.py'
print (command)
ret = os.system(command)

# create an sbas subdirectory and move to that directory
command = 'mkdir sbas'
print (command)
ret = os.system(command)
ret = os.chdir('sbas')

# retrieve size of geo files from full size .rsc file
fe=open('../elevation.dem.rsc','r')
words=fe.readline()
demwidth=words.split()[1]
words=fe.readline()
demlength=words.split()[1]
fe.close()

# create appropriate sbas list
command = '$PROC_HOME/sentinel/sbas_list.py '+timebaseline+' '+spatialbaseline
print (command)
ret = os.system(command)

# form all interferograms, take looks to get smaller file if needed
command = '$PROC_HOME/sentinel/ps_sbas_igrams.py sbas_list ../elevation.dem.rsc 1 1 '+demwidth+' '+demlength+' '+looksac+' '+looksdn
print (command)
ret = os.system(command)

# size of multilooked int and unw files from .rsc file
fe=open('dem.rsc','r')
words=fe.readline()
unwwidth=words.split()[1]
words=fe.readline()
unwlength=words.split()[1]
fe.close()

# create a reduced size dem to match multilooked files
command = '$PROC_HOME/util/nbymi2 ../elevation.dem dem '+demwidth+' '+str(int(int(demwidth)/int(unwwidth)))+' '+str(int(int(demlength)/int(unwlength)))
print (command)
ret = os.system(command)

# unwrap interferograms in parallel
command = '$PROC_HOME/util/unwrap_parallel.py '+unwwidth
print (command)
ret = os.system(command)

# set up sbas ancillary files
command = '$PROC_HOME/sbas/sbas_setup.py sbas_list geolist'
print (command)
ret = os.system(command)

# gather parameters for sbas calculation
ret = os.system('cp intlist unwlist')
ret = os.system("sed -i 's/int/unw/g' unwlist")

proc = subprocess.Popen("wc -l < unwlist",stdout=subprocess.PIPE, shell=True)
(nunwfiles,err)=proc.communicate()
proc = subprocess.Popen("wc -l < geolist",stdout=subprocess.PIPE, shell=True)
(nslcs,err)=proc.communicate()

# troposphere correction using regression vs elevation
command = '$PROC_HOME/int/tropocorrect.py unwlist '+unwwidth+' '+unwlength
print (command)
ret = os.system(command)

# compute sbas velocity solution
#command = '$PROC_HOME/sbas/sbas unwlist '+nunwfiles.rstrip()+' '+nslcs.rstrip()+' '+unwwidth+' ref_locs'
command = '$PROC_HOME/sbas/sbas unwlist '+str(nunwfiles.decode()).rstrip()+' '+str(nslcs.decode()).rstrip()+' '+unwwidth+' ref_locs'
print (command)
ret = os.system(command)

# some cleanup to keep things neat
ret = os.system('mv intlist saveintlist')
command = 'rm listofintlists intlist*'
print (command)
ret = os.system(command)
ret = os.system('mv saveintlist intlist')

print('Timeseries generated')
