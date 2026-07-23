# run_all.R
# Reproduce the full analysis from raw data to figures:
#   Rscript R/run_all.R
# Scripts are numbered and independent — each reads its inputs from disk —
# so any one can also be re-run alone after upstream outputs exist.

scripts <- c("01_clean_derive.R", "02_hotspots.R", "03_figures.R", "04_interactive.R")

for (s in scripts) {
  message("==> ", s)
  source(here::here("code", s), local = new.env())
}

# Record the environment the results were produced with.
writeLines(
  c(capture.output(sessionInfo()), "", paste("Run date:", Sys.Date())),
  here::here("output", "session_info.txt")
)
message("==> done; session info written to output/session_info.txt")
