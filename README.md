# Missoula Housing Capacity — GIS Data Story

Analysis for the Cascadia Partners Technical Senior Associate hiring
exercise: a parcel-level look at how much housing Missoula's adopted Growth
Policy already makes room for, and where that untapped capacity clusters.

## Headline findings (first pass)

- **~43,000 plan-ready units** sit on 3,587 vacant or underbuilt parcels
  (4,311 acres) where the Growth Policy's future land use already calls for
  housing — no rezoning required. Missoula has ~44,300 units today.
- **Half of that capacity is small-scale infill** (parcels ≤ 5 acres), not
  just big greenfield tracts.
- **A third of it concentrates in ~4% of the urban fabric**: Getis-Ord Gi*
  hot spots (46 of 1,188 hex cells at 95%+ confidence) hold ~14,100 ready
  units, clustered in the Mullan/Sxtpqyen area, the midtown corridor, and
  the south hills.
- **Counterpoint:** 530 mobile-home parcels holding ~2,850 of the city's
  most affordable homes sit on land planned for higher density — a
  displacement-risk flag, deliberately excluded from the opportunity count.

## Method

1. **Clean & derive** ([R/01_clean_derive.R](R/01_clean_derive.R)) — read the
   taxlot geodatabase; derive improvement-to-land ratio (ILR), environmental
   constraint share (floodway / steep slope), plan-implied unit capacity by
   future land-use class, and the gap vs. existing units. A parcel is an
   *opportunity* when it is housing-eligible under the Growth Policy,
   economically soft (vacant or ILR < 1), not public/institutional/open-space
   land, and not mostly constrained.
2. **Hot spots** ([R/02_hotspots.R](R/02_hotspots.R)) — aggregate ready
   capacity to a 1,000-ft hex grid and run Getis-Ord Gi* (queen contiguity,
   self-inclusive) to find statistically significant clusters. Parcel-level
   Gi* is deliberately avoided: unit gap is so right-skewed that it only
   rediscovers individual mega-parcels.
3. **Figures** ([R/03_figures.R](R/03_figures.R)) — hero hot-spot map,
   existing-vs-capacity dumbbell by land-use class, and an infill/large-site
   breakdown. Palettes are colorblind-checked.

All tunable assumptions (density per land-use class, ILR threshold,
constraint cutoff, excluded uses, hex size) live in
[R/00_setup.R](R/00_setup.R).

## Reproduce

```sh
Rscript R/run_all.R
```

Requires R (developed on 4.5) with: `sf`, `dplyr`, `tidyr`, `readr`,
`spdep`, `ggplot2`, `scales`, `here`. The exact environment used is recorded
in [output/session_info.txt](output/session_info.txt).

Inputs are committed in `data/` (Esri file geodatabase + field map).
`python/` note: [code/read_data.py](code/read_data.py) is a small
geopandas utility used for initial data inspection; the pipeline itself is
pure R.

## Repository layout

```
data/     raw inputs (taxlot .gdb, FieldMap.csv) — never modified
R/        numbered analysis scripts + run_all.R entry point
code/     python data-inspection utility
output/   generated data (gpkg, csv) and figures (png) — reproducible
docs/     (reserved) rendered website for GitHub Pages
```

## Assumptions & caveats

- Density assumptions per future land-use class are **placeholders
  calibrated to the Our Missoula Growth Policy ranges** and must be verified
  against the adopted document before client use (`DU_PER_ACRE` in
  `R/00_setup.R`).
- Flood/slope percentages are only populated where a constraint exists; NA
  is treated as 0%. The constrained share takes the max of the two (they
  overlap in unknown ways).
- Assessed values are used as an economic-softness signal (ILR), not as
  market prices.
- Capacity is *plan-implied*, not a development forecast: it nets out
  constrained land and existing units but ignores ownership, market
  feasibility, and infrastructure.

## Roadmap

- [ ] Part 1 slide (hero map + headline stats + capacity chart)
- [ ] Part 2 page (scaling, delegation/QC, $50k budget)
- [ ] Quarto website rendered via GitHub Actions (Part 3, embeddable
      interactive version of the story)
