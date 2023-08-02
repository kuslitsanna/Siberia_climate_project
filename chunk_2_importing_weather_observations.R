pacman::p_load(bigrquery,
               dplyr,
               leaflet, 
               htmlwidgets,
               sf,
               ggplot2)

# to import selected_stations without running the first code chunk, use the following code:

# selected_stations <- read.csv("outputs/selected_stations.csv")

# selected_stations %<>% 
#   st_as_sf(coords = c("longitude", "latitude"), remove=FALSE) %>% 
#   st_set_crs(4326) %>% 
#   mutate(id = as.factor(id), name = as.factor(name))


# selected_stations.csv can be downloaded from project repo/outputs


## Importing GHCN weather observations from BigQuery #####

arg1 <- c(1983:2023) %>% as.data.frame() # replace with desired time frame
arg2 <- selected_stations$id %>% as.data.frame()
data_tibble <- cross_join(arg1, arg2) %>% rename(arg1=..x, arg2=..y)

# prepare object to store query results
output_list <- list()

# here I have broken down the task into smaller chunks to monitor data usage
# this query ran for approximately 2 hrs on my pc

for(i in 1:200) {     # replace with 'for(i in seq(nrow(data_tibble)))' to run entire process in one go
  arg1 <- data_tibble$arg1[i]
  arg2 <- data_tibble$arg2[i]
  query <- paste("SELECT id, date, element, value
                 FROM bigquery-public-data.ghcn_d.ghcnd_",arg1,
                 " WHERE id='",arg2,
                 "' AND (element = 'TMAX' OR element='TMIN' OR element = 'PRCP' OR element = 'SNWD')", sep = "")
  output <- bq_project_query(projectid, query) %>% bq_table_download()
  output_list[[i]] <- output
  print(paste("Loop", i, "finished" ))
}

print(object.size(output_list))





for(i in 201:1000) {
  arg1 <- data_tibble$arg1[i]
  arg2 <- data_tibble$arg2[i]
  query <- paste("SELECT id, date, element, value
                 FROM bigquery-public-data.ghcn_d.ghcnd_",arg1,
                 " WHERE id='",arg2,
                 "' AND (element = 'TMAX' OR element='TMIN' OR element = 'PRCP' OR element = 'SNWD')", sep = "")
  output <- bq_project_query(projectid, query) %>% bq_table_download()
  output_list[[i]] <- output
  print(paste("Loop", i, "finished" ))
}

print(object.size(output_list))



for(i in 1001:4305) {
  arg1 <- data_tibble$arg1[i]
  arg2 <- data_tibble$arg2[i]
  query <- paste("SELECT id, date, element, value
                 FROM bigquery-public-data.ghcn_d.ghcnd_",arg1,
                 " WHERE id='",arg2,
                 "' AND (element = 'TMAX' OR element='TMIN' OR element = 'PRCP' OR element = 'SNWD')", sep = "")
  output <- bq_project_query(projectid, query) %>% bq_table_download()
  output_list[[i]] <- output
  print(paste("Loop", i, "finished" ))
}
  
print(object.size(output_list)) #final output size 124 MB


## Widen dataframe ####

# transform list into single data frame
output_df <- bind_rows(output_list)

# adjust variable types

output_df <- output_df %>% mutate(
  id = as.factor(id),
  element = as.factor(element),
  date = as.POSIXct(date, tz="UTC", "%Y-%m-%d")) 

# widen dataframe

df_wide <- output_df %>% spread(key = element, value = value) %>% arrange(date) %>% group_by(id)



## Filter downloaded data for stations with the highest number of observations (least NAs) ####

# count valid observations in dataset by station id

obs_counts <- df_wide %>%
  summarise(
    TMAX_valid_count = sum(!is.na(TMAX)),
    TMIN_valid_count = sum(!is.na(TMIN)),
    PRCP_valid_count = sum(!is.na(PRCP)),
    SNWD_valid_count = sum(!is.na(SNWD)),
    total_valid_count = sum(!is.na(TMAX), !is.na(TMIN), !is.na(PRCP), !is.na(SNWD))
  ) %>% 
  as.data.frame %>% 
  arrange(desc(total_valid_count))

print(obs_counts)

plot(obs_counts$total_valid_count) # sharp drop in valid count around 25,000 and 40,000 observations

