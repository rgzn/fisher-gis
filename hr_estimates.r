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

ynp_buffer %>% 
  st_bbox ->
  ynp_bbox




fisher_file = "YOSE_FISH.gpkg"
output_file = "kde.tif"
tmp_file = "tmp_input_file.gpkg"

st_read(fisher_file) -> fisher_points

# Filter data to only within YNP buffer
fisher_points %>%
  st_crop(ynp_bbox) ->
  fisher_points

fisher_points %>% 
  st_write(tmp_file, append=FALSE)

# crs <- st_crs(fisher_points) # 32611

qgis_run_algorithm(
  "qgis:heatmapkerneldensityestimation",
  INPUT = tmp_file,
  RADIUS = 400,
  KERNEL = 4,
  PIXEL_SIZE=20,
  OUTPUT = output_file
)


# fisher_points %>% 
#   st_coordinates() %>% 
#   as_tibble %>% 
#   rename(x=X,y=Y) %>% 
#   mutate(Index = fisher_points$Index) ->
#   fisher_xy
# 
# fisher_xy %>% 
#   btb::kernelSmoothing(sEPSG = "32611",
#                        iCellSize = 100L,
#                        iBandwidth = 300L,
#                        vQuantiles = c(0.1,0.5,0.90)) %>% 
#   st_as_sf ->
#   fisher_hr
# 
# 
# fisher_hr %>% 
#   st_transform(4326) %>% 
#   st_crop(xmin=-120,xmax=-118,ymin=37,ymax=38) %>%
#   ggplot() +
#   +     geom_sf(aes(fill = nbObs), col = NA)

## Plotting ##

mapviewOptions(basemaps = c("OpenTopoMap",
                            "Esri.WorldShadedRelief", 
                            "Esri.WorldImagery"))

# fisher_hr %>% 
#   st_transform(4326) %>%
#   st_crop(xmin=-120,xmax=-118,ymin=37,ymax=38) %>% 
#   mapview(zcol="nbObs",
#           alpha=0)


hr <- read_stars(output_file,proxy=TRUE)
hr %>% mapview(na.color="#BEBEBE00")
