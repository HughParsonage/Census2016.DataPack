for (Region in c("STE", "SED",
                 "SA1",
                 "SA2", "SA3", "SA4", "LGA", "CED",
                 "SSC",
                 "POA")) {
  in_for_loop <- TRUE
  table_killer <- NULL; cat("\n-------", Region, "-------\n");
  invisible(source(knitr::purl("data-raw/put-data.Rmd", output = tempfile(), quiet = TRUE)))
}

