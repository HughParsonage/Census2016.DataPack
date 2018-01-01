for (Region in c("SA2", "SA3", "SA4", "LGA", "CED", "SED", "POA", "STE")) {
  table_killer <- NULL; cat("\n-------", Region, "-------\n");
  invisible(source(knitr::purl("data-raw/put-data.Rmd", output = tempfile(), quiet = TRUE)))
}

