#!/bin/bash
# Post-render hook: build the PDF deliverables into docs/.
#   missoula_data_story_slide.pdf   (Part 1 — one-page slide, from slide.qmd)
#   missoula_project_management.pdf (Part 2 — one-pager, from part2.qmd)
#   missoula_housing_memo.pdf       (full memo, from index.qmd)
# Output filenames are set via `output-file:` in each qmd so navbar links
# and the pages' "Download PDF" links stay consistent.
#
# Guard against recursion: the renders below re-trigger this hook.
if [ -n "$MISSOULA_RENDERING_PDF" ]; then
  exit 0
fi
export MISSOULA_RENDERING_PDF=1
set -e

echo "Rendering PDF deliverables..."
# slide.qmd is not a website page, so its output lands in the project
# root — move it into the site output dir alongside the others.
quarto render slide.qmd --to typst
mv -f missoula_data_story_slide.pdf docs/
quarto render part2.qmd --to typst
quarto render index.qmd --to typst
echo "  PDFs done."
