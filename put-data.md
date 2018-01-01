---
title: "Data by Commonwealth Election Division etc"
author: "Hugh Parsonage"
date: "17 July 2017"
output: html_document
---


```r
# Region <- "CED"
```


```r
START <- Sys.time()
if (basename(dirname(getwd())) == "data-raw") {
  knitr::opts_knit$set(root.dir = "..")
}
knitr::opts_chunk$set(echo = TRUE, 
                      print_chunk = TRUE)
```


```r
library(readxl)
library(testthat)
library(magrittr)
library(hutils)
library(data.table)
```


```r
# Ensure we are working with pristine tables
if (!isTRUE(getOption("knitr.in.progress"))) {
  AllTables <- Filter(function(x) is.data.table(get(x)), ls())
  if (length(AllTables) != 0) {
    if (exists("table_killer")) {
      menu_selection <- 1
    } else {
      menu_selection <- menu(c("Remove all tables.",
                               "Cancel."),
                             title = "Data tables detected. This script will save all tables in the workspace to the package. Remove current tables from workspace?")
    }
  }
  
  if (exists("menu_selection")) {
    if (menu_selection %in% c(0, 2)) {
      stop("Operation cancelled.")
    } else {
      rm(list = AllTables)
    }
  }
}
library(ASGS)
```


```r
Metadata <-
  read_excel("data-raw/data-packs/Metadata/Metadata_2016_GCP_DataPack.xls",
             sheet = 2,
             skip = 10) %>%
  as.data.table
```

```
## Error in read_fun(path = path, sheet = sheet, limits = limits, shim = shim, : path[1]="data-raw/data-packs/Metadata/Metadata_2016_GCP_DataPack.xls": The system cannot find the path specified
```


```r
SA16_decoder <- fread("data-raw/SA16_decoder.csv")
```

```
## Error in fread("data-raw/SA16_decoder.csv"): File 'data-raw/SA16_decoder.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
Region_key <- 
  fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv')) %>%
  names %>%
  extract2(1)
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
#' @return Wide as-is data table of all tables.
freadG <- function(g, ...) {
  stopifnot(length(g) == 1)
  g0 <- paste0(if (g < 10) "0", g)
  file_list <-
    list.files(path = file.path('./data-raw/data-packs/data/', Region, 'AUST'),
               # Files may be of the form ..G08_AUS.. or ..G09B_AUS..
               pattern = paste0('2016Census_G', g0, '[A-Z]?_AUS_', Region, '\\.csv$'),
               full.names = TRUE)
  if (length(file_list) > 1) {
    file_list %>%
    lapply(fread, key = Region_key, logical01 = FALSE, ...) %>%
    Reduce(f = function(X, Y) X[Y])
  } else {
    fread(file = file_list[1], logical01 = FALSE, ...)
  }
}
```


```r
# Performance
grep <- function(..., perl, fixed) base::grep(..., perl = missing(fixed), fixed = !missing(fixed))
grepl <- function(..., perl, fixed) base::grepl(..., perl = missing(fixed), fixed = !missing(fixed))
gsub <- function(..., perl, fixed) base::gsub(..., perl = missing(fixed), fixed = !missing(fixed))
```


```r
force_double <- function(x) suppressWarnings(as.double(x))
```


```r
total_adults <- 
  fread("./data-raw/data-packs/data/AUST/2016Census_G01_AUS.csv") %>%
  .[, .SD, .SDcols = c(1, grep("^Age_[0-9]{2}.*_P$", names(.)))] %>%
  melt.data.table(id.vars = names(.)[1]) %$%
  sum(value)
```

```
## Error in fread("./data-raw/data-packs/data/AUST/2016Census_G01_AUS.csv"): File './data-raw/data-packs/data/AUST/2016Census_G01_AUS.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
.decode_country <- function(x, to = "alpha-3") {
  xna <- is.na(x)
  x[!xna] <- trimws(x[!xna])
  stopifnot(to == "alpha-3",
            names(ISO3166)[1] == "name")
  nom <- ISO3166[["name"]]
  a3 <- ISO3166[["alpha_3"]]
  keep <- and(nchar(x, keepNA = FALSE) == 3L,
              x == toupper(x))
  
  res <- a3[pmatch(x, nom, duplicates.ok = TRUE)]
  res[keep] <- x[keep]
  if (F & anyNA(res[!is.na(x)])) {
    print(x[is.na(res[!is.na(x)])])
    stop("Country code could not be decoded.")
  }
  res[xna] <- NA_character_
  res
}

decode_country <- function(out) {
  stopifnot(is.data.table(out),
            "CountryOfBirth" %in% names(out))
  out[, CountryOfBirth := trimws(gsub("_", " ", CountryOfBirth))]
  out[, CountryOfBirth := gsub("(?<!(F))Ye?a?r.*arrival.ns$", "", CountryOfBirth, ignore.case = TRUE)]
  out[CountryOfBirth %pin% "(Born )?[Ee]lsewhere", CountryOfBirth := NA_character_]
  out[CountryOfBirth %pin% "Bosnia", CountryOfBirth := "Bosnia and Herzegovina"]
  out[CountryOfBirth %pin% "Korea", CountryOfBirth := "KOR"]
  out[CountryOfBirth %pin% c("N[a-z]+n Ireland",
                             "England",
                             "Scotland",
                             "Wales"),
      CountryOfBirth := "United Kingdom"]
  out[CountryOfBirth %pin% "SE Europe nfd", CountryOfBirth := NA_character_]
  out[CountryOfBirth == "Vietnam", CountryOfBirth := "VNM"]
  # Negative lookbehind due to FYROM (Macedonia)
  
  
  out[CountryOfBirth %pin% "FYROM",                   CountryOfBirth := "MKD"]
  out[CountryOfBirth %pin% "China excl? SARs Tai?w",  CountryOfBirth := "CHN"]
  out[CountryOfBirth %pin% c("USA", "United States"), CountryOfBirth := "USA"]
  out[CountryOfBirth %pin% "Ho?ng Ko?ng",             CountryOfBirth := "Hong Kong"]
  out[, CountryOfBirth := .decode_country(CountryOfBirth)]
  out[]
}
```


