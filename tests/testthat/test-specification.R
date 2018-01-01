context("test-specification.R")

test_that("Up to specification", {
  if (requireNamespace("Census2016.spec", quietly = TRUE)) {
    library(Census2016.spec)
    Census2016.spec::test_check("Census2016.DataPack")
  }

})
