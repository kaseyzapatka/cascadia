#!/bin/bash
# Pre-render hook (runs from report/): stage pipeline figures inside the
# project dir. Typst restricts file access to the project root, so pages
# can't reference ../output directly; this copy keeps the pipeline's
# output/ as the single source of truth. report/figures/ is gitignored.
set -e
mkdir -p figures
cp ../output/figures/*.png figures/
