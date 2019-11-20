:: a batch script for converting photogrammetry points into a
:: number of products with a tile-based multi-core batch pipeline
:: include LAStools in PATH to allow running script from anywhere
:: adapted from https://rapidlasso.com/2018/12/27/scripting-lastools-to-create-a-clean-dtm-from-noisy-photogrammetric-point-cloud/ 

set PATH=%PATH%;C:\LAStools\bin
set LAStools=C:\LAStools\bin
set NUM_CORES=10
set list= 19_044_FM_g 19_070_NE_g 19_031_SW_g 19_072_RS_g 19_077_RS_g 19_079_SW_g  19_081_RS_g 19_083_RS_g 19_085_RS_g
set wdir=working directory
lastile -version
pause
FOR %%A IN (%list%) DO (
rmdir .\1_tiles_temp /s /q
mkdir .\1_tiles_temp
::tile data for parallel processing
lastile -i %wdir%\Point_Cloud\%%A.las ^
     -set_classification 0 ^
     -tile_size 250 -buffer 10 -flag_as_withheld ^
     -o 1_tiles_temp\%%A.las
:: sort buffered tiles into more spatially coherent order
rmdir .\2_tiles_temp /s /q
mkdir .\2_tiles_temp
lassort -i 1_tiles_temp\%%A_*.las ^
         -odir 2_tiles_temp ^
         -cores %NUM_CORES%
:: classify 25th percentile point of 20 cm by 20 cm cells with 25 or more points as 8
rmdir .\3_tiles_temp /s /q
mkdir .\3_tiles_temp
lasthin -i 2_tiles_temp\%%A_*.las ^
          -step 0.2 ^
          -percentile 25 25 ^
          -classify_as 8 ^
          -odir 3_tiles_temp ^
          -cores %NUM_CORES%
:: classify the isolated points as 9 (when checking only points of class 8)
rmdir .\4_tiles_temp /s /q
mkdir .\4_tiles_temp
lasnoise -i 2_tiles_temp\%%A_*.las ^
          -ignore_class 0 ^
          -step_xy 0.20 -step_z 0.05 -isolated 3 ^
          -classify_as 9 ^
          -odir 4_tiles_temp ^
          -cores %NUM_CORES%
:: :: classify temporary ground points as 2 (checking only the remaining points of class 8)
rmdir .\5_tiles_temp /s /q
mkdir .\5_tiles_temp
lasground -i 4_tiles_temp\%%A_*.las ^
           -ignore_class 0 9 ^
           -step 5 ^
           -odir 5_tiles_temp ^
           -cores %NUM_CORES%
:: :: classify all points as noise 7 that are 2.5 cm below the temporary ground points
rmdir .\6_tiles_temp /s /q
mkdir .\6_tiles_temp
lasheight -i 5_tiles_temp\%%A_*.las ^
           -classify_below -0.025 7 ^
           -classify_above -0.025 1 ^
           -odir 6_tiles_temp ^
           -cores %NUM_CORES%
:: :: classify the lowest non-noise point per 10 cm by 10 cm cell as class 8 
rmdir .\7_tiles_temp /s /q
mkdir .\7_tiles_temp
lasthin -i 6_tiles_temp\%%A_*.las ^
         -ignore_class 7^
         -step 0.1 ^
         -lowest ^
         -classify_as 8 ^
         -odir 7_tiles_temp ^
         -cores %NUM_CORES%
::classify noise points         
rmdir .\4_tiles_temp0 /s /q
mkdir .\4_tiles_temp0
lasnoise -i 7_tiles_temp\%%A_*.las ^
          -ignore_class 7 ^
          -step 0.25 -isolated 100 ^
          -classify_as 8 ^
          -odir 4_tiles_temp0 ^
          -cores %NUM_CORES%
:: :: classify the points that have class 8 into ground (2) and non-ground (1) points 
rmdir .\8_tiles_temp /s /q
mkdir .\8_tiles_temp
lasground_new -i 4_tiles_temp0\%%A_*.las ^
              -ignore_class 1 7 ^
              -step 10 ^
              -extra_fine ^
              -spike 0.5 ^
              -spike_down 0.5 ^
              -odir 8_tiles_temp ^
              -cores %NUM_CORES%
:: :: interpolate and raster the ground points into a 25 cm DTM 
lasmerge -i 8_tiles_temp\%%A_*.las ^
         -keep_class 2 -drop_withheld ^
         -o %wdir%\%%A_bare.las -olas
blast2dem -i %wdir%\%%A_bare.las^
          -step 0.1 -o %wdir%\DSM\%%A.tif
) 
pause
