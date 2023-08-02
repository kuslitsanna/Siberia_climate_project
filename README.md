# Siberia_climate_project

-   **Problem:** The effects of global climate change have been particularly severe in the Siberia region of North Asia. Frequent and intense heat waves in recent years are resulting in the rapid melting of permafrost, causing significant transformations in the region's landscape. The warming climate is creating shifts in precipitation patterns, affecting water resources and impacting ecosystems and human activities. As the release of greenhouse gases from thawing permafrost contributes to further climate change, these changes have important global implications.

-   **Objective:** This project used historical daily weather-station observations from the Global Historical Climatology Network - Daily (GHCN-Daily) dataset hosted in [BigQuery](https://cloud.google.com/blog/products/gcp/global-historical-daily-weather-data-now-available-in-bigquery) to analyse and visualise trends in the data, and forecast potential future climate states in the Siberia region.

-   **Scope:**

The analysis looked at 4 core elements in the GHCN dataset:

|      |                                         |
|------|-----------------------------------------|
| TMAX | maximum daily temperature in degrees C  |
| TMIN | minimum daily temperature in degrees C  |
| PRCP | daily precipitation in millimetres      |
| SNWD | daily snow depth in millimetres         |

Examined period: 1983-01-01 to 2023-07-01

- **Contents:**

[chunk_1_identifying_stations.R](chunk_1_identifying_stations.R) - This code imports weather station metadata from the GHCN datasets on BigQuery (bigquery-public-data.ghcn_d.ghcnd_stations) and filters the data using a shapefile of the Siberia region [(Siberia_shape.kml)](Siberia_shape.kml). The remaining stations are then narrowed down based on proximity, imposing a minimum distance of 300 km from each other. The final selection includes 105 Siberian weather stations, visualized on an interactive map [(interactive_map_selected_stations.html)](outputs/interactive_map_selected_stations.html). The metadata of the selected stations is exported to a CSV file [(selected_stations.csv)](outputs/selected_stations.csv).

[chunk_2_importing_weather_observations.R](chunk_2_importing_weather_observations.R) - This code imports weather data (PRCP, TMAX, TMIN, SNWD) from the GHCN datasets on BigQuery for the period 1983-01-01 to 2023-07-23, observed at 105 weather stations in Siberia. The data is then filtered to retain 23 stations with the highest number of valid observations, each located at a minimum distance of 600 km from one another. Outliers are detected and removed as necessary. The cleaned dataset is exported to a CSV file [(climate_data.csv)](outputs/climate_data.csv), and the new selection of 23 examined weather stations is visualized on an interactive map [(23_selected_stations_interactive_map.html)](outputs/23_selected_stations_interactive_map.html).

-  **Disclaimer:**
  
This project was created as part of a data skills course and serves as a demonstration of working with the GHCN (Global Historical Climatology Network) dataset. I am not a climate scientist, and the analyses presented here are for educational purposes only. The results and interpretations should not be considered authoritative. For accurate and reliable climate information, please refer to official sources and consult with qualified climate scientists.


