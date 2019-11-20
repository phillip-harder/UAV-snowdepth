# UAV-snowdepth
Quantifying the ability of UAV lidar and structure from motion products to observe sub-canopy snowdepth.  Code is in support of: Phillip Harder, John W. Pomeroy, and Warren D. Helgason, 2019, Advances in mapping sub-canopy snow depth with unmanned aerial vehicles using structure from motion and lidar techniques. The Cryosphere Discussions. Submitted November 2019

## Accuracy_Analysis.R
R script to compute and plot the error metrics from comparision of UAV-lidar and UAV-SfM DSMs versus manual survey observations segmented by study site and vegetation condition.

## lidar_dsm_process.bat
Windows batch file to process a .las point cloud file from UAV-lidar into a 0.1m resolution digital surface model.  Uses LAStools functions to tile, remove noise, classify ground surface, merge tiles and export dsm.

## SfM_dsm_process.bat
Windows batch file to process a .las point cloud file from UAV-SfM into a 0.1m resolution digital surface model.  Uses LAStools to export a DSM adapted from adapted from https://rapidlasso.com/2018/12/27/scripting-lastools-to-create-a-clean-dtm-from-noisy-photogrammetric-point-cloud/ 

## grid_pt.bat
Windows batch file to compute number of points per 0.5m grid cell from a .las point cloud file with LAStools.

## hv_lidar.bat
Windows batch file to compute vegetation height (90th percentile of point height above surface) at 1 m resolution from a .las point cloud file with LAStools.
