:: a batch script for number of points for a 0.5m grid (0.25 m2 grid cells)
set PATH=%PATH%;C:\LAStools\bin
set LAStools=C:\LAStools\bin
set TILE_SIZE=100
set BUFFER=10
set STEP=0.25
set CORES=11
set list= 19_044_FM_a 18_250_RS_a 18_260_FM_a 18_283_NE_a 18_283_SW_a 18_347_SW_a 19_000_SW_a 19_031_SW_a 19_031_SW_g 19_044_FM_g 19_070_NE_a 19_070_NE_g 19_072_RS_a 19_072_RS_g 19_077_RS_a 19_077_RS_g 19_079_SW_a 19_079_SW_g 19_081_RS_a 19_081_RS_g 19_085_RS_a 19_085_RS_g
set wdir= working directory
lastile -version
pause
FOR %%A IN (%list%) DO (
lasgrid -i %wdir%\Point_Cloud\%%A.las -o %wdir%\grid\%%A_grid.tif -counter -step 0.5
) 

pause