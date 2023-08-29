pacman::p_load(lubridate, 
               tidyverse,
               xts,
               ggplot2,
               sf)

# to import climate_data.csv without running the first code chunk, use the following code:
# climate_data_clean <- read.csv("outputs/climate_data.csv")
# climate_data_clean <- climate_data_clean %>% 
#  st_as_sf(coords = c("longitude", "latitude"), remove=FALSE) %>% 
#  st_set_crs(4326) %>%
#  mutate(id = as.factor(id), 
#         name = as.factor(name),
#         date = as.POSIXct(date, format = "%Y-%m-%d"))

### Create time series object of observed daily mean temperatures ####

# calculate observed daily mean temperature (TAVG) from TMAX and TMIN values

climate_data_clean <- climate_data_clean %>% mutate(TAVG = (TMAX + TMIN) / 2)

climate_data_clean %>% select(TMAX, TMIN, TAVG) %>% print(n = 50)


# create separate df for the new variable TAVG

TAVG_daily <- climate_data_clean %>% as.data.frame() %>% 
  select(id, date, TAVG)


# split the daily TAVG data frame into a list of separate data frames for each weather station id

TAVG_list <- split(TAVG_daily, TAVG_daily$id)

# convert each data frame to xts object

TAVG_xts_list <- lapply(TAVG_list, function(x) xts(x$TAVG, order.by = x$date))


# merge the xts objects in xts_list into a single multivariate xts object

multivariate_TAVG_xts <- do.call(merge, TAVG_xts_list)


### Dealing with NAs in data ####

# Count NAs in each variable
na_counts <- colSums(is.na(multivariate_TAVG_xts))

# Print the NA counts
print(na_counts) 

# aggregate daily TAVG values to yearly average TAVG 

multivariate_TAVG_xts_monthly <- apply.monthly(multivariate_TAVG_xts, mean, na.rm = TRUE) %>% window(end = "2022-12-31") # this function calculates mean values for each month disregarding NAs in the data

na_counts <- colSums(is.na(multivariate_TAVG_xts_monthly))
print(na_counts)


multivariate_TAVG_xts_quarterly <- apply.quarterly(multivariate_TAVG_xts_monthly, mean)

na_counts <- colSums(is.na(multivariate_TAVG_xts_quarterly))
print(na_counts)


multivariate_TAVG_xts_yearly <- apply.yearly(multivariate_TAVG_xts_quarterly, mean)

na_counts <- colSums(is.na(multivariate_TAVG_xts_yearly))
print(na_counts)

#this code aggregates to monthly, quaterly, and then yearly values ignoring NAs in each step to ensure large number of NAs don't skew the data

#deal with remaining NAs
multivariate_TAVG_xts_yearly <- multivariate_TAVG_xts_yearly %>% na.locf()

na_counts <- colSums(is.na(multivariate_TAVG_xts_yearly))
print(na_counts)#no NAs remain in the data

## Create df of temperature anomaly values ####

# calculate temperature anomaly values relative to the 1983-2022 mean for each station
anomaly_TAVG_yearly <- scale(multivariate_TAVG_xts_yearly, scale = FALSE)



# convert multivariate xts back to data frame

df_anomaly <- as.data.frame(anomaly_TAVG_yearly)


# Convert row names to a new column called 'year'

df_anomaly <- df_anomaly %>% rownames_to_column(var = 'year')%>% 
  mutate(year = year(ymd(date)))


# Convert the data frame to long format, rounding values to 2 decimals

df_anomaly_long <- df_anomaly %>%
  pivot_longer(cols = -date, names_to = 'id', values_to = 'TAVG') %>%
  mutate(TAVG = round(TAVG, 2))

#associate latitude and longitude values with data points

anomaly_ready <- inner_join(new_station_selection, 
                            df_anomaly_long, by = "id") %>% 
  mutate(id = as.factor(id), 
         name = as.factor(name), 
         .keep = "unused")

# change names to sentence case and arrange in alphabetical order for visualisation

anomaly_ready <- anomaly_ready[order(anomaly_ready$name), ] %>% mutate(name = str_to_title(name))

# export cleaned dataset

save(anomaly_ready, file = "outputs/anomaly_ready.RData")
