context("LGA16_to_17.R")

test_that("Example", {
  expect_equal(nrow(LGA__medianTotalHouseholdIncome) - 1L,
               # one row less:
               nrow(LGA16_to_17(LGA__medianTotalHouseholdIncome, method = "average")))
  LGA17__Age_Sex <- LGA16_to_17(LGA__Age_Sex, method = "sum")
  expect_equal(sum(LGA__Age_Sex$persons), sum(LGA17__Age_Sex$persons))

  expect_equal(nrow(LGA__medianTotalHouseholdIncome) - 1L,
               # one row less:
               nrow(LGA16_to_17(as.data.frame(LGA__medianTotalHouseholdIncome), method = "average")))
  LGA17__Age_Sex <- LGA16_to_17(LGA__Age_Sex, method = "sum")
  expect_equal(sum(LGA__Age_Sex$persons), sum(LGA17__Age_Sex$persons))

})

test_that("tibble", {
  skip_if_not_installed("tibble")
  expect_equal(nrow(LGA__medianTotalHouseholdIncome) - 1L,
               # one row less:
               nrow(LGA16_to_17(tibble::as_tibble(LGA__medianTotalHouseholdIncome),
                                method = "average")))
  LGA17__Age_Sex <- LGA16_to_17(tibble::as_tibble(LGA__Age_Sex), method = "sum")
  expect_equal(sum(LGA__Age_Sex$persons), sum(LGA17__Age_Sex$persons))

})
