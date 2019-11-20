:: a batch script computing vegetation height from lidar data
set PATH=%PATH%;C:\LAStools\bin
set LAStools=C:\LAStools\bin
set TILE_SIZE=100
set BUFFER=10
set STEP=0.25
set CORES=11
set list= 19_000_SW_a 18_283_NE_a 18_260_FM_a 18_250_RS_a
set wdir= working directory
lastile -version
pause
FOR %%A IN (%list%) DO (
rmdir tiles /s /q
mkdir tiles
:: create a temp1orary tiling with tile size and buffer 30
lastile -i %wdir%\Point_Cloud\%%A.las ^
        -set_classification 0 ^
       -tile_size %TILE_SIZE% -buffer %BUFFER% -flag_as_withheld ^
        -o tiles\tile.laz -olaz
:: classify noise points
rmdir tiles_denoised /s /q
mkdir tiles_denoised
lasnoise -i tiles\tile*.laz ^
        -step_xy 1 -step_z 1 ^
        -classify_as 7 ^
        -odir tiles_denoised -olaz ^
        -cores %CORES%
:: classify surface points
rmdir tiles_ground /s /q
mkdir tiles_ground
lasground_new -i tiles_denoised\tile*.laz ^
              -ignore_class 7 ^
              -nature ^
              -odir tiles_ground -olaz ^
              -cores %CORES%
::replace z points with height points              
lasheight -i tiles_ground\tile*.laz -replace_z ^         
            -o temp_tiles_height -olaz ^
            -cores %CORES%
lasmerge -i tiles_ground\tile*.las ^
         -drop_withheld ^
         -o %wdir%\%%A_height.las -olas
::compute 90th percentile of height at 1m resolution to estimate top of canopy         
lascanopy -i %wdir%\%%A_height.las -step 1 -height_cutoff 0.1 -p 90 -otif
) 
pause
