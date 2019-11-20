.libPaths(new="C:/RPackages")
library(raster)
library(reshape2)
library(rgdal)
library(plyr)
library(dplyr)
library(maptools)
library(ggplot2)
library(lubridate)

#error metric functions
#Root Mean Square Error
RMSE <- function(obs, est) {
  i<-which(!is.na(obs)&!is.na(est))
  sqrt(sum((est[i]-obs[i])^2)/length(est[i]))
}
#mean bias
mb<-function(obs,est){
  i<-which(!is.na(obs)&!is.na(est))
  sum(est[i])/sum(obs[i])-1
} 
#bias
bias<-function(obs,est){
  i<-which(!is.na(obs)&!is.na(est))
  sum(est[i]-obs[i])/length(est[i])
}  
#r^2 coefficient of determination
r2fun <- function(obs, pred){
  i<-which(!is.na(obs)&!is.na(pred))
  ((length(pred[i])*(sum(pred[i]*obs[i]))-sum(obs[i])*sum(pred[i]))/
      (((length(pred[i])*sum(obs[i]^2)-sum(obs[i])^2)^0.5)*((length(pred[i])*sum(pred[i]^2)-sum(pred[i])^2)^0.5)))^2
}
#convert long lat to UTM
LongLatToUTM<-function(x,y,zone){
  xy <- data.frame(ID = 1:length(x), X = x, Y = y)
  coordinates(xy) <- c("X", "Y")
  proj4string(xy) <- CRS("+proj=longlat +datum=WGS84")  ## for example
  res <- spTransform(xy, CRS(paste("+proj=utm +zone=",zone," ellps=WGS84",sep='')))
  return(as.data.frame(res))
}

#set working directory
setwd("F:/lidar_sd/Archive/")

#read in manual snow depth and ground surface survey data
depth<-read.csv('Survey_data/survey_data.csv')

#Convert lat long to UTM
depth$X_utm<-NA
depth$Y_utm<-NA
depth$zone<-13
depth$zone[which(depth$domain=='19_044'|depth$domain=='18_260'|depth$domain=='19_115')]<-11
depth[,6:7]<-LongLatToUTM(depth$lon,depth$lat,depth$zone)[2:3]
depth[which(depth$domain=='19_044'|depth$domain=='18_260'|depth$domain=='19_115'),6:7]<-LongLatToUTM(depth$lon[which(depth$domain=='19_044'|depth$domain=='18_260'|depth$domain=='19_115')],depth$lat[which(depth$domain=='19_044'|depth$domain=='18_260'|depth$domain=='19_115')],11)[2:3]

#compute snow surface and ground surface elevations
depth$z_type<-'g'
depth$z_type[which(is.na(depth$sd))]<-'s'
depth$z_snow<-depth$z
depth$z_snow[which(depth$z_type=='g')]<-depth$z[which(depth$z_type=='g')]+depth$sd[which(depth$z_type=='g')]
depth$z_soil<-depth$z
depth$z_soil[which(depth$z_type=='s')]<-NA

#code location
depth$site<-'RS'
depth$site[which(depth$domain=='19_044'|depth$domain=='18_260'|depth$domain=='19_115')]<-'FM'
depth$site[which(depth$domain=='18_283_SW'|depth$domain=='19_070_SW'|
                   depth$domain=='18_347'|depth$domain=='19_031'|
                   depth$domain=='19_074'|depth$domain=='19_079')]<-'SW'

depth$site[which(depth$domain=='18_283_NE'|depth$domain=='19_070_NE')]<-'NE'

#code snow-free or snow-covered surface type
depth$cond<-'snow'
depth$cond[which(depth$domain=='18_283_NE'|depth$domain=='18_283_SW'|depth$domain=='18_260'|depth$domain=='18_250')]<-'bare'

bare<-c('19_000_SW_a','18_283_NE_a','18_250_RS_a','18_260_FM_a')
sites<-unique(depth$site)
#Initialise dataframe
depth$ldr_z<-NA
depth$sfm_z<-NA
depth$bare_z<-NA
depth$hv<-NA