```r
Mop <- function(DT, value.name = "persons", suborder = NULL) {
  stopifnot(value.name %in% names(DT),
            # Should be Completed
            'MaxSchooling' %notin% names(DT))
  
  # Check for no duplicates, except for value.name
  if (anyDuplicated(DT, by = setdiff(names(DT), c(value.name, "variable")))) {
    print(duplicated_rows(DT, by = setdiff(names(DT), c(value.name, "variable"))))
    stop("Duplicated rows.")
  }
  
  # Are any columns constant?
  uv <- vapply(DT, uniqueN, integer(1))
  if (any(uv == 1)) {
    print(names(uv)[uv == 1])
    stop("Constant columns in DT.")
  }
  
  out <- DT
  
  if ("CountryOfBirth" %chin% names(out)) {
    if (!all(coalesce(nchar(out[["CountryOfBirth"]]), 3L) == 3L)) {
      stop("CountryOfBirth must be ISO-3166-2")
    }
  }
  
  if ("Dwelling" %chin% names(out)) {
    out[, PrivateDwelling := Dwelling == "Private"]
    out[, Dwelling := NULL]
  }
  
  if ("HasChildren" %chin% names(out)) {
    setnames(out, "HasChildren", "HasChild")
  }
  if ("HasChildrenUnder15" %chin% names(out)) {
    setnames(out, "HasChildrenUnder15", "HasChildUnder15")
  }
  if ("YearOfArrival" %chin% names(out)) {
    setnames(out, "YearOfArrival", "YearOfArrival.max")
  }
  
  if ("SchoolSector" %chin% names(out)) {
    out[SchoolSector == "Non_Govt",
        SchoolSector := "Non-government"]
  }
  
  if ("MaxSchoolingCompleted" %chin% names(out)) {
    out[,
        "MaxSchoolingCompleted" := factor(MaxSchoolingCompleted,
                                          levels = c("Did not go to school", 
                                                     "Year 8 or below",
                                                     "Year 8",
                                                     "Year 9",
                                                     "Year 10",
                                                     "Year 11",
                                                     "Year 12"),
                                          ordered = TRUE)]
  }
  
  if ("FamilyComposition" %chin% names(out)) {
    if (!OR("CoupleFamily" %in% names(out),
            uniqueN(out[["FamilyComposition"]]) > 3L)) {
      out[!grepl("Other", FamilyComposition),
          CoupleFamily := FamilyComposition %pin% "Couple"]
      out[, FamilyComposition := NULL]
    }
  }
  
  if ("IncomeTotPersonal.min" %chin% names(out)) {
    out[, IncomeTotPersonal.min := NULL]
  }
  
  out <- 
    out %>%
    drop_col("variable") %>%
    setcolorder(sort(names(.))) %>%
    set_cols_first(Region_key) %>%
    setorderv(setdiff(names(.), value.name)) %>%
    set_cols_last(value.name) %>%
    .[]
  
  for (j in names(out)) {
   out[out[[j]] == "Other", (j) := "(Other)"]
  }
  
  # http://www.abs.gov.au/ausstats/abs@.nsf/0/1CD2B1952AFC5E7ACA257298000F2E76?OpenDocument
  if (Region %notin% c("SA1", "SA2")) {
    # na.rm = TRUE for medianTotalPersonalIncome etc
    apparent_population <- sum(out[[value.name]], na.rm = TRUE)
  } else {
    apparent_population <- sum(as.double(out[[value.name]]), na.rm = TRUE)
  }
  
  permitted_error <- switch(Region,
                            "SA1" = 1.5e6,
                            0.5e6)
  permitted_error <- 
    permitted_error * (1 + any(value.name == "adults" && "MaxSchoolingCompleted" %in% names(DT)))
  
  if (Region == "SA1" && any(grepl("IncomeTotPersonal|Age.min", names(DT)))) {
    permitted_error <-  4e6
  }
  
  if (Region == "SSC" && any(grepl("IncomeTotPersonal|Age.min", names(DT)))) {
    permitted_error <-  1e6
  }
  
  expected_population <- 
    switch(value.name,
           "persons" = 23401.9e3,
           "adults" = total_adults,
           # i.e. make no check
           apparent_population)
  
  if (AND(!any(c("BornAust",
                 "MaritalStatus",
                 "MaxSchoolingCompleted",
                 "OnlyEnglishSpokenHome") %in% names(DT)),
          abs(apparent_population - expected_population) > permitted_error)) {
    if (apparent_population < expected_population) {
      stop("Population undercounted: ", prettyNum(apparent_population, big.mark = ","),
           " (e = ", prettyNum(abs(apparent_population - expected_population), big.mark = ","), ")",
           "\nShould you have used a different value.name?")
    } else {
      stop("Apparent population too high: ", prettyNum(apparent_population, big.mark = ","),
           " (e = ", prettyNum(abs(apparent_population - expected_population), big.mark = ","), ")")
    }
  }
  
  # Check for no duplicates, except for value.name
  if (anyDuplicated(out, by = setdiff(names(out), value.name))) {
    print(duplicated_rows(out, by = setdiff(names(out), value.name)))
    stop("Duplicated rows.")
  }
  if (!is.null(suborder)) {
    set_colsuborder(out, suborder)
    setorderv(out, setdiff(names(out), value.name))
  }

  out_noms <- names(out)
  
  object_name <- 
    paste0(Region,
           "__",
           if (length(out_noms) == 2) {
             sub("persons", "Persons", value.name)
           } else {
             paste0(setdiff(out_noms, c(Region_key, value.name)),
                    collapse = "_")
           })
  
  if (Region %notin% c("SA1", "POA")) {
    decoder <- 
      switch(Region,
             "SA2" = SA16_decoder[ASGS_Structure == Region,
                                  .(SA2_MAIN16 = Census_Code_2016,
                                    SA2_NAME16 = Census_Name_2016)],
             "SA3" = SA16_decoder[ASGS_Structure == Region,
                                  .(SA3_MAIN16 = Census_Code_2016,
                                    SA3_NAME16 = Census_Name_2016)],
             "SA4" = SA16_decoder[ASGS_Structure == Region,
                                  .(SA4_MAIN16 = Census_Code_2016,
                                    SA4_NAME16 = Census_Name_2016)],
             "STE" = SA16_decoder[ASGS_Structure == Region,
                                  .(STE_MAIN16 = Census_Code_2016,
                                    STE_NAME16 = Census_Name_2016)],
             "LGA" = {
               NonABS_decoder[ASGS_Structure == Region,
                              .(Census_Code_2016, LGA_NAME16 = Census_Name_2016)]
             },
             "CED" = {
               NonABS_decoder[ASGS_Structure == Region,
                              .(Census_Code_2016, CED_NAME16 = Census_Name_2016)]
             },
             "SED" = {
               NonABS_decoder[ASGS_Structure == Region,
                              .(Census_Code_2016, SED_NAME16 = Census_Name_2016)]
             },
             "SSC" = {
               NonABS_decoder[ASGS_Structure == Region,
                              .(Census_Code_2016, SSC_NAME16 = Census_Name_2016)]
             },
             NULL) %>%
      unique %>%
      setnames(1, Region_key)
    
    decoded_out <- decoder[out, on = Region_key]
    decoded_out[, (Region_key) := NULL]
  } else {
    
    if (is.integer(out[[value.name]]) && 
        !anyNA(out[[value.name]]) &&
        all(.subset2(out, value.name) >= 0L)) {
      decoded_out <- out[.subset2(out, value.name) > 0L]
    } else {
      decoded_out <- out
    }
    
  }
  
  if (!anyDuplicated(decoded_out, by = setdiff(names(decoded_out), value.name))) {
    out <- decoded_out 
  } else {
    cat("\n\n\n\n\n")
    print(duplicated_rows(decoded_out, by = setdiff(names(decoded_out), value.name)))
    cat("\n\n\n\n\n")
  }
  
  if (exists(object_name, envir = .GlobalEnv)) {
    if (last(names(get(object_name, envir = .GlobalEnv))) != last(names(out))) {
      object_name <- paste0(object_name, "_", last(names(out)))
      if (exists(object_name, envir = .GlobalEnv)) {
        stop(object_name, " already exists.")
      }
    }
  }
  
  if (!is.null(attributes(names(out)))) {
    attributes(names(out)) <- NULL
  }
  
  assign(object_name, out, envir = .GlobalEnv)
  
  decoded_out[]
}
```



```r
iso3166_url <-
  "https://raw.githubusercontent.com/lukes/ISO-3166-Countries-with-Regional-Codes/master/all/all.csv"

ISO3166 <-
  if (file.exists("data-raw/ISO-3166-countries.csv")) {
    fread("data-raw/ISO-3166-countries.csv")
  } else {
    fread(iso3166_url) %T>%
      fwrite("data-raw/ISO-3166-countries.csv") %>%
      .[]
  }
```

```
## Error in fwrite(., "data-raw/ISO-3166-countries.csv"): No such file or directory: 'data-raw/ISO-3166-countries.csv'. Unable to create new file for writing (it does not exist already). Do you have permission to write here, is there space on the disk and does the path exist?
```

```r
setnames(ISO3166, "alpha-3", "alpha_3")
```

```
## Error in is.data.frame(x): object 'ISO3166' not found
```


```r
expect_equal(.decode_country(c("United Kingdom", "Australia", "Australia",
                               NA)), 
             c("GBR", "AUS", "AUS",
               NA))
```

```
## Error in stopifnot(to == "alpha-3", names(ISO3166)[1] == "name"): object 'ISO3166' not found
```


```r
NonABS_decoder <-
  read_excel("./data-raw/data-packs/Metadata/2016Census_geog_desc_1st_release.xlsx",
             sheet = "2016_ASGS_Non-ABS_Structures") %>%
  as.data.table
```

```
## Error in sheets_fun(path): zip file './data-raw/data-packs/Metadata/2016Census_geog_desc_1st_release.xlsx' cannot be opened
```


```r
zero2NA <- function(DT) {
  Classes <- vapply(DT, storage.mode, character(1))
  IntNoms <- names(Classes)[Classes == "integer"]
  for (j in which(Classes == "integer")) {
    set(DT, i = which(DT[[j]] == 0L), j = j, value = NA_integer_)
  }
  
  for (j in which(Classes == "double")) {
    set(DT, i = which(abs(DT[[j]]) < .Machine$double.eps), j = j, value = NA_real_)
  }
  DT
}

local({
  DT <- data.table(x = 1:5, y = c(0L, 1:4), z = c(-0.5, 0, 0.5, 1, 1.5),
                   ZZ = LETTERS[1:5])
  zero2NA(DT)
  
  expect_equal(DT[["x"]], 1:5)
  expect_equal(DT[["y"]], c(NA_integer_, 1:4))
  expect_equal(DT[["z"]], c(-0.5, NA_real_, 0.5, 1, 1.5))
  expect_equal(DT[["ZZ"]], LETTERS[1:5])
})
```


```r
CED_decoder <-
  read_excel("./data-raw/data-packs/Metadata/2016Census_geog_desc_1st_release.xlsx", 
             sheet = "2016_ASGS_Non-ABS_Structures") %>%
  setDT %>%
  .[ASGS_Structure == "CED"] %>%
  setnames("Census_Code_2016", Region_key) %>%
  setnames("Census_Name_2016", "Electoral_division") %>%
  .[, .SD, .SDcols =  c(Region_key, "Electoral_division")]
```


```r
extract_age <- function(variable, orderedFactor = TRUE) {
  out <- 
    variable %>%
    # Prepare:
    gsub("_yrs_ovr", "_ov", .) %>%
    gsub("([0-9]{2})_ov", "\\1ov", x = ., perl = TRUE) %>%
    gsub("^.*(_[0-9]{2}_[0-9]{2})_yrs?.*$", "\\1", x = .) %>%
    gsub("^.*85ov.*$", "_85ov", x = .) %>%
    # Extract
    gsub("^.*?_((?:[0-9]{1,2}(?![0-9]))(?:(?:_[0-9]{1,2}(?![0-9])))?(?:ov)?).*$", "\\1", ., perl = TRUE) %>%
    gsub("_", "-", ., fixed = TRUE) %>%
    gsub("_?ov", "+", ., perl = TRUE)
  
  # Has 'ov' in original and only numbers in out
  out <- hutils::if_else(grepl("[^A-Za-z]ov[^A-Za-z]", variable, perl = TRUE) & grepl("^[0-9]+$", out),
                        paste0(out, "+"),
                        out)
  
  if (orderedFactor) {
    out <- factor(out, levels = unique(out), ordered = TRUE)
  }
  out
}

expect_equal(extract_age("Count_home_Census_Nt_0_14_yr", FALSE), "0-14")
expect_equal(extract_age("Age_0_4_yr_P", FALSE), "0-4")
expect_equal(extract_age("Age_psns_att_edu_inst_25_ov_P", FALSE), "25+")
expect_equal(extract_age("A_65_y_ov_Indig_stat_ns_P", FALSE), "65+")
expect_equal(extract_age("P_Hghst_yr_schl_ns_85_yrs_ovr", FALSE), "85+")
expect_equal(extract_age("M_1_149_15_19_yrs", FALSE), "15-19")
expect_equal(extract_age("M_1_149_85ov", FALSE), "85+")
```


