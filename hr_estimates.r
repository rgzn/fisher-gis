library(tidyverse)
library(sf)
# library(atlastools)   # possible track processing library
# library(amt)
library(btb)  # kernel smoothing?
library(stars)
library(mapview)

proj_crs <- 32611

# Load functions from QGIS
library(qgisprocess)
qgis_configure() 

# Establish YNP boundary for data filtering
st_read("NPS_-_Land_Resources_Division_Boundary_and_Tract_Data_Service.geojson") %>%
  filter(PARKNAME == "Yosemite") %>% 
  st_transform(proj_crs) %>%
  st_buffer(10000) ->
  ynp_buffer

# Bounding box of buffer
ynp_buffer %>% 
  st_bbox ->
  ynp_bbox

# I/O files
fisher_file = "YOSE_FISH.gpkg"
output_file = "kde.tif"
tmp_file = "tmp_input_file.gpkg"

# Read data
st_read(fisher_file) -> fisher_points

# Filter data to only within YNP buffer
fisher_points %>%
  st_crop(ynp_bbox) ->
  fisher_points

fisher_points %>% 
  st_write(tmp_file, append=FALSE)


qgis_run_algorithm(
  "qgis:heatmapkerneldensityestimation",
  INPUT = tmp_file,
  RADIUS = 400,
  KERNEL = 4,
  PIXEL_SIZE=20,
  OUTPUT = output_file
)


mapviewOptions(basemaps = c("OpenTopoMap",
                            "Esri.WorldShadedRelief", 
                            "Esri.WorldImagery"),
               na.color="#BEBEBE00")
mapviewOptions()



hr_proxy<- read_stars(output_file,proxy=TRUE)
hr_proxy %>% mapview(na.color="#BEBEBE00")

hr <-read_stars(output_file,proxy=FALSE)
hr %>% 
  st_contour(contour_lines=FALSE, breaks = c(20,60,100)) %>% 
  mapview(zcol = "Max",
          at=c(10,30, 80,110))