#quantify number of soil and snow surface elevations obs per site
sum_n<-ddply(depth,c("domain"),summarise,
             n_z=length(which(!is.na(sd))),
             n_sd=length(which(!is.na(z))))

#For loop to extract elevation data from UAV data corresponding to survey point data
#loop per sites
for(i in 1:length(sites)){
  bare_dem<-raster(paste('DSM/',bare[i],'.tif',sep=""))     
  snow_flights<-unique(depth$domain[which(depth$site==sites[i])]) 
  hv<-raster(paste('hv/',bare[i],'.tif',sep=""))  
  #loop per snow cover flights at each sites
  for(j in 1:length(snow_flights)){
    snow_dem_l<-raster(paste('DSM/',substr(snow_flights[j],1,6),"_",sites[i],"_a.tif",sep=""))
    dd<-which(depth$domain==snow_flights[j])
    depth$ldr_z[dd]<-extract(snow_dem_l,SpatialPoints(cbind(depth$X_utm[dd],  depth$Y_utm[dd])))
    depth$bare_z[dd]<-extract(bare_dem,SpatialPoints(cbind(depth$X_utm[dd],  depth$Y_utm[dd])))
    depth$hv[dd]<-extract(hv,SpatialPoints(cbind(depth$X_utm[dd],  depth$Y_utm[dd])))
    if (file.exists(paste('DSM/',substr(snow_flights[j],1,6),"_",sites[i],"_g.tif",sep=""))){
      snow_dem_e<-raster(paste('DSM/',substr(snow_flights[j],1,6),"_",sites[i],"_g.tif",sep=""))
      depth$sfm_z[dd]<-extract(snow_dem_e,SpatialPoints(cbind(depth$X_utm[dd],  depth$Y_utm[dd])))
    }
    if (file.exists(paste('DSM/',substr(snow_flights[j],1,6),"_",sites[i],"_d.tif",sep=""))){
      snow_dem_e<-raster(paste('DSM/',substr(snow_flights[j],1,6),"_",sites[i],"_d.tif",sep=""))
      depth$sfm_z[dd]<-extract(snow_dem_e,SpatialPoints(cbind(depth$X_utm[dd],  depth$Y_utm[dd])))
    }
    rm(snow_l,snow_e,temp_bare,temp_snow,temp_snow_e)
  }
}

#calculate snow depth
depth$sd_ldr<-depth$ldr_z-depth$bare_z
depth$sd_sfm<-depth$sfm_z-depth$bare_z
#reorganise data for long format
#lidar surfaces
snow_z_int<-data.frame(obs=depth$z_snow,
                       est=depth$ldr_z,
                       apprch="UAV-lidar",
                       variable="z",
                       site=depth$site,
                       domain=depth$domain,
                       hv=depth$hv,
                       surf="snow")
bare_z_int<-data.frame(obs=depth$z_soil,
                       est=depth$bare_z,
                       apprch="UAV-lidar",
                       variable="z",
                       site=depth$site,
                       domain=depth$domain,
                       hv=depth$hv,
                       surf="bare")
#ebee surfaces
snow_z_int_e<-data.frame(obs=depth$z_snow,
                         est=depth$sfm_z,
                         apprch="UAV-sfm",
                         variable="z",
                         site=depth$site,
                         domain=depth$domain,
                         hv=depth$hv,
                         surf="snow")
#snow depth surfaces
snow_sd_int<-data.frame(obs=depth$sd,
                        est=depth$sd_ldr,
                        apprch="UAV-lidar",
                        variable="sd",
                        site=depth$site,
                        domain=depth$domain,
                        hv=depth$hv,
                        surf="snow")
snow_sd_int_e<-data.frame(obs=depth$sd,
                          est=depth$sd_sfm,
                          apprch="UAV-sfm",
                          variable="sd",
                          site=depth$site,
                          domain=depth$domain,
                          hv=depth$hv,
                          surf="snow")
