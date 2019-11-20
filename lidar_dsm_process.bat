:: a batch script for converting lidar points into bare earth digital surface model
set PATH=%PATH%;C:\LAStools\bin
set LAStools=C:\LAStools\bin
set TILE_SIZE=250
set BUFFER=10
set STEP=0.25
set CORES=11
set list= 18_250_RS_a 18_260_FM_a 18_283_NE_a 18_283_SW_a 18_347_SW_a 19_031_SW_a 19_044_FM_a 19_070_SW_a 19_070_NE_a 19_072_RS_a 19_074_SW_a 19_077_RS_a 19_079_SW_a 19_081_RS_a 19_085_RS_a 19_088_RS_a 19_093_SW_a 19_094_RS_a 19_000_SW_a 19_099_RS_a
set wdir=working directory

lastile -version
pause
FOR %%A IN (%list%) DO (
:: create temp1orary tile directory
rmdir tiles /s /q
mkdir tiles
:: create a temp1orary tiling with tile size and buffer 30
lastile -i wdir\Point_Cloud\%%A.las ^
        -set_classification 0 ^
       -tile_size %TILE_SIZE% -buffer %BUFFER% -flag_as_withheld ^
        -o tiles\tile.las
::classify noise points
rmdir tiles_denoised /s /q
mkdir tiles_denoised
lasnoise -i tiles\tile*.las ^
        -step 1 -isolated 10 ^
        -classify_as 7 ^
        -odir tiles_denoised ^
        -cores %CORES%
::classify bare surface points
rmdir tiles_ground /s /q
mkdir tiles_ground
lasground_new -i tiles_denoised\tile*.las ^
              -ignore_class 7 ^
              -step 10 ^
              -extra_fine ^
              -spike 0.5 ^
              -spike_down 2.5 ^
              -odir tiles_ground ^
              -cores %CORES%
lasmerge -i tiles_ground\tile*.las ^
         -drop_withheld -keep_class 2 ^
         -o %wdir%\%%A_bare.las -olas
blast2dem -i %wdir%\%%A_bare.las^
          -step 0.1 -o %wdir%\DSM\%%A.tif
) 

pause