```r
strip_age <- function(variable, orderedFactor = FALSE) {
  out <- 
    variable %>%
    # Prepare:
    gsub("([0-9]{2})_ov", "\\1ov", x = ., perl = TRUE) %>%
    # Extract
    gsub("(_[0-9]+(?:_[0-9]{1,2})?(?:ov)?)_yr", "", ., perl = TRUE)
  if (orderedFactor) {
    out <- factor(out, levels = unique(out), ordered = TRUE)
  }
  out
}

expect_equal(strip_age("P_15_19_yr_Marrd_reg_marrge"), "P_Marrd_reg_marrge")
```

### G01


```r
assign(paste0(Region, '__Persons'), { 
  fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'),
        select = c(Region_key, "Tot_P_P")) %>%
    setnames("Tot_P_P", "persons") %>%
    Mop
})
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'),
      select = c(Region_key, "Tot_P_M", "Tot_P_F")) %>%
  melt.data.table(id.vars = Region_key,
                  variable.name = "Sex",
                  value.name = "persons") %>%
  .[, Sex := gsub("Tot_P_", "", Sex)] %>%
  .[] %>% 
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv')) %>%
  .[, .SD, .SDcols = c(Region_key, 
                       grep("^Age_[0-9].*P$", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  variable.name = "Age",
                  value.name = "persons") %>%
  .[, Age := extract_age(Age)] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv')) %>%
  .[, .SD, .SDcols = c(Region_key, 
                       grep("^Age_[0-9].*[MF]$", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  
                  value.name = "persons") %>%
  .[, Age := extract_age(variable)] %>%
  .[, Sex := gsub("^.*([MF])$", "\\1", variable)] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'), 
      select = c(Region_key, "Counted_Census_Night_home_P", "Count_Census_Nt_Ewhere_Aust_P")) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[, HomeCensusNight := grepl("home", variable)] %>%
  .[, .SD, .SDcols = c(Region_key, "HomeCensusNight", "persons")] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'), 
      select = c(Region_key,
                 "Counted_Census_Night_home_M", "Count_Census_Nt_Ewhere_Aust_M",
                 "Counted_Census_Night_home_F", "Count_Census_Nt_Ewhere_Aust_F")) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  
  .[, HomeCensusNight := grepl("home", variable)] %>%
  .[, Sex := gsub("^.*([MF])$", "\\1", variable, perl = TRUE)] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'), 
        select = c(Region_key,
                   "Tot_P_P",
                   "Indigenous_psns_Aboriginal_P",
                   "Indig_psns_Torres_Strait_Is_P", 
                   "Indig_Bth_Abor_Torres_St_Is_P")) %>%
  .[, non_Indig := Tot_P_P - (Indigenous_psns_Aboriginal_P +
                                Indig_psns_Torres_Strait_Is_P +
                                Indig_Bth_Abor_Torres_St_Is_P)] %>%
  .[, Tot_P_P := NULL] %>%
  .[] %>%
  melt.data.table(id.vars = c(Region_key),
                  value.name = "persons") %>%
  .[, IndigenousStatus := "Non-indigenous"] %>%
  .[variable == "Indigenous_psns_Aboriginal_P",
    IndigenousStatus := "Aboriginal"] %>%
  .[variable == "Indig_Bth_Abor_Torres_St_Is_P",
    IndigenousStatus := "Both Aboriginal & Torres Strait Islander"] %>%
  .[variable == "Indig_psns_Torres_Strait_Is_P",
    IndigenousStatus := "Torres Strait Islander"] %>%
  .[, IndigenousStatus := factor(IndigenousStatus, levels = unique(.$IndigenousStatus), ordered = TRUE)] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'), 
      select = c(Region_key, 
                 "Birthplace_Australia_P",
                 "Birthplace_Elsewhere_P")) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[variable == "Birthplace_Australia_P", BornAust := TRUE] %>%
  .[variable == "Birthplace_Elsewhere_P", BornAust := FALSE] %>%
  .[] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'), 
      select = c(Region_key, 
                 "Birthplace_Australia_F", "Birthplace_Australia_M",
                 "Birthplace_Elsewhere_F", "Birthplace_Elsewhere_M")) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[variable %pin% "Birthplace_Australia", BornAust := TRUE] %>%
  .[variable %pin% "Birthplace_Elsewhere", BornAust := FALSE] %>%
  .[variable %pin% "F$", Sex := "F"] %>%
  .[variable %pin% "M$", Sex := "M"] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'), 
      select = c(Region_key, 
                 "Lang_spoken_home_Eng_only_P",
                 "Lang_spoken_home_Oth_Lang_P")) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[variable == "Lang_spoken_home_Eng_only_P", OnlyEnglishSpokenHome := TRUE] %>%
  .[variable == "Lang_spoken_home_Oth_Lang_P", OnlyEnglishSpokenHome := FALSE] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'), 
        select = c(Region_key, 
                   "Lang_spoken_home_Eng_only_F",
                   "Lang_spoken_home_Eng_only_M",
                   "Lang_spoken_home_Oth_Lang_F",
                   "Lang_spoken_home_Oth_Lang_M")) %>%
  melt.data.table(id.vars = Region_key, 
                  value.name = "persons") %>%
  .[variable %pin% "Lang_spoken_home_Eng_only", OnlyEnglishSpokenHome := TRUE] %>%
  .[variable %pin% "Lang_spoken_home_Oth_Lang", OnlyEnglishSpokenHome := FALSE] %>%
  .[variable %pin% "F$", Sex := "F"] %>%
  .[variable %pin% "M$", Sex := "M"] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'),
        select = c(Region_key,
                   "Tot_P_P",
                   "Australian_citizen_P")) %>%
  .[, NAust := Tot_P_P - Australian_citizen_P] %>%
  .[, Tot_P_P := NULL] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[, AustCitizen := TRUE] %>%
  .[variable == "NAust", AustCitizen := FALSE] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```



```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'),
      select = c(Region_key,
                 "Tot_P_F",
                 "Australian_citizen_F",
                 "Tot_P_M",
                 "Australian_citizen_M")) %>%
  .[, NAust_F := Tot_P_F - Australian_citizen_F] %>%
  .[, NAust_M := Tot_P_M - Australian_citizen_M] %>%
  .[, Tot_P_F := NULL] %>%
  .[, Tot_P_M := NULL] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[, AustCitizen := TRUE] %>%
  .[variable %pin% "NAust", AustCitizen := FALSE] %>%
  .[variable %pin% "F$", Sex := "F"] %>%
  .[variable %pin% "M$", Sex := "M"] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'),
      select = c(Region_key,
                 "Age_psns_att_educ_inst_0_4_P",
                 "Age_psns_att_educ_inst_5_14_P", 
                 "Age_psns_att_edu_inst_15_19_P",
                 "Age_psns_att_edu_inst_20_24_P", 
                 "Age_psns_att_edu_inst_25_ov_P")) %>%
  melt.data.table(id.vars = Region_key,
                  variable.name = "AgeStudent",
                  value.name = "students") %>%
  .[, AgeStudent := extract_age(AgeStudent)] %>%
  Mop("students")
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'),
      select = c(Region_key,
                 "Age_psns_att_educ_inst_0_4_F",
                 "Age_psns_att_educ_inst_0_4_M",
                 "Age_psns_att_educ_inst_5_14_F", 
                 "Age_psns_att_educ_inst_5_14_M", 
                 "Age_psns_att_edu_inst_15_19_F",
                 "Age_psns_att_edu_inst_15_19_M",
                 "Age_psns_att_edu_inst_20_24_F", 
                 "Age_psns_att_edu_inst_20_24_M", 
                 "Age_psns_att_edu_inst_25_ov_F",
                 "Age_psns_att_edu_inst_25_ov_M")) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "students") %>%
  .[, AgeStudent := extract_age(variable)] %>%
  .[variable %pin% "F$", Sex := "F"] %>%
  .[variable %pin% "M$", Sex := "M"] %>%
  Mop("students")
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv')) %>%
  .[, .SD, .SDcols = c(Region_key, grep("High_yr_schl_comp_.*_P", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "adults") %>%
  .[, tmp := "Did not go to school"] %>%
  .[variable != "High_yr_schl_comp_D_n_g_sch_P",
    tmp := paste("Year", gsub("^.*Yr_([0-9]{1,2}).*$", "\\1", variable))] %>%
  .[, MaxSchoolingCompleted := factor(tmp, levels = rev(unique(.$tmp)), ordered = TRUE)] %>%
  .[, tmp := NULL] %>%
  Mop("adults")
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv')) %>%
  .[, .SD, .SDcols = c(Region_key, grep("High_yr_schl_comp_.*_[MF]$", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[, tmp := "Did not go to school"] %>%
  .[variable %notin% c("High_yr_schl_comp_D_n_g_sch_F", "High_yr_schl_comp_D_n_g_sch_M"),
    tmp := paste("Year", gsub("^.*Yr_([0-9]{1,2}).*$", "\\1", variable))] %>%
  .[, MaxSchoolingCompleted := factor(tmp, levels = rev(unique(.$tmp)), ordered = TRUE)] %>%
  .[, Sex := gsub("^.*([MF])$", "\\1", variable)] %>%
  .[, tmp := NULL] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'), 
      select = c(Region_key,
                 #"Count_psns_occ_priv_dwgs_M",
                 #"Count_psns_occ_priv_dwgs_F", 
                 "Count_psns_occ_priv_dwgs_P", 
                 #"Count_Persons_other_dwgs_M", 
                 #"Count_Persons_other_dwgs_F", 
                 "Count_Persons_other_dwgs_P")) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[, Dwelling := "Other"] %>%
  .[variable == "Count_psns_occ_priv_dwgs_P", Dwelling := "Private"] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G01_AUS_', Region, '.csv'), 
      select = c(Region_key,
                 "Count_psns_occ_priv_dwgs_M",
                 "Count_psns_occ_priv_dwgs_F", 
                 #"Count_psns_occ_priv_dwgs_P", 
                 "Count_Persons_other_dwgs_M", 
                 "Count_Persons_other_dwgs_F")) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[, Dwelling := "Other"] %>%
  .[variable %pin% "priv_dwgs", Dwelling := "Private"] %>%
  .[, Sex := gsub("^.*([MF])$", "\\1", variable)] %>%
  Mop
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G01_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G01_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```