all<-rbind(snow_z_int,bare_z_int,snow_z_int_e,snow_sd_int,snow_sd_int_e)
all<-all[which(!(all$site=="NE" &all$apprch=='sfm')),]
temp<-subset(all, variable=="sd"& site!="NE")
temp$site<-as.character(temp$site)
temp$site[which(temp$site=="FM")]<-"Fortress"
temp$site[which(temp$site=="SW")]<-"Prairie"
temp$site[which(temp$site=="RS")]<-"Prairie"
temp$class<-'Open'
temp$class[which(temp$hv>0.5)]<-'Shrub'
temp$class[which(temp$hv>2)]<-'Tree'

#plot observed versus estimated snow depths
p<-ggplot(temp,aes(x=obs,y=est,col=apprch))#,col=apprch,pch=surface))
p<-p+geom_point()+facet_grid(class~site)+theme_bw(base_size=12)+ylab('Estimated Snow Depth (m)')+xlab('Observed Snow Depth (m)')
p<-p+scale_color_discrete(name="Technique")#+theme(axis.ticks = element_blank(), axis.text.y=element_blank())
p<-p+geom_abline(intercept=0,slope=1)
p

summary1<-ddply(temp, c("class", "site","apprch"), summarise, 
                RMSE=RMSE(obs,est),
                Bias=bias(obs,est))
#add stats to plot
summary1$y<-0.2
summary1$y[which(summary1$apprch=="UAV-sfm")]<--0.1
summary1$RMSE<-round(summary1$RMSE,2)
summary1$Bias<-round(summary1$Bias,2)
p<-p + geom_text(data    = summary1,
                 mapping = aes(x = 1.35, y = y, label = sprintf("%0.2f", round(RMSE, digits = 2)),col=apprch),
                 hjust   = -0.1,
                 vjust   = 0,show.legend = FALSE)
p<-p+geom_text(aes(x = 1.35, y = 0.5, label = "RMSE"),col="black",
               hjust   = -0.1,
               vjust   = 0,show.legend = FALSE)
p<-p + geom_text(
  data    = summary1,
  mapping = aes(x = 1.85, y = y, label = Bias,col=apprch),
  hjust   = -0.1,
  vjust   = 0,show.legend = FALSE)
p<-p+geom_text(aes(x = 1.85, y = 0.5, label = "Bias"),col="black",
               hjust   = -0.1,
               vjust   = 0,show.legend = FALSE)
p

ggsave("Figure_5.png",p, width=7,height=6,unit="in",device="png")

#plot RMSE boxplots of surface by site and surface type
temp<-subset(all, variable=="z"& site!="NE")
temp$site<-as.character(temp$site)
temp$site[which(temp$site=="FM")]<-"Fortress"
temp$site[which(temp$site=="SW")]<-"Prairie"
temp$site[which(temp$site=="RS")]<-"Prairie"
temp$class<-'Open'
temp$class[which(temp$hv>0.5)]<-'Shrub'
temp$class[which(temp$hv>2)]<-'Tree'
summary1<-ddply(temp, c("class", "site","apprch","surf","domain"), summarise, 
                RMSE=RMSE(obs,est),
                Bias=bias(obs,est))

summary1$surf<-as.character(summary1$surf)
summary1$surf[which(summary1$surf=="bare")]<-c("ground")

p<-ggplot(summary1,aes(x=surf,y=RMSE,col=apprch))#,col=apprch,pch=surface))
p<-p+geom_boxplot()+facet_grid(class~site)+theme_bw(base_size=12)+ylab('RMSE (m)')+xlab('Surface Type')
p<-p+scale_color_discrete(name="Technique")#+theme(axis.ticks = element_blank(), axis.text.y=element_blank())
p
ggsave("Figure_6.png",p, width=7,height=6,unit="in",device="png")

