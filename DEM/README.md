# copernicusdem
Howard Zebker's code to download and mosaic Copernicus DEM 

you need wget installed on your machine to download the DEMs
you need libtiff installed on your machine
you need gcc and gfortran to build the required programs

you need to place the following programs on your PATH:
 coptiffread
 makeDEMcop
 mosaicDEM
 createspecialdem
 cop_dem.py
 createDEMcop.py
 sentinel_coordinates_copernicus.py
 
you need to build these executables:

 gcc coptiffread.c -o coptiffread -ltiff
 gfortran makeDEMcop.f90 -o makeDEMcop
 gfortran mosaicDEM.f90 -o mosaicDEM
 gfortran createspecialdem.f90 -o  createspecialdem

make sure the python is executable

 chmod a+x cop_dem.py
 chmod a+x createDEMcop.py
 chmod a+x sentinel_coordinates_copernicus.py

now put everything needed on your path

 cp coptiffread $DIRECTORY_WHERE_YOU_KEEP_YOUR_EXECUTABLES
 cp makeDEMcop $DIRECTORY_WHERE_YOU_KEEP_YOUR_EXECUTABLES
 cp mosaicDEM $DIRECTORY_WHERE_YOU_KEEP_YOUR_EXECUTABLES
 cp createspecialdem $DIRECTORY_WHERE_YOU_KEEP_YOUR_EXECUTABLES
 cp cop_dem.py $DIRECTORY_WHERE_YOU_KEEP_YOUR_EXECUTABLES
 cp createDEMcop.py $DIRECTORY_WHERE_YOU_KEEP_YOUR_EXECUTABLES
 cp sentinel_coordinates_copernicus.py $DIRECTORY_WHERE_YOU_KEEP_YOUR_EXECUTABLE

