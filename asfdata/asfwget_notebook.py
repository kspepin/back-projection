#!/usr/bin/python3
#
#
#  asfwget - download set of asf raw sentinel products
#
#   command template: 
#  "https://datapool.asf.alaska.edu/RAW/SA/S1A_IW_RAW__0SDV_20200209T043049_20200209T043122_031171_039571_0730.zip"
#

import os
import sys
import subprocess

if len(sys.argv) < 2:
    print ("usage: asfwget_notebook.py scenelist\n","  scenelist contains granule names starting with S1(A,B)")
    sys.exit(0)

scenefile=sys.argv[1]
fscenes=open(scenefile,'r')
scenelist=fscenes.readlines()
fscenes.close()

# get credentials and remove the file for security
fcred=open('.credentials','r')
username=fcred.readline().rstrip()
password=fcred.readline().rstrip()
#print (username)
#print (password)
fcred.close()
#os.remove('.credentials')

AB=''
num=0
command=[]
for scene in scenelist:
    if len(scene)>1:
        if scene.find('S1A')>=0:
            AB='A'
        if scene.find('S1B')>=0:
            AB='B'
        print ('Downloading scene: ',scene.rstrip())
#        command.append(subprocess.Popen(['wget','-qN','--user='+username,'--password='+password,'https://datapool.asf.alaska.edu/RAW/S'+AB+'/'+scene.replace('-RAW','').rstrip()+'.zip','--show-progress']))
        command.append(subprocess.Popen(['wget','-qN','--user='+username,'--password='+password,'https://datapool.asf.alaska.edu/RAW/S'+AB+'/'+scene.replace('-RAW','').rstrip()+'.zip']))
        num=num+1

for i in range(num):
    command[i].wait()

print('Download complete.\n')

sys.exit()