# exclude stations with lowest numbers of valid observations
excluded_ids <- obs_counts %>% filter(total_valid_count<40000) %>%
  dplyr::select(id)

# check results
unique(excluded_ids$id)

# create negative join with selected stations
valid_stations <- anti_join(selected_stations, excluded_ids, by="id") # 52 remaining stations

# visualise location of new selection
basemap %>% addCircleMarkers(data=valid_stations, radius=1)

# filter remaining stations by proximity, min. distance: 600 km
new_station_selection <- filterByProximity(valid_stations, dist=600, returnIndex=FALSE) # 23 remaining stations

# view new selection

basemap %>% addCircleMarkers(data=new_station_selection, radius=1)



# print map of new station selection and add labels displaying name, long, lat 
map_stations_23 <- basemap %>%
  addMarkers(data = new_station_selection, 
             label = paste(new_station_selection$name, 
                           new_station_selection$id, 
                           "Long:", new_station_selection$longitude, 
                           "Lat:", new_station_selection$latitude, 
                           sep = " ")
             )

map_stations_23


# save map as an HTML file to retain interactive features
saveWidget(map_stations_23,
           file.path(output_folder, 
                     "23_selected_stations_interactive_map.html")
           )



## Filter imported weather data for new selection of stations #####


# create join with new selection of stations and weather observations

climate_data <- inner_join(new_station_selection, df_wide, by="id") 

#drop levels in factor variables

climate_data$id <- droplevels(climate_data$id)
climate_data$name <- droplevels(climate_data$name)




## Clean data ######


# adjust units of measurement (the GHCN dataset records PRCP in tenth of mm; TMAX and TMIN in tenth of degrees c)

climate_data <- climate_data %>% 
  mutate(PRCP = PRCP/10, 
         TMAX = TMAX/10, 
         TMIN = TMIN/10)



### Investigate outliers in variable PRCP #######

ggplot(climate_data, aes(name, PRCP, colour=name)) + geom_jitter()

# investigate daily PRCP values over 90 mm

climate_data %>% 
  filter(PRCP>90) %>% 
  arrange(id) %>% 
  print(n=200) # values coming up as 99.1 and 99.3 have been flagged as values that failed one of NCEI's quality control tests

# replace erroneous values with NA

climate_data <- climate_data %>% 
  mutate(PRCP=ifelse(PRCP==99.1, NA, PRCP)) %>% 
  mutate(PRCP=ifelse(PRCP==99.3, NA, PRCP))


# 5 outliers >150 seem correct but should be brought in to level out distribution of data

climate_data <- climate_data %>% 
  mutate(PRCP=ifelse(PRCP>150, 150, PRCP))

# check results

ggplot(climate_data, aes(name, PRCP, colour=name)) + geom_jitter()

climate_data %>% 
  filter(PRCP>90) %>% 
  arrange(id) %>% 
  print(n=200)


### Investigate outliers in variable TMAX #######


ggplot(climate_data, aes(name, TMAX, colour=name)) + geom_boxplot()

# investigate TMAX values below -50 degrees Celsius
climate_data %>% 
  filter(TMAX< -50) %>% 
  arrange(id) %>% 
  select(id, name, date, TMAX) %>% 
  print(n=200) # low extremes seem accurate

# investigate outliers above 38 degrees Celsius

climate_data %>% 
  filter(TMAX>38) %>% 
  arrange(id) %>% 
  select(id, name, date, TMAX) %>% 
  print(n=200) # 4 observations in TMAX appear erroneous 

# replace erroneous values with NA

climate_data$TMAX[climate_data$id == "RSM00023662" & climate_data$TMAX == 39.7] <- NA
climate_data$TMAX[climate_data$id == "RSM00023933" & climate_data$TMAX == 40.1] <- NA
climate_data$TMAX[climate_data$id == "RSM00024959" & climate_data$TMAX == 38.4] <- NA
climate_data$TMAX[climate_data$id == "RSM00031371" & climate_data$TMAX == 51.2] <- NA

# check results

ggplot(climate_data, aes(name, TMAX, colour=name)) + geom_boxplot()

climate_data %>% 
  filter(TMAX>38) %>% 
  arrange(id) %>% 
  select(id, name, date, TMAX) %>% 
  print(n=200) 


### Investigate outliers in TMIN #######

ggplot(climate_data, aes(name, TMIN, colour=name)) + geom_boxplot()

