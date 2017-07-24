library(hutils)
library(data.table)
# CED

print_tot <- function(DT) {
  cat(sum(DT$value))
  cat("\n")
  DT
}

UsualResidence_by_Age <-
  fread("./data-raw/data-packs/data/CED/AUST/2016Census_G03_AUS_CED.csv") %>%
  melt.data.table(id.vars = "CED_CODE_2016", variable.factor = FALSE) %>%
  .[!(variable %pin% "Tot")] %>%
  .[variable %pin% "(yr|85ov)$"] %>%
  .[, Age := gsub("^.*?_([0-9]+(?:_[0-9]{2})?(?:ov)?)(?:_yr)?$", "\\1", variable, perl = TRUE)] %>%
  .[, ResidenceVar := gsub("_([0-9]+(?:_[0-9]{2}))?_yr", "", variable, perl = TRUE)] %>%

  .[ResidenceVar %pin% "Count_home?_Census_Nt",
    UsualResidence := "Home"] %>%

  .[ResidenceVar %pin% "VisDiff_SA2_",
    UsualResidence := paste("Visitor different SA2:", gsub("VisDiff_SA2_", "", ResidenceVar))] %>%
  .[ResidenceVar %pin% "VisSame",
    UsualResidence := "Visitor same SA2"] %>%
  .[, .(CED_CODE_2016, Age, UsualResidence, value)] %>%
  setkey(CED_CODE_2016, Age, UsualResidence) %>%
  .[]

fread("./data-raw/data-packs/data/CED/AUST/2016Census_G01_AUS_CED.csv")
fread("./data-raw/data-packs/data/CED/AUST/2016Census_G02_AUS_CED.csv")
