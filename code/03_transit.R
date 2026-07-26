# 03_transit.R
# Transit accessibility of the plan-enabled capacity: what share of ready
# units sits within a quarter-mile walkshed of a Mountain Line bus stop?
# Uses the agency's published GTFS feed (data/external/mountainline_gtfs.zip;
# re-downloaded from mountainline.com/about/data-portal/ if absent).
# Writes: output/data/transit_stats.csv, output/data/transit.gpkg
#         (walkshed + route shapes, for the maps)

source(here::here("code", "00_setup.R"))

library(sf)
library(dplyr)
library(readr)

GTFS_ZIP <- here::here("data", "external", "mountainline_gtfs.zip")
GTFS_URL <- "https://www.mountainline.com/files/MUTD_GTFS.zip"
if (!file.exists(GTFS_ZIP)) {
  dir.create(dirname(GTFS_ZIP), recursive = TRUE, showWarnings = FALSE)
  download.file(GTFS_URL, GTFS_ZIP, mode = "wb", quiet = TRUE)
}

tmp <- tempfile()
dir.create(tmp)
unzip(GTFS_ZIP, exdir = tmp)

# ---- Stops -> quarter-mile walkshed ------------------------------------
# 1,320 ft Euclidean buffer: the standard walkshed shorthand. It slightly
# overstates true network walking distance — disclosed in methods.

stops <- read_csv(file.path(tmp, "stops.txt"), show_col_types = FALSE) |>
  st_as_sf(coords = c("stop_lon", "stop_lat"), crs = 4326) |>
  st_transform(CRS_PLANE)

walkshed <- stops |>
  st_buffer(WALKSHED_FT) |>
  st_union() |>
  st_sf(geometry = _)

# ---- Route shapes (for cartography) ------------------------------------

shapes <- read_csv(file.path(tmp, "shapes.txt"), show_col_types = FALSE) |>
  arrange(shape_id, shape_pt_sequence) |>
  group_by(shape_id) |>
  summarise(geometry = st_sfc(st_linestring(
    cbind(shape_pt_lon, shape_pt_lat)), crs = 4326), .groups = "drop") |>
  st_as_sf() |>
  st_transform(CRS_PLANE) |>
  st_union() |>
  st_sf(geometry = _)

# ---- Share of capacity within the walkshed -----------------------------

parcels <- st_read(file.path(OUT_DATA, "parcels_scored.gpkg"), quiet = TRUE)
opp <- filter(parcels, is_opportunity)
opp$near_transit <- lengths(st_intersects(opp, walkshed)) > 0

transit_stats <- tibble(
  stat = c("stops_n",
           "opportunity_parcels_near_transit",
           "ready_units_near_transit",
           "ready_units_total",
           "share_ready_units_near_transit"),
  value = c(nrow(stops),
            sum(opp$near_transit),
            sum(opp$unit_gap[opp$near_transit]),
            sum(opp$unit_gap),
            sum(opp$unit_gap[opp$near_transit]) / sum(opp$unit_gap))
)
write_csv(transit_stats, file.path(OUT_DATA, "transit_stats.csv"))

st_write(walkshed, file.path(OUT_DATA, "transit.gpkg"),
         layer = "walkshed", delete_dsn = TRUE, quiet = TRUE)
st_write(shapes, file.path(OUT_DATA, "transit.gpkg"),
         layer = "routes", append = TRUE, quiet = TRUE)

message("03_transit: ", nrow(stops), " stops; ",
        round(100 * transit_stats$value[5], 1),
        "% of ready units within a quarter mile of a stop.")
