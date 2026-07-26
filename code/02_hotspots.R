# 02_hotspots.R
# Getis-Ord Gi* hot-spot analysis of untapped housing capacity.
#
# unit_gap is extremely right-skewed at the parcel level (median 1, max
# ~3,200), so running Gi* on raw parcels only rediscovers the mega-parcels.
# Instead, ready capacity (unit_gap on opportunity parcels) is aggregated to
# a hexagonal grid and Gi* runs on the grid: the result reads as corridors
# and neighborhoods rather than individual outlier lots.
# Writes: output/data/hex_hotspots.gpkg

source(here::here("code", "00_setup.R"))

library(sf)
library(dplyr)
library(spdep)

parcels <- st_read(file.path(OUT_DATA, "parcels_scored.gpkg"), quiet = TRUE)

# ---- Hex grid over the urban fabric ------------------------------------
# Cell size is the center-to-center distance in feet (~23 ac hexes at
# 1,000 ft): fine enough to trace corridors, coarse enough to smooth
# single-parcel noise.

eligible <- filter(parcels, housing_eligible)
grid  <- st_make_grid(eligible, cellsize = HEX_CELLSIZE_FT, square = FALSE)
hexes <- st_sf(hex_id = seq_along(grid), geometry = grid)

# Study area = hexes containing at least one housing-eligible parcel.
# Restricting the grid this way keeps empty edge hexes (mountainsides,
# river) from diluting the statistic as artificial zeros.
pts <- st_set_geometry(eligible, st_point_on_surface(st_geometry(eligible)))

hex_join <- st_join(pts, hexes, join = st_within) |> st_drop_geometry()

hex_stats <- hex_join |>
  group_by(hex_id) |>
  summarise(
    parcels_n      = n(),
    ready_units    = sum(unit_gap[is_opportunity]),
    opp_parcels    = sum(is_opportunity),
    existing_units = sum(DwellingUnits),
    noah_units     = sum(DwellingUnits[is_noah])
  )

hexes <- hexes |>
  inner_join(hex_stats, by = "hex_id")   # inner join = study-area hexes only

# ---- Gi* ---------------------------------------------------------------
# Queen contiguity on the hex lattice; include.self() upgrades local G to
# the self-inclusive Gi* form.

nb <- include.self(poly2nb(hexes, queen = TRUE))
lw <- nb2listw(nb, style = "W", zero.policy = TRUE)

# localG is analytic (normal approximation), so no seed is involved.
gi <- localG(hexes$ready_units, lw, zero.policy = TRUE)

hexes <- hexes |>
  mutate(
    gi_z = as.numeric(gi),
    gi_class = factor(
      case_when(
        gi_z >=  2.58 ~ "Hot spot (99% conf.)",
        gi_z >=  1.96 ~ "Hot spot (95% conf.)",
        gi_z >=  1.65 ~ "Hot spot (90% conf.)",
        gi_z <= -1.65 ~ "Cold spot",
        TRUE          ~ "Not significant"
      ),
      levels = c("Hot spot (99% conf.)", "Hot spot (95% conf.)",
                 "Hot spot (90% conf.)", "Not significant", "Cold spot")
    )
  )

st_write(hexes, file.path(OUT_DATA, "hex_hotspots.gpkg"),
         layer = "hexes", delete_dsn = TRUE, quiet = TRUE)

# ---- Affordability exposure --------------------------------------------
# How much of the existing low-cost (NOAH) stock sits inside or directly
# adjacent to the capacity clusters — the parcels most exposed if the
# clusters redevelop. "Adjacent" = a hex touching a 95%+ hot-spot hex.

hot95 <- filter(hexes, gi_z >= 1.96)
touch <- st_intersects(hexes, hot95)
hexes$near_hotspot <- lengths(touch) > 0

exposure <- tibble::tibble(
  stat = c("hot_hexes_95", "ready_units_hot_95", "noah_units_total_hexed",
           "noah_units_in_hot_95", "noah_units_in_or_adjacent_hot_95"),
  value = c(nrow(hot95),
            sum(hot95$ready_units),
            sum(hexes$noah_units),
            sum(hexes$noah_units[hexes$gi_z >= 1.96]),
            sum(hexes$noah_units[hexes$near_hotspot]))
)
readr::write_csv(exposure, file.path(OUT_DATA, "hotspot_stats.csv"))

hot <- st_drop_geometry(hot95)
message("02_hotspots: ", nrow(hexes), " hexes; ", nrow(hot),
        " hot at 95%+, holding ", round(sum(hot$ready_units)),
        " of ", round(sum(hexes$ready_units)), " ready units; NOAH units in/adjacent: ",
        sum(hexes$noah_units[hexes$near_hotspot]), " of ", sum(hexes$noah_units), ".")
