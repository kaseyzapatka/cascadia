# 04_interactive.R
# Self-contained Leaflet map for the website: hex capacity clusters over a
# light basemap, with the opportunity parcels as a toggleable layer.
# Writes: output/maps/hotspot_map.html (embedded on the map.qmd page)

source(here::here("code", "00_setup.R"))

library(sf)
library(dplyr)
library(leaflet)
library(htmlwidgets)

dir.create(here::here("output", "maps"), recursive = TRUE, showWarnings = FALSE)

hexes   <- st_read(file.path(OUT_DATA, "hex_hotspots.gpkg"),   quiet = TRUE)
parcels <- st_read(file.path(OUT_DATA, "parcels_scored.gpkg"), quiet = TRUE)

# Leaflet wants WGS84. Simplify parcel outlines (~10 ft tolerance) to keep
# the self-contained HTML light enough to embed.
hexes_ll <- st_transform(hexes, 4326)
opp_ll <- parcels |>
  filter(is_opportunity) |>
  st_simplify(dTolerance = 10) |>
  st_transform(4326) |>
  mutate(
    popup = sprintf(
      "<b>%s</b><br/>Future land use: %s<br/>Acres: %.2f<br/>Existing units: %d<br/>Plan-enabled units: %.0f",
      LandUseBuildingType_All, Land_Use, Acres, DwellingUnits, unit_gap
    )
  )

# Brand palette (see 03_figures.R); hot classes stepped green, gray neutral.
PAL_GI <- c(
  "Hot spot (99% conf.)" = "#4c5813",
  "Hot spot (95% conf.)" = "#8b9c26",
  "Hot spot (90% conf.)" = "#c9d465",
  "Not significant"      = "#e8e6e1",
  "Cold spot"            = "#7096c0"
)
LBL_GI <- c("Very strong cluster (99% confidence)",
            "Strong cluster (95% confidence)",
            "Moderate cluster (90% confidence)",
            "No significant clustering",
            "Cluster of low capacity")
hexes_ll$col <- unname(PAL_GI[as.character(hexes_ll$gi_class)])

map <- leaflet(options = leafletOptions(minZoom = 11)) |>
  addProviderTiles(providers$CartoDB.Positron) |>
  addPolygons(
    data = hexes_ll, group = "Capacity clusters (Gi*)",
    fillColor = ~col, fillOpacity = 0.55, color = "#ffffff", weight = 0.5,
    label = ~sprintf("%.0f plan-enabled units (%s)", ready_units, gi_class)
  ) |>
  addPolygons(
    data = opp_ll, group = "Opportunity parcels",
    fillColor = "#7096c0", fillOpacity = 0.5, color = "#7096c0", weight = 0.5,
    popup = ~popup
  ) |>
  addLegend(
    position = "bottomright",
    title = "Clustering of untapped capacity<br/><span style='font-weight:normal;font-size:11px'>confidence the concentration is not random (Gi*)</span>",
    colors = unname(PAL_GI[names(PAL_GI) %in% unique(as.character(hexes_ll$gi_class))]),
    labels = LBL_GI[names(PAL_GI) %in% unique(as.character(hexes_ll$gi_class))]
  ) |>
  addLayersControl(
    overlayGroups = c("Capacity clusters (Gi*)", "Opportunity parcels"),
    options = layersControlOptions(collapsed = FALSE)
  ) |>
  hideGroup("Opportunity parcels")

saveWidget(map, here::here("output", "maps", "hotspot_map.html"),
           selfcontained = TRUE, title = "Missoula untapped housing capacity")

message("04_interactive: wrote output/maps/hotspot_map.html")
