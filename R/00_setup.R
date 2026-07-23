# 00_setup.R
# Shared paths, parameters, and analysis assumptions.
# Every downstream script sources this file, so all tunable assumptions
# live here and nowhere else.

library(here)

# ---- Paths -------------------------------------------------------------

GDB_PATH   <- here("data", "HiringExercise_GIS_2024.gdb")
GDB_LAYER  <- "CP_Hiring_Exercise_Missoula"
FIELDMAP   <- here("data", "FieldMap.csv")
OUT_DATA   <- here("output", "data")
OUT_FIG    <- here("output", "figures")

dir.create(OUT_DATA, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_FIG,  recursive = TRUE, showWarnings = FALSE)

# CRS: NAD83 State Plane Montana (US ft) — matches the source layer, keeps
# areal math in familiar units. EPSG 102700 lacks an EPSG code; 2256 is the
# int'l-foot twin and is what sf resolves the source WKT to in practice.
CRS_PLANE <- 2256

# ---- Capacity assumptions ---------------------------------------------
# Assumed allowable net densities (dwelling units / acre) by City Growth
# Policy future land-use designation. PLACEHOLDERS calibrated to the ranges
# in the Our Missoula Growth Policy (2035) land-use guide — verify against
# the adopted document before client use. Classes not listed are treated as
# not housing-eligible and contribute zero capacity.
DU_PER_ACRE <- c(
  "Residential Low"         = 3,
  "Residential Medium"      = 8,
  "Residential Medium-High" = 16,
  "Residential High"        = 29,
  "Neighborhood Mixed Use"  = 16,
  "Community Mixed Use"     = 29,
  "Urban Center"            = 43
)

# ---- Screening thresholds ---------------------------------------------

# Improvement-to-land ratio below which a parcel is considered economically
# "soft" (the building is worth less than the land under it).
ILR_SOFT <- 1.0

# Parcels with more than this share of floodway or steep slope are treated
# as constrained out of the opportunity set entirely.
MAX_CONSTRAINED_SHARE <- 0.50

# Existing-use classes that are never treated as redevelopment
# opportunities, in four groups:
#   * public / institutional land that won't turn over on market signals
#   * parks, open space, and recreation (incl. private courses/clubs)
#   * master parcels, which would double-count their child condo units
#   * mobile homes — cheap improvements on planned-density land score as
#     "soft," but redeveloping them displaces naturally occurring
#     affordable housing; they're flagged separately as preservation risk
EXCLUDED_USES <- c(
  # public / institutional
  "Government Property", "Government-Parks and Open Space",
  "Church", "School", "University", "Hospital", "Emergency Services",
  "Post Office", "Library", "Cultural Facility", "Cultural Center",
  "Centrally Assessed", "Stadium", "Rail/Bus/Air Terminal",
  # parks / open space / recreation
  "HOA - Open Space and Parks", "HOA-Parks and Open Space",
  "Golf Course", "Country Club", "Tennis Club", "Cemetery",
  # master parcels (units live on child condo records)
  "Condo/Townhouse Master", "Condominium Master",
  # naturally occurring affordable housing — preservation, not opportunity
  "Mobile Home"
)

# Existing-use classes counted as vacant/unimproved.
VACANT_USES <- c("Vacant Land")

# Parcels at or below this size are "infill" opportunities; larger soft
# parcels are reported separately as "large sites" so a handful of big
# edge-of-town tracts can't quietly dominate the headline number.
MAX_INFILL_ACRES <- 5

# ---- Hot-spot parameters ----------------------------------------------

HEX_CELLSIZE_FT <- 1000    # hex center-to-center distance (ft), ~23 ac cells
GI_SEED         <- 20260722  # seed for reproducibility
