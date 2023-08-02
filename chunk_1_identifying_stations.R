pacman::p_load(bigrquery,
               rangeBuilder,
               sf,
               tidyverse,
               leaflet, 
               htmlwidgets)




## Read in shapefile of Siberia #####

siberia_shape <- read_sf("Siberia_shape.kml") # simple shapefile, rough approximation created in Google Earth and available in project repo




## Import data from BigQuery #####

# extract latitude and longitude range from spatial object

bbox <- st_bbox(siberia_shape)

print(bbox) #the returned xmin, xmax, ymin and ymax values are fed into the query below

# query GHCN weather stations dataset stored in BigQuery

projectid <- "ace-cycling-389416" # replace with your ID

sql <- "SELECT id, name, latitude, longitude 
        FROM `bigquery-public-data.ghcn_d.ghcnd_stations` 
        WHERE longitude BETWEEN 50 and 192 
        AND latitude BETWEEN 41 and 83" # this query returns a list of weather station data located within the specified coordinates


unfiltered_stations <- bq_project_query(projectid, sql) %>%
  bq_table_download() # query returns 1267 weather stations 





## Clean and filter dataset ####

# convert latitude and longitude into sf points
unfiltered_stations %<>%
  st_as_sf(coords = c("longitude", "latitude"), remove=FALSE) %>%
  st_set_crs(4326)


# filter stations to those located within the Siberia shapefile
filtered_stations <- unfiltered_stations %>% 
  st_intersection(siberia_shape$geometry) # 667 stations

# visualise location of filtered stations in viewer
basemap <- leaflet() %>% addTiles()

basemap %>% addCircleMarkers(data=filtered_stations, radius=1)

# reduce number of stations to those located at a minimum distance of 300 km apart
selected_stations <- filterByProximity(filtered_stations, 
                                       dist=300, 
                                       returnIndex=FALSE) # 105 stations selected

# visualise location of selected stations
basemap %>% addCircleMarkers(data=selected_stations, radius=1)

# adjust variable types
selected_stations <- selected_stations %>% 
  mutate(id = as.factor(id), name = as.factor(name))

# add comment

comment(selected_stations) <- c("This dataframe contains the names, IDs, and coordinates of 105 selected weather stations in the Siberia region, located at a minimum distance of 300 km apart.", "Source: Menne, M.J., I. Durre, B. Korzeniewski, S. McNeill, K. Thomas, X. Yin, S. Anthony, R. Ray, 
R.S. Vose, B.E.Gleason, and T.G. Houston, 2012: Global Historical Climatology Network - 
Daily (GHCN-Daily), Version 3.30. 
NOAA National Climatic Data Center.")




## Export outputs ####

# create a directory named 'outputs' in the working directory 
output_folder <- file.path(getwd(), "outputs")

dir.create(output_folder, showWarnings = FALSE)

# export selected_stations object to CSV file

selected_stations_export <- selected_stations %>% 
  as.tibble() %>% 
  select(id, name, longitude, latitude)


write.csv(selected_stations_export, 
          row.names = FALSE, 
          file.path(output_folder, "selected_stations.csv")) 


# print map of selected station locations with labels displaying name, long, lat 
map_stations <- basemap %>%
  addMarkers(data = selected_stations, 
             label = paste(selected_stations$name,
                           selected_stations$id, 
                           "Long:", selected_stations$longitude, 
                           "Lat:", selected_stations$latitude, 
                           sep = " "))

map_stations

# save map as an HTML file to retain interactive features
saveWidget(map_stations,
           file.path(output_folder, "interactive_map_selected_stations.html"))




## Clear environment ######

# create safety backup

save.image(file = "backup_workspace_chunk_1.RData")

# clear workspace

rm(filtered_stations, unfiltered_stations, siberia_shape, bbox, sql)

cat("\014")  

