#!/usr/bin/python3

#  testasfgetrawdata.py - download asf raw data granule(s)

import copy
import os
import glob
import shutil

#from IPython.display import clear_output

from asf_notebook import EarthdataLogin
from asf_notebook import new_directory
from asf_notebook import get_wget_cmd
from asf_notebook import input_path
from asf_notebook import get_vertex_granule_info
from asf_notebook import handle_old_data

login = EarthdataLogin()

while True:
    data_dir = input_path("\nPlease enter the name of a directory in which to store download your data.")
    if os.path.exists(data_dir):
        contents = glob.glob('{data_dir}/*')
        if len(contents) > 0:
            choice = handle_old_data(data_dir, contents)
            if choice == 1:
                shutil.rmtree(data_dir)
                os.mkdir(data_dir)
                break
            elif choice == 2:
                break
            else:
                clear_output()
                continue
        else:
            break
    else:
        os.mkdir(data_dir)
        break


analysis_directory = "{os.getcwd()}/{data_dir}"
os.chdir(analysis_directory)
print("Current working directory: {os.getcwd()}")

scenes_str = input("Enter the granule/scene names you wish to download as a comma separated string. \n"
                   "Whitespaces will be ignored.\n")
clear_output()
scenes_str = scenes_str.translate(str.maketrans("ALPSRP185270680", 'L1.0', ''.join(' ')))
# '', '', ''.join(' ')))

scenes = scenes_str.split(',')
print("Scene Names:")
for s in scenes:
    print(s)

for scene in scenes:
    scene_info = get_vertex_granule_info(scene)
    if not scene_info:
        continue
    scene_filename = scene_info["fileName"]
    if not os.path.exists(scene_filename):
        cmd = get_wget_cmd(scene_info["downloadUrl"], login)
        ret = os.system(cmd) #!$cmd
    else:
        print("{scene} already exists.")






#import os
#import sys

#from asf_notebook import path_exists
#from asf_notebook import download_ASF_granule

#if len(sys.argv) < 2:
#    print ('Usage: testasfgetrawdata.py granule')
#    sys.exit(0)

#granule=sys.argv[1]

# where are we running?
#print(os.getcwd())
#path=os.getcwd()

#filename = download_ASF_granule("ALPSRP185270680", 'L1.0')

#print (filename)