### G02

```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G02_AUS_', Region, '.csv')) %>%
  .[, .SD, .SDcols = c(Region_key, "Median_tot_prsnl_inc_weekly")] %>%
  setnames("Median_tot_prsnl_inc_weekly", "medianTotalPersonalIncome") %>%
  .[, medianTotalPersonalIncome := medianTotalPersonalIncome * 52L] %>%
  zero2NA %>%
  setcolorder(sort(names(.))) %>%
  set_cols_first(Region_key) %>%
  setorderv(setdiff(names(.), c("persons"))) %>%
  set_cols_last("persons") %>%
  .[] %>%
  Mop("medianTotalPersonalIncome")
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G02_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G02_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
  fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G02_AUS_', Region, '.csv')) %>%
    .[, .SD, .SDcols = c(Region_key, "Median_mortgage_repay_monthly")] %>%
    setnames("Median_mortgage_repay_monthly", "medianMortgageRepayment") %>%
    .[, medianMortgageRepayment := medianMortgageRepayment * 12L] %>%
    zero2NA %>%
    setcolorder(sort(names(.))) %>%
    set_cols_first(Region_key) %>%
    setorderv(setdiff(names(.), c("persons"))) %>%
    set_cols_last("persons") %>%
    .[] %>%
    Mop("medianMortgageRepayment")
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G02_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G02_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G02_AUS_', Region, '.csv')) %>%
  .[, .SD, .SDcols = c(Region_key, "Median_tot_hhd_inc_weekly")] %>%
  setnames("Median_tot_hhd_inc_weekly", "medianTotalHouseholdIncome") %>%
  .[, medianTotalHouseholdIncome := medianTotalHouseholdIncome * 52L] %>%
  zero2NA %>%
  setcolorder(sort(names(.))) %>%
  set_cols_first(Region_key) %>%
  setorderv(setdiff(names(.), c("persons"))) %>%
  set_cols_last("persons") %>%
  .[] %>%
  Mop("medianTotalHouseholdIncome")
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G02_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G02_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G02_AUS_', Region, '.csv')) %>%
  .[, .SD, .SDcols = c(Region_key, "Median_tot_fam_inc_weekly")] %>%
  setnames("Median_tot_fam_inc_weekly", "medianTotalFamilyIncome") %>%
  .[, medianTotalFamilyIncome := medianTotalFamilyIncome * 52L] %>%
  zero2NA %>%
  setcolorder(sort(names(.))) %>%
  set_cols_first(Region_key) %>%
  setorderv(setdiff(names(.), c("persons"))) %>%
  set_cols_last("persons") %>%
  .[] %>%
  Mop("medianTotalFamilyIncome")
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G02_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G02_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```


```r
fread(paste0('./data-raw/data-packs/data/', Region, '/AUST/2016Census_G02_AUS_', Region, '.csv')) %>%
  .[, .SD, .SDcols = c(Region_key, "Median_rent_weekly")] %>%
  setnames("Median_rent_weekly", "medianRent") %>%
  .[, medianRent := medianRent * 52L] %>%
  zero2NA %>%
  setcolorder(sort(names(.))) %>%
  set_cols_first(Region_key) %>%
  setorderv(setdiff(names(.), c("persons"))) %>%
  set_cols_last("persons") %>%
  .[] %>%
  Mop("medianRent")
```

```
## Error in fread(paste0("./data-raw/data-packs/data/", Region, "/AUST/2016Census_G02_AUS_", : File './data-raw/data-packs/data/POA/AUST/2016Census_G02_AUS_POA.csv' does not exist; getwd()=='C:/Users/hughp/Documents/Census2016.DataPack/data-raw'. Include correct full path, or one or more spaces to consider the input a system command.
```

### G03


