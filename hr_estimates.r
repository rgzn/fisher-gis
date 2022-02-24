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

# Write temporary file for qgis processing
fisher_points %>% 
  st_write(tmp_file, append=FALSE)

# Generate KDE
qgis_run_algorithm(
  "qgis:heatmapkerneldensityestimation",
  INPUT = tmp_file,
  RADIUS = 400,
  KERNEL = 4,
  PIXEL_SIZE=20,
  OUTPUT_VALUE=0,
  OUTPUT = output_file
)


### Plotting ###

mapviewOptions(basemaps = c("OpenTopoMap",
                            "Esri.WorldShadedRelief", 
                            "Esri.WorldImagery"),
               na.color="#BEBEBE00")
# mapviewOptions()

hr_proxy<- read_stars(output_file,proxy=TRUE)
hr_proxy %>% mapview(na.color="#BEBEBE00")

hr <-read_stars(output_file,proxy=FALSE)
quartiles <- hr$kde.tif %>% quantile(probs = seq(0, 1, 0.25), na.rm=TRUE)
quintiles <- hr$kde.tif %>% quantile(probs = seq(0, 1, 0.2), na.rm=TRUE)
deciles <- hr$kde.tif %>% quantile(probs = seq(0, 1, 0.1), na.rm=TRUE)
twentiles <- hr$kde.tif %>% quantile(probs = seq(0, 1, 0.05), na.rm=TRUE)


#isopleths = seq(0.0001,0.001,0.0001)
#isopleths = c(0.0001,0.0008,0.0009,0.001)
isopleths <-
  c( quartiles[3], 
     twentiles[17],
     twentiles[20])

heatPal <- RColorBrewer::brewer.pal(4,"YlOrRd")
opacityPal <- seq(0.4,0.8,0.1)

hr %>% 
  st_contour(contour_lines=FALSE, breaks = isopleths) %>% 
  mutate(idx = dplyr::row_number()) ->
  hr_isopleths
hr_isopleths %>% 
  mutate(fill = heatPal[idx]) %>% 
  mutate(`fill-opacity` = opacityPal[idx]) %>% 
  mutate(class="Shape") %>%
  mutate(name=idx,
         `stroke-opacity` = 1,
         creator="VAFLBF",
         updated= 1.642639e+12,
         `stroke-width`=0) %>% 
  st_transform(4326) %>% 
  st_write("hr2.geojson", append=FALSE)


hr_isopleths%>% 
  mapview(zcol = "idx",
          col.regions = RColorBrewer::brewer.pal(4,"YlOrRd"))


