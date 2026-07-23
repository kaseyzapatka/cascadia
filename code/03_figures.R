# 03_figures.R
# Slide-ready figures for the data story:
#   fig1_hotspot_map.png   — hero map: Gi* hot spots of ready capacity
#   fig2_capacity_gap.png  — existing units vs. plan capacity by land-use class
#   fig3_breakdown.png     — where the ready units sit (scale x type)
# Writes PNGs (300 dpi) to output/figures/.

source(here::here("code", "00_setup.R"))

library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

parcels <- st_read(file.path(OUT_DATA, "parcels_scored.gpkg"), quiet = TRUE)
hexes   <- st_read(file.path(OUT_DATA, "hex_hotspots.gpkg"),   quiet = TRUE)

# ---- Shared style ------------------------------------------------------
# Palette anchored on the user's brand swatches — steel blue #7096c0 and
# chartreuse green #bdc74f — validated for CVD safety with the dataviz
# palette checker: blue = what exists, green = what the plan adds (marks
# use the deeper #8b9c26 step of the same hue so they read against white;
# the light swatch tone survives as fills/tints). The map's hot classes
# are the green hue stepped light -> dark with neutral gray for "not
# significant" and blue for (absent) cold spots.

COL_EXISTING <- "#7096c0"
COL_ADDED    <- "#8b9c26"
COL_FABRIC   <- "#efedea"   # background parcel fabric
COL_INK      <- "#272727"
COL_INK2     <- "#52514e"

PAL_GI <- c(
  "Hot spot (99% conf.)" = "#4c5813",
  "Hot spot (95% conf.)" = "#8b9c26",
  "Hot spot (90% conf.)" = "#c9d465",
  "Not significant"      = "#e8e6e1",
  "Cold spot"            = "#7096c0"
)

# Plain-language legend: a Gi* "hot spot" is a hex whose neighborhood-wide
# capacity is higher than chance would allow — i.e., a cluster of high
# values surrounded by high values (the Gi* analogue of LISA's high-high).
LBL_GI <- c(
  "Hot spot (99% conf.)" = "Capacity cluster — 99% confidence",
  "Hot spot (95% conf.)" = "Capacity cluster — 95% confidence",
  "Hot spot (90% conf.)" = "Capacity cluster — 90% confidence",
  "Not significant"      = "No significant clustering",
  "Cold spot"            = "Low-capacity cluster"
)

theme_story <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      text             = element_text(color = COL_INK),
      plot.title       = element_text(face = "bold", size = rel(1.25)),
      plot.subtitle    = element_text(color = COL_INK2, size = rel(0.95)),
      plot.caption     = element_text(color = COL_INK2, size = rel(0.7), hjust = 0),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#e8e6e1", linewidth = 0.3),
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      legend.position  = "top",
      legend.justification = "left"
    )
}

# ---- Fig 1: hero hot-spot map ------------------------------------------

fig1 <- ggplot() +
  geom_sf(data = parcels, fill = COL_FABRIC, color = NA) +
  geom_sf(data = hexes, aes(fill = gi_class), color = "#fcfcfb",
          linewidth = 0.1, alpha = 0.92) +
  scale_fill_manual(values = PAL_GI, labels = LBL_GI, name = NULL, drop = FALSE) +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title    = "Missoula's untapped housing capacity clusters in a few corridors",
    subtitle = "Getis-Ord Gi* hot spots of plan-enabled units on vacant and underbuilt parcels\n(1,000-ft hex grid over housing-eligible parcels)",
    caption  = "Source: City of Missoula taxlot data (2024). Analysis: capacity gap between Growth Policy\nfuture land use and existing dwelling units on unconstrained, economically soft parcels."
  ) +
  theme_story() +
  theme(
    axis.text        = element_blank(),
    panel.grid.major = element_blank()
  )

ggsave(file.path(OUT_FIG, "fig1_hotspot_map.png"), fig1,
       width = 8.5, height = 9.5, dpi = 300, bg = "#fcfcfb")

# ---- Fig 2: existing units vs. plan capacity by land-use class ---------
# Dumbbell: blue dot = units on the ground today, orange dot = today plus
# the ready capacity identified on opportunity parcels in that class.

by_class <- parcels |>
  st_drop_geometry() |>
  filter(housing_eligible) |>
  group_by(Land_Use) |>
  summarise(
    existing = sum(DwellingUnits),
    ready    = sum(unit_gap[is_opportunity]),
    .groups  = "drop"
  ) |>
  mutate(potential = existing + ready) |>
  arrange(desc(ready)) |>
  mutate(Land_Use = factor(Land_Use, levels = rev(Land_Use)))

fig2 <- ggplot(by_class, aes(y = Land_Use)) +
  geom_segment(aes(x = existing, xend = potential, yend = Land_Use),
               color = "#c9c7c1", linewidth = 1.2) +
  geom_point(aes(x = existing,  color = "Homes today"), size = 3.2) +
  geom_point(aes(x = potential, color = "If plan-enabled capacity is built"), size = 3.2) +
  geom_text(aes(x = potential, label = paste0("+", comma(round(ready)))),
            hjust = -0.35, size = 3.1, color = COL_INK2) +
  scale_color_manual(values = c("Homes today" = COL_EXISTING,
                                "If plan-enabled capacity is built" = COL_ADDED),
                     name = NULL) +
  scale_x_continuous(labels = comma, expand = expansion(mult = c(0.02, 0.16))) +
  labs(
    title    = "The Growth Policy already makes room for ~43,000 more homes",
    subtitle = "Dwelling units by Growth Policy future land-use designation (not current zoning):\ntoday vs. with capacity on vacant and underbuilt parcels",
    caption  = "Plan-enabled capacity = assumed allowable density x developable acres on unconstrained soft parcels,\nnet of existing units. Density assumptions pending verification against the adopted Growth Policy.",
    x = "Dwelling units", y = NULL
  ) +
  theme_story()

ggsave(file.path(OUT_FIG, "fig2_capacity_gap.png"), fig2,
       width = 10, height = 5.5, dpi = 300, bg = "#fcfcfb")

# ---- Fig 3: where the ready units sit ----------------------------------

breakdown <- parcels |>
  st_drop_geometry() |>
  filter(is_opportunity) |>
  count(site_scale, opportunity_type, wt = unit_gap, name = "units")

fig3 <- ggplot(breakdown,
               aes(x = units, y = site_scale, fill = opportunity_type)) +
  geom_col(width = 0.55, color = "#fcfcfb", linewidth = 0.8) +
  geom_text(aes(label = comma(round(units))),
            position = position_stack(vjust = 0.5),
            color = "#272727", size = 3.4, fontface = "bold") +
  scale_fill_manual(values = c("Vacant" = COL_EXISTING,
                               "Underbuilt" = COL_ADDED), name = NULL) +
  scale_x_continuous(labels = comma) +
  labs(
    title    = "Half the opportunity is small-scale infill",
    subtitle = "Plan-enabled units by parcel size and current condition",
    x = "Plan-enabled dwelling units", y = NULL
  ) +
  theme_story()

ggsave(file.path(OUT_FIG, "fig3_breakdown.png"), fig3,
       width = 9, height = 3.6, dpi = 300, bg = "#fcfcfb")

message("03_figures: wrote 3 figures to ", OUT_FIG)
