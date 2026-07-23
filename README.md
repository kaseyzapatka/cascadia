# Missoula Housing Capacity — GIS Data Story

Analysis for the Cascadia Partners Technical Senior Associate hiring
exercise: a parcel-level look at how much housing Missoula's adopted Growth
Policy already makes room for, and where that capacity clusters.

**Deliverables** (all built from this repo):

- **Part 1 — data story slide:** `docs/missoula_data_story_slide.pdf`
  (one-page 11×8.5, from [slide.qmd](slide.qmd))
- **Part 2 — project management one-pager:**
  `docs/missoula_project_management.pdf` (from [part2.qmd](part2.qmd))
- **Part 3 — AI-enhanced web deliverable:** the Quarto website itself
  (data story, interactive map, methods, FAQ), published via GitHub Actions

## Headline findings

- **~43,000 plan-enabled units** sit on 3,587 vacant or underbuilt parcels
  (~4,300 acres) where the Growth Policy's future land use already calls
  for housing. Missoula has ~44,300 units today.
- **Half of that capacity is small-scale infill** (parcels ≤ 5 acres).
- **A third concentrates in ~4% of the urban fabric**: 46 Gi* hot-spot
  hexes (95%+ confidence) hold ~14,100 units — Mullan/Sxwtpqyen, midtown,
  and the south hills.
- **Counterpoint:** 530 mobile-home parcels (~2,850 affordable units) sit
  on planned-density land — flagged as displacement risk, excluded from
  the opportunity count.

## Pipeline

```sh
Rscript code/run_all.R   # raw .gdb -> derived data -> figures -> leaflet map
```

1. [code/01_clean_derive.R](code/01_clean_derive.R) — clean geodatabase
   quirks; derive improvement-to-land ratio, constraint share,
   plan-enabled capacity, opportunity screen
2. [code/02_hotspots.R](code/02_hotspots.R) — Getis-Ord Gi* on a 1,000-ft
   hex grid
3. [code/03_figures.R](code/03_figures.R) — slide/story figures
   (brand palette, colorblind-validated)
4. [code/04_interactive.R](code/04_interactive.R) — self-contained Leaflet
   map for the website

All tunable assumptions live in [code/00_setup.R](code/00_setup.R).
Requires R (developed on 4.5) with `sf`, `dplyr`, `tidyr`, `readr`,
`spdep`, `ggplot2`, `scales`, `leaflet`, `htmlwidgets`, `here`; exact
environment in [output/session_info.txt](output/session_info.txt).

## Website

Quarto site (pages: `index`, `map`, `methods`, `part2`, `faq`; config in
[_quarto.yml](_quarto.yml)). The site embeds the committed figures and map
from `output/`, so rendering never re-runs the analysis:

```sh
quarto render        # -> docs/ (also builds the three PDFs via post-render)
quarto preview       # local preview
```

Publishing: [.github/workflows/publish.yml](.github/workflows/publish.yml)
renders and pushes to the `gh-pages` branch on every push to `main`.
One-time setup after first push: **Settings → Pages → Deploy from a
branch → `gh-pages` / root**.

## Repository layout

```
data/       raw inputs (taxlot .gdb, FieldMap.csv) — never modified
code/       numbered R scripts + run_all.R entry point
output/     generated figures, leaflet map, stats (committed; gpkg ignored)
*.qmd       website pages + PDF deliverables (slide, part2)
scripts/    quarto post-render hook (PDF builds)
docs/       rendered site (gitignored; CI publishes gh-pages)
```

## Assumptions & caveats

- Density assumptions per future land-use designation are placeholders
  calibrated to Growth Policy ranges — **verify against the adopted
  document before client use** (`DU_PER_ACRE` in `code/00_setup.R`).
- Flood/slope NA means "no mapped constraint" (treated as 0%); constraint
  share takes the max of the two.
- Assessed values proxy economic softness (ILR), not market prices.
- Capacity is plan-implied, not a development forecast.
- The Sxwtpqyen Area designation is conservatively excluded from capacity,
  so totals are likely understated.