climate_data %>% 
  filter(TMIN< -55) %>% 
  arrange(id) %>% 
  select(id,name,date,TMIN) %>% 
  print(n=200) 



### Investigate outliers in SNWD #######

ggplot(climate_data, aes(name, SNWD)) + geom_boxplot() + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# investigate SNWD values over 1500 mm

climate_data %>% 
  filter(SNWD>1500) %>% 
  arrange(id) %>% 
  select(id, name, date, SNWD, TMAX) %>% 
  print(n=200) # these outliers have been flagged as values that failed one of NCEI's quality control tests

# investigate SNWD values above 1000 mm where TMIN is above 0 degrees Celsius

climate_data %>% 
  filter(SNWD>1000 & TMIN > 0) %>% 
  arrange(id) %>% 
  select(id, name, date, SNWD, TMIN) %>% 
  print(n=200) # these outliers have also been flagged

# replace suspect outliers with NA

climate_data <- climate_data %>% 
  mutate(SNWD = ifelse(SNWD > 1500, NA, SNWD)) %>% 
  mutate(SNWD = ifelse(SNWD > 1000 & TMIN > 0, NA, SNWD))

# check results

ggplot(climate_data, aes(name, SNWD)) + 
  geom_boxplot() + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# investigate outliers further

# create separate data frame with a new "Month" variable
climate_data_check <- climate_data %>%
  mutate(Month = format(date, "%m"))  


ggplot(climate_data_check, aes(x = Month, y = SNWD)) +
  geom_boxplot() # the plot shows distribution of SNWD values by month of the year

# print suspect outliers 

climate_data_check %>% 
  filter(Month == "08" & SNWD > 250 | 
           Month == "09" & SNWD >250 |
           Month == "10" & SNWD > 700 | 
           Month == "11" & SNWD > 1200) %>% 
  arrange(latitude) %>%
  select(id,name, date, SNWD) %>% 
  print(n=200)

# replace identified suspect outliers with NA

SNWD_error <- climate_data_check %>% 
  filter(Month == "08" & SNWD > 250 | 
           Month == "09" & SNWD >250 | 
           Month == "10" & SNWD > 700 | 
           Month == "11" & SNWD > 1200) %>% 
  mutate(SNWD = NA) %>% 
  rename(SNWD_NA = SNWD) %>% 
  as.tibble() %>% 
  select(id, date, SNWD_NA) 

climate_data_clean <- full_join(climate_data, SNWD_error, 
                                by = c("id", "date")) %>%  
  mutate(SNWD = coalesce(SNWD_NA, SNWD)) %>%
  select(-SNWD_NA)

# check results

ggplot(climate_data_clean, aes(name, SNWD)) + 
  geom_boxplot() + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

tail(climate_data_clean$date)


### Add comments to clean data frame ######


comment(climate_data_clean) <- c("This dataframe contains 4 core elements from the GHCN daily dataset from 1983-01-01 to 2023-07-23 for 23 selected weather stations in the Siberia region, located at a minimum distance of 600 km apart.", "Source: Menne, M.J., I. Durre, B. Korzeniewski, S. McNeill, K. Thomas, X. Yin, S. Anthony, R. Ray, 
R.S. Vose, B.E.Gleason, and T.G. Houston, 2012: Global Historical Climatology Network - 
Daily (GHCN-Daily), Version 3.30. 
NOAA National Climatic Data Center.")

comment(climate_data_clean$PRCP) <- c("Precipitation in millimetres")
comment(climate_data_clean$TMAX) <- c("Maximum temperature in degrees Celsius")
comment(climate_data_clean$TMIN) <- c("Minimum temperature in degrees Celsius")
comment(climate_data_clean$SNWD) <- c("Snow depth in millimetres")


## Export filtered dataset #######

climate_data_export <- climate_data_clean %>%
  as_tibble %>%
  select(id, name, longitude, latitude, date, PRCP, TMAX, TMIN, SNWD)


write.csv(climate_data_export, row.names = FALSE, file.path(output_folder, "climate_data.csv")) 


## Clear environment  ####

# create safety backup

save.image(file = "backup_workspace_chunk_2.RData")

# remove everything except needed objects 

rm(list=setdiff(ls(),c("basemap",
                       "climate_data_clean", 
                       "map_stations_23", 
                       "new_station_selection",
                       "output_folder")))

cat("\014")  
