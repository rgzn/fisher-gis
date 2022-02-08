#########################################################################
# Only install once then comment required packages out (put # in front) #
#install.packages("sf") #spatial stuff                                  #
#install.packages("tcltk") #OS-independent file/folder selection        #
#install.packages("tidyverse")
#install.packages("hms")
#########################################################################
library(sf)
library(tcltk)
library(dplyr)

#########################################################################
# Select your filetype, tested with shapefile, geopackage, and CSV      #
#########################################################################
filetype <- ".gpkg" # ".gpkg" or ".csv" or ".shp"
setwd(tk_choose.dir(default = getwd(),caption = "Select your working directory (location of .txt files")) # could assign this without interactive selection

# Convert from fisher RF ID to useful ID
# Maybe best to read in from a csv of the master list?
collarid_to_fishid <- function(id) {
  # hold off on making this for now
}

txt_to_gis <- function(filename,num_fish) {
  fish_id <- strsplit(basename(filename)," ")[[1]][2]
  filename <- paste(filename, sep = '', collapse = ' ')
  # Read raw data + error handling for default filename with spaces (default for Lotek downloads)
  rawdata <- trimws(readLines(filename))
  # Dump missing fixes (empty rows)
  i <- 1
  while(i <= length(rawdata)) {
    #You could keep missing fixes if needed by setting null coordinates for them (0,0) and NAs for other columns
    if (grepl("NotEnoughSats", rawdata[i], fixed=TRUE)) {
      rawdata <- rawdata[-i]
      # Use something like this to maintain missed fixes: stri_sub(rawdata[i],49,52) <- "none" repeated at all blank column locations
      i = i - 1
    }
    i = i + 1
  }
  
  # Organize raw text (eliminate extra spaces, separate by text)
  headers <- vector(mode = "list", length = length(rawdata))
  for(i in 1:length(rawdata)) {
    headers[i] <- strsplit(rawdata[i],"[| ]+")
  }
  
  # Create data frame from raw data
  df <- data.frame(matrix(unlist(headers), ncol = max(lengths(headers)), byrow = TRUE))
  
  # Get column headers and indexing column organized properly
  colnames(df) <- df[1, ] # Make column headers from first row of data
  df <- df[-1, ] # Remove first row of data (which were turned into column headers)
  
  # Make a DateTime Column for sick temporal analyses, note raw time is in UTC
  datetimes <- vector()
  for (i in 1:length(df$Index)) {
    datetimes <- append(datetimes,paste(toString(as.Date(df$`RTC-date`[i], format = "%y/%m/%d")), df$`RTC-time`[i]))
  }
  df$Date_Time <- datetimes
  
  # Coerce data types for useful columns, gross looking but good to do so that excel or qgis don't mess things up
  df$Index <- as.integer(df$Index)
  df$Status <- as.character(df$Status)
  df$Sats <- as.character(df$Sats)
  df$`RTC-date` <- as.Date(df$`RTC-date`, "%y/%m/%d")
  df$`RTC-time` <- as.character(df$`RTC-time`) #not sure of best way to store time of day
  df$`FIX-date` <- as.Date(df$`FIX-date`, "%y/%m/%d")
  df$`FIX-time` <- as.character(df$`FIX-time`) 
  df$`Delta(s)` <- as.numeric(df$`Delta(s)`) #not sure of best way to store time of day
  df$Latitude <- as.numeric(df$Latitude)
  df$y <- df$Latitude #Save separate column for lat/long just in case
  df$Longitude <- as.numeric(df$Longitude)
  df$x <- df$Longitude #Save separate column for lat/long just in case
  df$`Altitude(m)` <- as.numeric(df$`Altitude(m)`)
  df$HDOP <- as.numeric(df$HDOP)
  df$eRes <- as.numeric(df$eRes)
  df$`Temperature(C)` <- as.numeric(df$`Temperature(C)`)
  df$`Voltage(V)` <- as.numeric(df$`Voltage(V)`)
  df$Date_Time <- as.POSIXct(df$Date_Time,format="%Y-%m-%d %H:%M:%OS", tz="UTC") # Coerce datetime into proper format
  attr(df$Date_Time, 'tzone', 'America/Los_Angeles') # Convert from UTC to Pacific (handles daylight savings?)
  # Create a column for the individual Fisher ID
  df$Fish_ID[1:length(df$Date_Time)] <- fish_id
  df<- df %>% select(Index,Fish_ID,x,y,Date_Time,everything())
  
  # Convert data frame to a spatial data frame with the selected coordinate system and lat/longs from the points
  crs <- "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
  spatial_df <- st_as_sf(x = df,
                         coords = c("Longitude","Latitude"),
                         crs = crs)
  
  # Convert from lat/long to UTM, comment out if unnecessary
  spatial_df <- st_transform(spatial_df,32611)
  spatial_df$UTM_E <- round(st_coordinates(spatial_df)[,1],0) # Save UTM Easting column rounded to nearest meter
  spatial_df$UTM_N <- round(st_coordinates(spatial_df)[,2],0) # Save UTM Northing column rounded to nearest meter
  spatial_df$Zone[1:length(spatial_df$UTM_N)] <- "11N" # Save UTM Zone column

  # Write the actual file, currently configured to create individual spl files per fisher (Fish_ID) within a singular geopackage (YOSE_FISH)
  # You can play with these options to get many outputs (e.g. singular CSV with all fishers, shapefile with all fishers, etc...)
  st_write(spatial_df,
           dsn = paste(getwd(),"\\","YOSE_FISH",filetype,sep=""),
           layer = paste(fish_id),
           append=TRUE)
}

# Select the raw telemetry text files (totally unchanged/not renamed from PinPointHost's output) for conversion
filechoice <- tk_choose.files(default=getwd(),
                            caption = "Select raw telemetry text files",
                            multi = TRUE,
                            filters = matrix(c(Filters[c("txt"),][1],Filters[c("txt"),][2]),1,2))

# Run the above code for each text file
for (i in 1:length(filechoice)) {
  txt_to_gis(filechoice[i],i)
}

print("All done")