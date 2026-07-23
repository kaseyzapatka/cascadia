# 01_clean_derive.R
# Read the Missoula taxlot layer, clean known data quirks, and derive the
# parcel-level metrics the story rests on:
#   * improvement-to-land ratio (ILR)
#   * environmental constraint share (floodway / steep slope)
#   * plan-implied unit capacity and the gap vs. existing units
#   * opportunity classification (vacant / underbuilt, infill / large site)
# Writes: output/data/parcels_scored.gpkg, output/data/headline_stats.csv

source(here::here("R", "00_setup.R"))

library(sf)
library(dplyr)
library(readr)
library(tidyr)

# ---- Read --------------------------------------------------------------

# type = 6 forces MULTIPOLYGON via GDAL, linearizing the ~900 MULTISURFACE
# (curve) features that GEOS otherwise can't process.
parcels_raw <- st_read(GDB_PATH, layer = GDB_LAYER, quiet = TRUE, type = 6)

parcels <- parcels_raw |>
  st_zm() |>                      # drop Z/M — source is Measured 3D MultiPolygon
  st_transform(CRS_PLANE) |>
  rename(geometry = Shape)
st_geometry(parcels) <- "geometry"

parcels <- filter(parcels, !st_is_empty(geometry))

# Repair invalid rings (self-intersections etc.) so areal ops behave.
invalid <- which(!st_is_valid(parcels))
if (length(invalid) > 0) {
  st_geometry(parcels)[invalid] <- st_make_valid(st_geometry(parcels)[invalid])
}

# ---- Clean -------------------------------------------------------------
# Field-specific quirks found in profiling:
#   * PercentageFlood / PercentSlope are only populated where a constraint
#     exists — NA genuinely means 0%.
#   * YearBuilt uses 0 as a "no building" sentinel.
#   * A handful of NA DwellingUnits / assessed values on exempt parcels.

parcels <- parcels |>
  mutate(
    PercentageFlood = replace_na(PercentageFlood, 0),
    PercentSlope    = replace_na(PercentSlope, 0),
    DwellingUnits   = replace_na(DwellingUnits, 0),
    FinalBuilding   = replace_na(FinalBuilding, 0),
    YearBuilt       = na_if(YearBuilt, 0)
  )

# ---- Derive ------------------------------------------------------------

parcels <- parcels |>
  mutate(
    # Economic softness: assessed improvement value relative to land value.
    # Undefined where land value is missing/zero (roads, exempt slivers).
    ilr = if_else(FinalLand > 0, FinalBuilding / FinalLand, NA_real_),

    # Constraint share: flood and slope percentages overlap in unknown ways,
    # so take the max of the two as the constrained fraction (conservative
    # without double-counting).
    constrained_share = pmax(PercentageFlood, PercentSlope) / 100,
    developable_acres = Acres * (1 - constrained_share),

    # Plan-implied capacity under the Growth Policy future land-use class.
    du_per_acre    = DU_PER_ACRE[Land_Use],
    capacity_units = coalesce(developable_acres * du_per_acre, 0),
    unit_gap       = pmax(capacity_units - DwellingUnits, 0)
  )

# ---- Classify opportunity parcels --------------------------------------
# A parcel is an opportunity when the Growth Policy plans housing for it,
# it is economically soft (vacant or ILR below threshold), it isn't public/
# exempt land, and it isn't mostly floodway or steep slope.

parcels <- parcels |>
  mutate(
    housing_eligible = !is.na(du_per_acre),
    is_vacant        = LandUseBuildingType_All %in% VACANT_USES,
    is_soft          = is_vacant | (!is.na(ilr) & ilr < ILR_SOFT),
    is_excluded_use  = LandUseBuildingType_All %in% EXCLUDED_USES,
    is_opportunity   = housing_eligible & is_soft & !is_excluded_use &
                       constrained_share <= MAX_CONSTRAINED_SHARE &
                       unit_gap >= 1,
    opportunity_type = case_when(
      !is_opportunity            ~ NA_character_,
      is_vacant                  ~ "Vacant",
      TRUE                       ~ "Underbuilt"
    ),
    site_scale = case_when(
      !is_opportunity            ~ NA_character_,
      Acres <= MAX_INFILL_ACRES  ~ "Infill (<= 5 ac)",
      TRUE                       ~ "Large site (> 5 ac)"
    ),

    # Counterpoint flag, not an opportunity: mobile homes on land planned
    # for higher density are the parcels most exposed to displacement
    # pressure if that capacity is realized.
    displacement_watch = LandUseBuildingType_All == "Mobile Home" &
                         housing_eligible
  )

# ---- Headline stats ----------------------------------------------------

opp <- filter(parcels, is_opportunity) |> st_drop_geometry()

headline <- tibble(
  stat = c(
    "parcels_total",
    "parcels_housing_eligible",
    "opportunity_parcels",
    "opportunity_acres",
    "potential_units_total",
    "potential_units_infill",
    "potential_units_large_sites",
    "potential_units_vacant",
    "potential_units_underbuilt",
    "existing_units_all_parcels",
    "share_capacity_top_decile_parcels",
    "displacement_watch_parcels",
    "displacement_watch_units"
  ),
  value = c(
    nrow(parcels),
    sum(parcels$housing_eligible),
    nrow(opp),
    sum(opp$Acres),
    sum(opp$unit_gap),
    sum(opp$unit_gap[opp$site_scale == "Infill (<= 5 ac)"]),
    sum(opp$unit_gap[opp$site_scale == "Large site (> 5 ac)"]),
    sum(opp$unit_gap[opp$opportunity_type == "Vacant"]),
    sum(opp$unit_gap[opp$opportunity_type == "Underbuilt"]),
    sum(parcels$DwellingUnits, na.rm = TRUE),
    { top <- ceiling(nrow(opp) / 10)
      sum(sort(opp$unit_gap, decreasing = TRUE)[seq_len(top)]) / sum(opp$unit_gap) },
    sum(parcels$displacement_watch),
    sum(parcels$DwellingUnits[parcels$displacement_watch])
  )
)

write_csv(headline, file.path(OUT_DATA, "headline_stats.csv"))
st_write(parcels, file.path(OUT_DATA, "parcels_scored.gpkg"),
         layer = "parcels", delete_dsn = TRUE, quiet = TRUE)

message("01_clean_derive: ", nrow(opp), " opportunity parcels, ",
        round(sum(opp$unit_gap)), " potential units.")