```r
freadG(3) %>%
  melt.data.table(id.vars = Region_key,
                  variable.factor = FALSE,
                  value.name = "persons") %>%
  .[!(variable %pin% "Tot")] %>%
  .[variable %pin% "(yr|85ov)$"] %>%
  .[, Age := extract_age(variable)] %>%
  .[, ResidenceVar := gsub("_([0-9]+(?:_[0-9]{2})?(?:ov)?)(?:_yr)?$", "", variable, perl = TRUE)] %>%

  .[ResidenceVar %pin% "Count_home?_Census_Nt",
    UsualResidence := "Home"] %>%

  .[ResidenceVar %pin% "VisDiff_SA2_",
    UsualResidence := paste("Visitor from", gsub("VisDiff_SA2_", "", ResidenceVar))] %>%
  .[ResidenceVar %pin% "VisSame",
    UsualResidence := "Visitor same SA2"] %>%
  .[, ResidenceVar := NULL] %>%
  Mop
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

### G04


```r
freadG(4) %>%
  .[, .SD, .SDcols = c(Region_key,
                       grep("yr_[0-9]{1,3}_(over_)?P$", names(.), value = TRUE),
                       "Age_yr_80_84_P",
                       "Age_yr_85_89_P",
                       "Age_yr_90_94_P",
                       "Age_yr_95_99_P",
                       "Age_yr_100_yr_over_P")] %>%
  melt.data.table(id.vars = Region_key,
                  variable.name = "Age.min",
                  variable.factor = FALSE,
                  value.name = "persons") %>%
  .[, Age.min := as.integer(sub("Age_yr_([0-9]{1,3}).*P$", "\\1", Age.min))] %>%
  .[] %>%
  Mop
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(4) %>%
  .[, .SD, .SDcols = c(Region_key,
                       grep("yr_[0-9]{1,3}_(over_)?[MF]$", names(.), value = TRUE),
                       "Age_yr_80_84_F",
                       "Age_yr_80_84_M",
                       "Age_yr_85_89_F",
                       "Age_yr_90_94_M",
                       "Age_yr_95_99_F",
                       "Age_yr_95_99_M",
                       "Age_yr_100_yr_over_F",
                       "Age_yr_100_yr_over_M")] %>%
  melt.data.table(id.vars = Region_key,
                  variable.name = "variable",
                  variable.factor = FALSE,
                  value.name = "persons") %>%
  .[, Age.min := as.integer(gsub("Age_yr_([0-9]{1,3}).*[MF]$", "\\1", variable))] %>%
  .[, Sex := gsub("Age_yr_(?:[0-9]{1,3}).*([MF])$", "\\1", variable, perl = TRUE)] %>%
  Mop
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(5) %>% 
  .[,
    .SD,
    .SDcols = c(Region_key,
                grep("[MF]_[0-9]{2}(ov)?(_[0-9]{2}_yr)?_(Married|Separated|Divorced|Widowed)", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  variable.factor = FALSE,
                  value.name = "responses") %>%
  .[, Age := extract_age(variable)] %>%
  .[, Sex := gsub("^([MF]).*$", "\\1", variable)] %>%
  .[, MaritalStatus := gsub("^.*(Married|Separated|Divorced|Widowed).*$", "\\1", variable, perl = TRUE)] %>%
  Mop("responses")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(6) %>%
  .[, .SD, .SDcols = c(Region_key,
                       names(.)[grepl("^P_", names(.)) & !grepl("Tot", names(.))])] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "adults") %>%
  .[, Age := extract_age(variable)] %>%
  .[, MaritalStatus := gsub("^.*(Marrd_reg_marrge|Married_de_facto|Not_married).*$", "\\1", variable)] %>%
  .[, MaritalStatus := gsub("_", " ", MaritalStatus)] %>%
  .[MaritalStatus == "Marrd reg marrge", Registered := TRUE] %>%
  .[MaritalStatus %pin% "de facto", Registered := FALSE] %>%
  .[MaritalStatus != "Not married", MaritalStatus := "Married"] %>%
  .[] %>%
  Mop("adults")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

## G07


```r
freadG(7) %>%
  .[, .SD, .SDcols = names(.)[nor(grepl("[MF]$", names(.)),
                                  grepl("Tot", names(.)))]] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[, Age := extract_age(variable)] %>%
  .[!grepl("_stat_ns", variable), Indigenous := !grepl("Non_Indig", variable)] %>%
  Mop
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(7) %>%
  .[, .SD, .SDcols = c(Region_key,
                       names(.)[and(grepl("[MF]$", names(.)),
                                    !grepl("Tot", names(.)))])] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[, Age := extract_age(variable)] %>%
  .[, Sex := gsub("^.*([MF])$", "\\1", variable)] %>%
  .[!grepl("_stat_ns", variable), Indigenous := !grepl("Non_Indig", variable)] %>%
  Mop()
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(8) %>%
  .[, .SD, .SDcols = c(Region_key,
                       grep("Tot_Resp", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "responses") %>%
  .[variable != "Tot_P_Tot_Resp"] %>%
  .[!grepl("Ancestry_NS", variable),
    Ancestry := gsub("^([A-Z].*)_(BP|FO|MO).*$", "\\1", variable)] %>%
  .[Ancestry %pin% "Sth.Afri?can", Ancestry := "South African"] %>%
  .[, Ancestry := sub("_Tot_Resp", "", Ancestry)] %>%
  .[, Ancestry := gsub("_", " ", Ancestry)] %>%
  .[, Ancestry := gsub("Aust", "Australian", Ancestry)] %>%
  .[, Ancestry := gsub("Abor", "Aboriginal", Ancestry)] %>%
  Mop("responses")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```



```r
freadG(8) %>%
  .[, .SD, .SDcols = c(ngrep("Tot", names(.)))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "responses") %>%
  .[!grepl("Ancestry_NS", variable),
    Ancestry := gsub("^([A-Z].*)_(BP|FO|MO).*$", "\\1", variable)] %>%
  .[Ancestry %pin% "Sth.Afri?can", Ancestry := "South African"] %>%
  # Join to obtain those with ancestry but whose parents were not
  # born overseas
  .[, Ancestry := sub("_Tot_Resp", "", Ancestry)] %>%
  .[, Ancestry := gsub("_", " ", Ancestry)] %>%
  .[, Ancestry := gsub("Aust", "Australian", Ancestry)] %>%
  .[, Ancestry := gsub("Abor", "Aboriginal", Ancestry)] %>%
  
  # Parents' country of birth
  .[variable %pin% "BP_B_Aus$", FatherBornAus := TRUE] %>%
  .[variable %pin% "BP_B_Aus$", MotherBornAus := TRUE] %>%
  .[variable %pin% "FO_B_OS$", FatherBornAus := FALSE] %>%
  .[variable %pin% "FO_B_OS$", MotherBornAus := TRUE] %>%
  .[variable %pin% "MO_B_OS$", FatherBornAus := TRUE] %>%
  .[variable %pin% "MO_B_OS$", MotherBornAus := FALSE] %>%
  .[variable %pin% "BP_B_OS$", FatherBornAus := FALSE] %>%
  .[variable %pin% "BP_B_OS$", MotherBornAus := FALSE] %>%
  .[] %>%
  Mop("responses")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

## G09


```r
freadG(9) %>%
  .[, .SD, .SDcols = c(Region_key, grep("^P.*(?<!(Tot_))Tot$", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[!grepl("COB_NS", variable), CountryOfBirth := gsub("^P_(.*)_Tot$", "\\1", variable)] %>%
  decode_country %>%
  # mop up missings
  .[, .(persons = sum(persons)), keyby = c(Region_key, "CountryOfBirth")] %>%
  .[] %>%
  Mop
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(9) %>%
  .[, .SD, .SDcols = c(Region_key, grep("^[MF].*(?<!(Tot_))Tot$", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[!grepl("COB_NS", variable), CountryOfBirth := gsub("^[MF]_(.*)_Tot$", "\\1", variable)] %>%
  decode_country %>%
  .[, Sex := "M"] %>%
  .[grepl("^F", variable), Sex := "F"] %>%
  .[] %>%
  .[, .(persons = sum(persons)), keyby = c(Region_key, "CountryOfBirth", "Sex")] %>%
  Mop
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

## G10


```r
freadG(10) %>%
  .[, .SD, .SDcols = union(Region_key, ngrep("Tot", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons_born_overseas") %>%
  .[!grepl("NS$", variable, ignore.case = TRUE), YearOfArrival := as.integer(gsub("^.*_([0-9]+)$", "\\1", variable))] %>%
  .[YearOfArrival < 1900L,
    YearOfArrival := if_else(YearOfArrival < 17L, 2000L, 1000L) + YearOfArrival] %>%
  .[, CountryOfBirth := gsub("(_Be?fo?re)?_[0-9]+(_[0-9]+)?$", "", variable)] %>%
  decode_country %>%
  .[, .(persons_born_overseas = sum(persons_born_overseas)),
    keyby = c(Region_key, "CountryOfBirth", "YearOfArrival")] %>%
  Mop("persons_born_overseas")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G11


```r
freadG(11, na.strings = "..") %>%
  .[, .SD, .SDcols = ngrep("^T|_T", names(.))] %>%
  drop_empty_cols %>%
  melt.data.table(id.vars = Region_key, 
                  value.name = "persons_born_overseas") %>%
  .[, Age := gsub("^A([0-9]{1,2})_?([0-9]{2}|ov).*$", "\\1-\\2", variable)] %>%
  .[, Age := gsub("-ov", "+", Age, fixed = TRUE)] %>%
  .[, Age := factor(Age, levels = unique(.$Age), ordered = TRUE)] %>%
  .[grepl("SEO", variable), SpeaksEnglishOnly := TRUE] %>%
  .[grepl("SOLSE", variable), SpeaksEnglishOnly := FALSE] %>%
  .[grepl("VWW", variable), EnglishProficiency := "1Speaks English well or very well"] %>%
  .[grepl("NWNAA", variable), EnglishProficiency := "2Speaks English not well or not at all"] %>%
  .[order(EnglishProficiency)] %>%
  .[, EnglishProficiency := gsub("^[0-2]", "", EnglishProficiency)] %>%
  .[, EnglishProficiency := factor(EnglishProficiency, levels = unique(.$EnglishProficiency), ordered = TRUE)] %>%
  .[] %>%
  .[!grepl("YNS$", variable), YearOfArrival := 2000L + as.integer(gsub("^.*([0-9]{2})$", "\\1", variable))] %>%
  Mop("persons_born_overseas")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G13 not used


```r
freadG(12) %>%
    .[, .SD, .SDcols = ngrep("^T|_T", names(.))] %>%
    melt.data.table(id.vars = Region_key, 
                    value.name = "children_of_couple_families") %>%
    .[, Age := gsub("^A([0-9]{1,2})_?([0-9]{2}|ov).*$", "\\1-\\2", variable)] %>%
    .[, Age := gsub("-ov", "+", Age, fixed = TRUE)] %>%
    .[, Age := factor(Age, levels = unique(.$Age), ordered = TRUE)] %>%
    .[grepl("SEO", variable), SpeaksEnglishOnly := TRUE] %>%
    .[grepl("SOLSE", variable), SpeaksEnglishOnly := FALSE] %>%
    .[grepl("VWW", variable), EnglishProficiency := "1Speaks English well or very well"] %>%
    .[grepl("NWNAA", variable), EnglishProficiency := "2Speaks English not well or not at all"] %>%
    .[order(EnglishProficiency)] %>%
    .[, EnglishProficiency := gsub("^[0-2]", "", EnglishProficiency)] %>%
    .[, EnglishProficiency := factor(EnglishProficiency, levels = unique(.$EnglishProficiency), ordered = TRUE)] %>%
    .[] %>%
    .[!grepl("YNS$", variable), YearOfArrival := 2000L + as.integer(gsub("^.*([0-9]{2})$", "\\1", variable))] %>%
    Mop("children_of_couple_families")
```


```r
list.files(path = paste0('./data-raw/data-packs/data/', Region, '/AUST/'),
             pattern = paste0('2016Census_G13[A-Z]_AUS_', Region, '\\.csv$'),
             full.names = TRUE) %>%
    lapply(fread, key = Region_key, na.strings = "..") %>%
    lapply(drop_empty_cols) %>%
    Reduce(f = function(X, Y) X[Y]) %>%
    .[, .SD, .SDcols = ngrep("^T|_T", names(.))] 
```

# G14


```r
freadG(14) %>%
  .[, .SD, .SDcols = c(Region_key,
                       intersect(grep("[MF]$", names(.), value = TRUE),
                                 ngrep("Tot", names(.), value = TRUE)))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons") %>%
  .[, Sex := gsub("^.*([MF])$", "\\1", variable)] %>%
  .[!grepl("_ns_", variable),                                                                       Religion :=     gsub("_[MF]", "", variable)] %>%
  .[Religion == "SB_OSB_NRA_NR",                                                                    Religion :=     "No religion"] %>%
  .[Religion %pin% "Christ",                                                                        Denomination := gsub("^Christ[a-z]+y_", "", Religion)] %>%
  .[Religion %pin% "Christ",                                                                        Religion :=     "Christianity"] %>%
  .[Religion %enotin% c("Christianity", "Buddhism", "Hinduism", "Judaism", "Islam", "No religion"), Religion :=     "(Other)"] %>%
  .[variable %pin% "Prsby",                                                                         Denomination := "Presbyterian Reformed"] %>%
  .[variable %pin% "Eastrn.Orthdox",                                                                Denomination := "Eastern Orthodox"] %>%
  .[variable %pin% "Orintal_Orthdx",                                                                Denomination := "Oriental Orthodox"] %>%
  .[variable %pin% "Sevnth.dy",                                                                     Denomination := "Seventh Day Adventist"] %>%
  .[variable %pin% "Othr_Protestnt",                                                                Denomination := "Protestant (Other)"] %>%
  .[variable %pin% "Jehvahs_Witnses",                                                               Denomination := "Jehovah's Witnesses"] %>%
  .[variable %pin% "Othr_Christian",                                                                Denomination := "(Other)"] %>%
  .[variable %pin% "Sikhism",                                                                       Denomination := "Sikhism"] %>%
  .[variable %pin% "Aust_Abor_Trad_Rel",                                                            Denomination := "Australian Aboriginal Traditional"] %>%
  .[variable %pin% "Othr_Reln_Other_reln_groups",                                                   Denomination := "(Other)"] %>%
  .[variable %pin% "SB_OSB_NRA_SB",                                                                 Denomination := "Secular beliefs"] %>%
  .[variable %pin% "SB_OSB_NRA_OSB",                                                                Denomination := "Other spiritual beliefs"] %>%
  .[variable %pin% "SB_OSB_NRA_OSB",                                                                Denomination := "Other spiritual beliefs"] %>%
  .[Denomination %ein% "Lattr_day_Snts",                                                            Denomination := "Latter Day Saints"] %>%
  .[, Denomination := gsub("_", " ", Denomination)] %>%
  .[Denomination %pin% "nfd$", Denomination := NA_character_] %>%
  .[Denomination %pin% "Asyrin", Denomination := "Assyrian Apostolic"] %>%
  Mop(suborder = c("Religion", "Denomination"))
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G15


```r
freadG(15) %>%
  .[, .SD, .SDcols = names(.) %pin% c(Region_key, ".Tot.[MF]", "Pre_school_[MF]", "Type_educanl_institution_ns_[MF]")] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "students") %>%

  .[!(variable %pin% "Type_educanl_institution_ns_[MF]"), EduInstitutionType := gsub("_[MF]$", "", variable)] %>%
  .[variable %pin% "Pre.school",                          EduInstitutionType := "Pre-school"] %>%
  .[variable %pin% "Infants.Primary",                     EduInstitutionType := "Infants/Primary"] %>%
  .[variable %pin% "^Secondary",                          EduInstitutionType := "Secondary"] %>%
  .[variable %pin% "^Tec.Furt",                           EduInstitutionType := "Technical or Further Educational Institution"] %>%
  .[variable %pin% "^Uni",                                EduInstitutionType := "University or other tertiary"] %>%
  .[variable %pin% "^Oth",                                EduInstitutionType := "(Other)"] %>%
  #
  .[, Sex := gsub("^.*([MF])$", "\\1", variable)] %>%
  .[] %>%
  Mop("students")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(15) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  drop_cols(grep("[P]$", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "students") %>%

  .[!(variable %pin% "Type_educanl_institution_ns_[MF]"), EduInstitutionType := gsub("_[MF]$", "", variable)] %>%
  .[variable %pin% "Pre.school",                          EduInstitutionType := "Pre-school"] %>%
  .[variable %pin% "Infa?nts.Prima?ry",                   EduInstitutionType := "Infants/Primary"] %>%
  .[variable %pin% "^Secondary",                          EduInstitutionType := "Secondary"] %>%
  .[variable %pin% "^Tec.Furt",                           EduInstitutionType := "Technical or Further Educational Institution"] %>%
  .[variable %pin% "^Uni",                                EduInstitutionType := "University or other tertiary"] %>%
  .[variable %pin% "^Oth",                                EduInstitutionType := "(Other)"] %>%
  #
  .[variable %pin% c("Primary", "^Secondary"), SchoolSector := gsub("^.*(Government|Catholic|Non_Govt).*$", "\\1", variable)] %>%
  #
  .[variable %pin% c("_Ft_(?!ns)", "_Pt_(?!ns)"), FullTime := variable %pin% "_Ft_"] %>%
  #
  .[variable %pin% c("25_ov", "15_24"), AgedUnder25 := variable %pin% "15_24"] %>%
  #
  .[, Sex := gsub("^.*([MF])$", "\\1", variable)] %>%
  .[] %>%
  Mop("students")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G16

```r
freadG(16) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  drop_cols(grep("^P_", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "adults") %>%
  .[, Age := extract_age(variable)] %>%
  .[, Sex := substr(variable, 0, 1)] %>%
  .[!grepl("schl_ns", variable), MaxSchoolingCompleted := gsub("^[MF]_([A-Za-z0-9]+)_.*$", "\\1", variable)] %>%
  .[,                            MaxSchoolingCompleted := gsub("Y([0-9]+)[eb]", "Year \\1", MaxSchoolingCompleted)] %>%
  .[grepl("Y8b", variable),      MaxSchoolingCompleted := "Year 8 or below"] %>%
  .[grepl("DNGTS", variable),    MaxSchoolingCompleted := "Did not go to school"] %>%
  .[,                            MaxSchoolingCompleted := factor(MaxSchoolingCompleted, levels = rev(unique(.$MaxSchoolingCompleted)), ordered = TRUE)] %>%
  .[] %>%
  Mop("adults")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G17

```r
freadG(17) %>%
  drop_cols(grep("^P_", names(.), value = TRUE)) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "adults") %>%
  .[, Sex := substr(variable, 0, 1)] %>%
  .[!grepl("PI_NS", variable),                MinIncome := force_double(gsub("^[MF]_([0-9]+)_([0-9]+)_.*$", "\\1", variable))] %>%
  .[!grepl("PI_NS", variable),                MaxIncome := force_double(gsub("^[MF]_([0-9]+)_([0-9]+)_.*$", "\\2", variable))] %>%
  .[grepl("Neg(tve)?_Nil_inco?me", variable), MinIncome := -Inf] %>%
  .[grepl("Neg(tve)?_Nil_inco?me", variable), MaxIncome := 0.0] %>%
  .[grepl("^[FM]_[0-9]+_more", variable),     MaxIncome := Inf] %>%
  .[grepl("^[FM]_[0-9]+_more", variable),     MinIncome := as.double(gsub("^[FM]_([0-9]+)_more.*", "\\1", variable))] %>%
  {
    for (j in c("MaxIncome", "MinIncome")) {
      # 149 -> 150 and annualize
      set(., j = j, value = 52.5 * round(.[[j]], -1))
    }
    .
  } %>%
  
  
  setnames(c("MaxIncome", "MinIncome"), 
           c("IncomeTotPersonal.max", "IncomeTotPersonal.min")) %>%
  # On second thoughts, let's just use the .max
  .[, IncomeTotPersonal.min := NULL] %>%
  
  .[, Age := extract_age(variable)] %>%
  .[] %>%
  Mop("adults")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(17) %>%
  drop_cols(grep("^P_", names(.), value = TRUE)) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "adults") %>%
  .[, Sex := substr(variable, 0, 1)] %>%
  .[!grepl("PI_NS", variable),                MinIncome := force_double(gsub("^[MF]_([0-9]+)_([0-9]+)_.*$", "\\1", variable))] %>%
  .[!grepl("PI_NS", variable),                MaxIncome := force_double(gsub("^[MF]_([0-9]+)_([0-9]+)_.*$", "\\2", variable))] %>%
  .[grepl("Neg(tve)?_Nil_inco?me", variable), MinIncome := -Inf] %>%
  .[grepl("Neg(tve)?_Nil_inco?me", variable), MaxIncome := 0.0] %>%
  .[grepl("^[FM]_[0-9]+_more", variable),     MaxIncome := Inf] %>%
  .[grepl("^[FM]_[0-9]+_more", variable),     MinIncome := as.double(gsub("^[FM]_([0-9]+)_more.*", "\\1", variable))] %>%
  {
    for (j in c("MaxIncome", "MinIncome")) {
      # 149 -> 150 and annualize
      set(., j = j, value = 52.5 * round(.[[j]], -1))
    }
    .
  } %>%
  
  
  setnames(c("MaxIncome", "MinIncome"), 
           c("IncomeTotPersonal.max", "IncomeTotPersonal.min")) %>%
  # On second thoughts, let's just use the .max
  .[, IncomeTotPersonal.max := NULL] %>%
  .[, Age := extract_age(variable)] %>%
  .[] %>%
  Mop("adults")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G18

```r
assign(paste0(Region, "__Age_NeedsAssistance_Sex"), {
  freadG(18) %>%
    drop_cols(grep("Tot", names(.), value = TRUE)) %>%
    drop_cols(grep("^P_", names(.), value = TRUE)) %>%
    melt.data.table(id.vars = Region_key,
                    value.name = "persons") %>%
    .[, Age := extract_age(variable)] %>%
    .[, Sex := substr(variable, 0, 1)] %>%
    .[!grepl("ns$", variable), NeedsAssistance := !grepl("No_need_for", variable)] %>%
    .[] %>%
    Mop
})
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G19


```r
freadG(19) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  drop_cols(grep("^P_", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "adults") %>%
  .[, Age := extract_age(variable)] %>%
  .[, Sex := substr(variable, 0, 1)] %>%
  .[!grepl("ns$", variable), Volunteer := !grepl("N_A_Volunteer$", variable, ignore.case = TRUE)] %>%
  .[] %>%
  Mop("adults")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(20) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  drop_cols(grep("^P_", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "adults") %>%
  .[, Age := extract_age(variable)] %>%
  .[, Sex := substr(variable, 0, 1)] %>%
  .[grepl("DNUDW", variable),                                HoursHousekeeping := "0"] %>%
  .[grepl("DUDW.LT.5", variable),                            HoursHousekeeping := "<5"] %>%
  .[grepl("DUDW.30_h_mo", variable),                         HoursHousekeeping := "30+"] %>%
  .[grepl("^.*DUDW_([0-9]{1,2})_([0-9]{1,2}).*$", variable), HoursHousekeeping := gsub("^.*DUDW_([0-9]{1,2})_([0-9]{1,2}).*$", "\\1-\\2", variable)] %>%
  .[, HoursHousekeeping := factor(HoursHousekeeping,
                                  levels = c("0", "<5", "5-14", "15-29", "30+"),
                                  ordered = TRUE)] %>%
  .[] %>%
  Mop("adults")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


# G20 unpaid disability assistance

```r
freadG(21) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  drop_cols(grep("^P_", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "adults") %>%
  .[, Age := extract_age(variable)] %>%
  .[, Sex := substr(variable, 0, 1)] %>%
  .[!grepl("ns$", variable), ProvidedUnpaidDisabilityAssistance := !grepl("No_unpa", variable)] %>%
  .[] %>%
  Mop("adults")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(22) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  drop_cols(grep("^P_", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "adults") %>%
  .[, Age := extract_age(variable)] %>%
  .[, Sex := substr(variable, 0, 1)] %>%
  .[] %>%
  .[!grepl("_NS$", variable), ProvidedUnpaidChildcare := !grepl("DNPCC$", variable)] %>%
  .[(ProvidedUnpaidChildcare), ForOwnChild := !grepl("Oth_CCO$", variable)] %>%
  .[(ProvidedUnpaidChildcare), ForOtherChild := !grepl("Own_CCO$", variable)] %>%
  .[] %>%
  Mop("adults", suborder = c("ProvidedUnpaidChildcare", "ForOwnChild", "ForOtherChild"))
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G24


```r
freadG(24) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "females") %>%
  .[, Age5yr := extract_age(variable)] %>%
  .[!grepl("(Nne|ns)$", variable), ChildrenEverBorn := as.integer(gsub("^.*brn_([1-6]).*$", "\\1", variable))] %>%
  .[grepl("Nne$", variable),       ChildrenEverBorn := 0L] %>%
  Mop("females")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G25 - Family composition


```r
freadG(25) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  # families
  drop_cols(grep("_F$", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "persons_in_families") %>%
  # Implicit total:
  .[variable != "CF_no_children_P"] %>%
  .[grepl("^CF", variable),    FamilyComposition := "Couple"] %>%
  .[grepl("^OPF", variable),   FamilyComposition := "One parent"] %>%
  .[grepl("^Other", variable), FamilyComposition := "(Other)"] %>%
  .[!grepl("^Other", variable), HasChild := !grepl("no_ch(ild|U15)", variable, ignore.case = TRUE)] %>%
  .[!grepl("^Other", variable), HasDependentStudent := !grepl("no_DS", variable)] %>%
  .[!grepl("^Other", variable), HasNonDependentChild := !grepl("no_NdCh_", variable)] %>%
  .[] %>%
  Mop("persons_in_families")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```



```r
freadG(25) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  # families
  drop_cols(grep("_P$", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "families") %>%
  .[variable != "CF_no_children_F"] %>%
  .[grepl("^CF", variable),     FamilyComposition :=    "Couple"] %>%
  .[grepl("^OPF", variable),    FamilyComposition :=    "One parent"] %>%
  .[grepl("^Other", variable),  FamilyComposition :=    "(Other)"] %>%
  .[!grepl("^Other", variable), HasChild :=             !grepl("no_ch(ild|U15)", variable, ignore.case = TRUE)] %>%
  .[!grepl("^Other", variable), HasDependentStudent :=  !grepl("no_DS", variable)] %>%
  .[!grepl("^Other", variable), HasNonDependentChild := !grepl("no_NdCh_", variable)] %>%
  .[] %>%
  Mop("families")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(26) %>%
  .[, .SD, .SDcols = c(ngrep("Tot", names(.)))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "children") %>%
  .[grepl("^CF", variable),                       FamilyComposition := "Couple"] %>%
  .[grepl("^One_PF", variable),                   FamilyComposition := "One parent"] %>%
  .[grepl("BPBau", variable, ignore.case = TRUE), ParentsBornAus :=    "Both"] %>%
  .[grepl("BPBO", variable),                      ParentsBornAus :=    "Neither"] %>%
  .[grepl("FBO", variable),                       ParentsBornAus :=    "Mother only"] %>%
  .[grepl("MBO", variable),                       ParentsBornAus :=    "Father only"] %>%
  .[, AgeChild := extract_age(variable)] %>%
  .[] %>%
  Mop("children")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(27) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  .[] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "families_with_children") %>%
  .[] %>%
  {
    dot <- .
    metadata27 <- Metadata[grepl("G27", `DataPack file`),
                           .(variable = Short, Long)]
    metadata27[dot, on = "variable", nomatch=0L]
  } %>%
  .[, FamilyComposition := gsub("_", " ", sub("_Families$", "", Long))] %>%
  .[, .SD, .SDcols = c(Region_key, "FamilyComposition", "families_with_children")] %>%
  Mop("families_with_children")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(28) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "families") %>%
  .[variable %pin% "^Neg",            IncomeFamily.max := 0.0] %>%
  .[variable %pin% "^FI",             IncomeFamily.max := 52.5 * (force_double(gsub("^FI_[0-9]+_([0-9]+)_.*$", "\\1", variable)) + 1)] %>%
  .[variable %pin% "^FI_[0-9]+_more", IncomeFamily.max := Inf] %>%
  .[!grepl("Other_fam", variable),    CoupleFamily :=     grepl("cpl_fam", variable)] %>%
  .[grepl("chi?ld$", variable),       HasChildren :=      grepl("with_child", variable)] %>%
  # Coalesce missing values (partial/full)
  .[, .(families = sum(families)),
    keyby = c(Region_key, "CoupleFamily", "HasChildren", "IncomeFamily.max")] %>%
  Mop("families")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(29) %>%
  drop_cols(grep("Tot", names(.), value = TRUE)) %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "households") %>%
  .[variable %pin% "^Neg", IncomeHousehold.max := 0.0] %>%
  .[variable %pin% "^HI", IncomeHousehold.max := 52.5 * (force_double(gsub("^HI_[0-9]+_([0-9]+)_.*$", "\\1", variable)) + 1)] %>%
  .[] %>%
  .[variable %pin% "^HI_[0-9]+_more", IncomeHousehold.max := Inf] %>%
  .[, FamilyHousehold := !grepl("Non_fam", variable, ignore.case = TRUE)] %>%
  .[, .(households = sum(households)),
    keyby = c(Region_key, "FamilyHousehold", "IncomeHousehold.max")] %>%
  Mop("households")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G30 - Motor vehicles


```r
freadG(30) %>%
  drop_col("Total_dwelings") %>%
  drop_col("Num_MVs_per_dweling_Tot") %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "occupied_private_dwellings") %>%
  .[!grepl("_NS", variable), MotorVehicles.min := as.integer(gsub("^.*([0-4]).*$", "\\1", variable))] %>%
  Mop("occupied_private_dwellings")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G31 HouseholdComposition by Number of Persons Usually Resident


```r
freadG(31, na.strings = "..") %>%
  drop_empty_cols %>%
  .[, .SD, .SDcols = ngrep("Tot", names(.))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "occupied_private_dwellings") %>%
  .[, UsualResidents.min := as.integer(sub("^.*([0-9]).*$", "\\1", variable))] %>%
  .[, FamilyHousehold := !grepl("NonFamHhold", variable)] %>%
  Mop("occupied_private_dwellings")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


# G32 - notrun

```r
freadG(32, na.strings = "..") %>%
  drop_empty_cols %>%
  .[, .SD, .SDcols = ngrep("Tot", names(.))]
```


```r
# freadG(33)
```


```r
freadG(34) %>%
  .[, .SD, .SDcols = ngrep("Tot", names(.))] %>%
  .[, .SD, .SDcols = union(Region_key, grep("^..[0-9]", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "occupied_private_dwellings_being_purchased") %>%
  .[grepl("Sep", variable),      DwellingStructure := "Separate house"] %>%
  .[grepl("ro?w.*tc", variable), DwellingStructure := "Semi-detached, row/terrace house, townhouse etc."] %>%
  .[grepl("Fla?t", variable),    DwellingStructure := "Flat/apartment"] %>%
  .[grepl("Other", variable),    DwellingStructure := "(Other)"] %>%
  
  .[, MortgageRepayment.min := 12L * as.integer(sub("^..([0-9]+).*", "\\1", variable))] %>%
  Mop("occupied_private_dwellings_being_purchased")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G35 - Mortgage repayment monthly by family composition


```r
freadG(35) %>%
  .[, .SD, .SDcols = ngrep("Tot", names(.))] %>%
  .[, .SD, .SDcols = c(Region_key, grep("^..[0-9]", names(.), value = TRUE))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "families_in_occupied_private_dwellings_being_purchased") %>%
  .[grepl("CF", variable),   FamilyComposition :=     "Couple family"] %>%
  .[grepl("1PF", variable),  FamilyComposition :=     "One-parent family"] %>%
  .[grepl("OthF", variable), FamilyComposition :=     "(Other)"] %>%
  #
  .[,                        HasChildren :=           !grepl("NC$", variable)] %>%

  .[,                        HasChildrenUnder15 :=     HasChildren & !grepl("NC_und15$", variable)] %>%
  #
  .[,                        MortgageRepayment.min :=  12L * as.integer(sub("^..([0-9]+).*", "\\1", variable))] %>%
  Mop("families_in_occupied_private_dwellings_being_purchased")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G36 - Rent weekly


```r
freadG(36) %>%
  .[, .SD, .SDcols = ngrep("Tot", names(.))] %>%
  .[, .SD, .SDcols = c(Region_key, grep("^..[0-9]", names(.), value = TRUE))] %>%
  # typo:
  setnames("R_650_over_LT_Lld_type_ns", "R_950_over_LT_Lld_type_ns") %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "occupied_private_dwellings_being_rented") %>%
  .[,                                 Rent.min := as.integer(52.5 * as.integer(sub("^..([0-9]+).*$", "\\1", variable)))] %>%
  .[grepl("Real_.*_agent", variable), Landlord := "Real estate agent"] %>%
  .[grepl("auth?$", variable),        Landlord := "State or territory housing authority"] %>%
  .[grepl("Psn.not", variable),       Landlord := "Person not in same household"] %>%
  .[grepl("coop", variable),          Landlord := "Co-op/church group etc"] %>%
  .[grepl("Other", variable),         Landlord := "(Other)"] %>%
  .[] %>%
  Mop("occupied_private_dwellings_being_rented")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G37 - Internet access


```r
freadG(37) %>%
  .[, .SD, .SDcols = ngrep("Tot", names(.))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "occupied_private_dwellings") %>%
  .[!grepl("IC_(not_stated|NS)", variable), InternetAccessedFromDwelling := grepl("^IA", variable)] %>%
  .[grepl("Separate_house", variable),      DwellingStructure :=            "Separate house"] %>%
  .[grepl("SemD", variable),                DwellingStructure :=            "Semi-detached, row/terrace house, townhouse etc."] %>%
  .[grepl("Flat_", variable),               DwellingStructure :=            "Flat/apartment"] %>%
  .[grepl("Other", variable),               DwellingStructure :=            "(Other)"] %>%
  Mop("occupied_private_dwellings")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
freadG(38) %>%
  .[, .SD, .SDcols = ngrep("Tot", names(.))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "occupied_private_dwellings") %>%
  .[variable %pin% "Separate_house",        DwellingStructure :=  "Separate house"] %>%
  .[variable %pin% "^Se_d_r",               DwellingStructure :=  "Semi-detached, row/terrace house, townhouse etc."] %>%
  .[variable %pin% "^Flt",                  DwellingStructure :=  "Flat/apartment"] %>%
  .[variable %pin% "Other",                 DwellingStructure :=  "(Other)"] %>%

  .[variable %pin% "^Flt_apt_At_to_a_hse?", DwellingSubtype :=    "Attached to a house"] %>%
  .[variable %pin% "1_st?_",                DwellingSubtype :=    "1 storey"] %>%
  .[variable %pin% "1_or2",                 DwellingSubtype :=    "1 or 2 storey block"] %>%
  .[variable %pin% "Se_d_r_or_t_h_t_2_st",  DwellingSubtype :=    "2 storeys or more"] %>%
  .[variable %pin% "3_st_bl",               DwellingSubtype :=    "3 storey block"] %>%
  .[variable %pin% "Flt_apt_4",             DwellingSubtype :=    "4 or more storey block"] %>%
  
  # 
  .[!grepl("Nof?B_NS$", variable),           NumberBedrooms.min := sub("^.*Nof?B.([0-9]+).*$", "\\1", variable)] %>%
  .[, NumberBedrooms.min := as.integer(NumberBedrooms.min)] %>%
  .[] %>%
  Mop("occupied_private_dwellings")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```

# G39


```r
freadG(39) %>%
  .[, .SD, .SDcols = c(ngrep("Tot", names(.)))] %>%
  melt.data.table(id.vars = Region_key,
                  value.name = "occupied_private_dwellings") %>%
  .[variable %pin% "^SH",            DwellingStructure := "Separate house"] %>%
  .[variable %pin% "^SDRTHT",        DwellingStructure := "Semi-detached, row/terrace house, townhouse etc."] %>%
  .[variable %pin% "^FoA",           DwellingStructure := "Flat/apartment"] %>%
  .[variable %pin% "^OD",            DwellingStructure := "(Other)"] %>%
  #
  .[variable %pin% "^SDRTHT_1_S",    DwellingSubtype :=   "1 storey"] %>%
  .[variable %pin% "^FoA_1_or_2",    DwellingSubtype :=   "1 or 2 storey block"] %>%
  .[variable %pin% "^FoA_3SB",       DwellingSubtype :=   "3 storey block"] %>%
  .[variable %pin% "^FoA_4moSB",     DwellingSubtype :=   "4 storey block or more"] %>%
  .[variable %pin% "^FoA_Att_to",    DwellingSubtype :=   "Attached to a house"] %>%
  #
  .[variable %pin% "^OD_C_.",        DwellingSubtype :=   "Caravan"] %>%
  .[variable %pin% "^OD_CH_",        DwellingSubtype :=   "Cabin household"] %>%
  .[variable %pin% "^OD_Imp_home_T", DwellingSubtype :=   "Improvised home, tent sleepers"] %>%
  .[variable %pin% "^OD_HorF",       DwellingSubtype :=   "House or flat attached to a shop, office, etc"] %>%
  
  .[variable %pin% "FHs_CF_no_C$",   HouseholdComposition := "Couple family with no children"] %>%
  .[variable %pin% "FHs_CF_C$",      HouseholdComposition := "Couple family with children"] %>%
  .[variable %pin% "FHs_OnePF$",     HouseholdComposition := "One parent family with children"] %>%
  .[variable %pin% "FHs_Oth_fam$",   HouseholdComposition := "Other family"] %>%
  .[variable %pin% "Lone_P_H$",      HouseholdComposition := "Lone-person household"] %>%
  .[variable %pin% "Group_H$",       HouseholdComposition := "Group household"] %>%
  Mop("occupied_private_dwellings")
```

```
## Error in fread(file = file_list[1], logical01 = FALSE, ...): Provided file 'NA' does not exists.
```


```r
FINISH <- Sys.time()
```



```r
# Print side-effect ok
stopifnot(dir.exists("data"))
ced_tbls <- grep(Region, tables()$NAME, value = TRUE)
```

```
## No objects of class data.table exist in .GlobalEnv
```

```r
if (Region == "SA1") {
  provide.dir(data_path <- normalizePath("~/Census2016.DataPack.SA1/data"))
} else {
  if (Region == "SSC") {
    provide.dir(data_path <- normalizePath("~/Census2016.DataPack.SSC/data"))
  } else {
    data_path <- "data"
  }
}

try({
prior_data_size <- 
  lapply(list.files(path = data_path,
                    full.names = TRUE),
         file.info) %>%
  rbindlist %$%
  sum(size) %>%
  divide_by(1024^2) %>%
  round(2)

prior_region_data_size <-
  lapply(list.files(path = data_path,
                    pattern = Region,
                    full.names = TRUE),
         file.info) %>%
  rbindlist %$%
  sum(size) %>%
  divide_by(1024^2) %>%
  round(2)
}, silent = TRUE)
region_dtas <- c(list.files(path = "data/",
                            pattern = Region,
                            full.names = TRUE),
                 list.files(path = file.path("data-raw", "data", Region),
                            pattern = paste0(Region, ".*csv$"),
                            full.names = TRUE))

vapply(region_dtas,
       file.remove,
       logical(1)) %>%
  all %>%
  stopifnot
```

```
## Warning in FUN(X[[i]], ...): cannot remove file 'data/POA', reason
## 'Permission denied'
```

```
## Error: . is not TRUE
```

```r
for (tbl in ced_tbls) {
  save(list = tbl,
       file = file.path(data_path, paste0(tbl, ".rda")),
       compress = "gzip",
       compression_level = 9)
  
  file.csv <- file.path("data-raw", "data", Region, paste0(tbl, ".csv"))
  
  .ced_tbl <- get(tbl)
  fwrite(.ced_tbl, file = file.csv)
  
  switch (ceiling(file.size(file.csv) / (95 * 1024^2)),
          {
            NULL
          },
          {
            DT <- .ced_tbl
            lastv <- .subset2(DT, last(names(DT)))
            if (is.integer(lastv) && min(lastv) == 0L) {
              DT <- DT[lastv > 0L]
            }
            NN <- nrow(DT)
            DT1 <- DT[seq_len(NN %/% 2)]
            DT2 <- DT[-seq_len(NN %/% 2)]
            file.remove(file.csv)
            fwrite(DT1, sub("\\.csv$", "1.csv", file.csv))
            fwrite(DT2, sub("\\.csv$", "2.csv", file.csv))
          },
          {
            DT <- .ced_tbl
            lastv <- .subset2(DT, last(names(DT)))
            if (is.integer(lastv) && min(lastv) == 0L) {
              DT <- DT[lastv > 0L]
            }
            NN <- nrow(DT)
            DT1 <- DT[seq_len(NN %/% 2)]
            DT2 <- DT[-seq_len(NN %/% 2)]
            DT11 <- DT1[seq_len(nrow(DT1) %/% 2)]
            DT12 <- DT1[-seq_len(nrow(DT1) %/% 2)]
            DT21 <- DT2[seq_len(nrow(DT2) %/% 2)]
            DT22 <- DT2[-seq_len(nrow(DT2) %/% 2)]
            stopifnot(nrow(DT11) + nrow(DT12) +
                        nrow(DT21) + nrow(DT22) == nrow(DT))
            file.remove(file.csv)
            fwrite(DT11, sub("\\.csv$", "11.csv", file.csv))
            fwrite(DT12, sub("\\.csv$", "12.csv", file.csv))
            fwrite(DT21, sub("\\.csv$", "21.csv", file.csv))
            fwrite(DT22, sub("\\.csv$", "22.csv", file.csv))
          })
}

region_dtas <- list.files(path = "data/",
                          pattern = Region,
                          full.names = TRUE)
# tools::resaveRdaFiles(paths = region_dtas)

current_region_data_size <-
  lapply(list.files(path = data_path,
                    pattern = Region,
                    full.names = TRUE),
         file.info) %>%
  rbindlist %$%
  sum(size) %>%
  divide_by(1024^2) %>%
  round(2)

current_data_size <- 
  lapply(list.files(path = data_path,
                    full.names = TRUE),
         file.info) %>%
  rbindlist %$%
  sum(size) %>%
  divide_by(1024^2) %>%
  round(2)

cat("Region:\t", prior_region_data_size, "MB  ===> ", current_region_data_size, "MB")
```

```
## Region:	 0 MB  ===>  0 MB
```

```r
cat("Total: \t", prior_data_size, "MB  ===> ", current_data_size, "MB")
```

```
## Total: 	 0 MB  ===>  0 MB
```
