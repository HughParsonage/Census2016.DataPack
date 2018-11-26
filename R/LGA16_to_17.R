
#' Approximately aggregate LGA 2016 values to match LGA 2017 names
#'
#' @param x A data frame with 2 or more columns, one of which must by LGA_NAME16 and another should be some
#' kind of numeric value; all other columns must be appropriate for a \code{dplyr::group_by} operation
#' (e.g. categorical variables like age, sex and indigenous status)
#' @param method Whether the values should be combined by adding them (eg for head counts) or by taking
#' an average (e.g. for median income) weighted by the populations of Botany Bay and Rockdale (note that
#' these are not always the appropriate weights,
#' hence this method is only going to be an approximation for values that cannot be summed)
#' @param value_var the value variable that is to be grouped up and summarised. If not provided, this
#' is assumed to be the final column of x.
#' @param return. The class of the returned value. If \code{NULL}, the default,
#' a \code{data.table} is returned if \code{x} is a \code{data.table} and a \code{tibble}
#' is \code{x} is a \code{tibble}.
#' @return A table one row shorter than \code{x} (for each group).
#' @details In late 2016, Botany Bay (C) and Rockdale (C) merged into Bayside (A), in New South Wales.
#' Do not confuse this with Bayside (C), in Victoria... The Census datapack uses Botany Bay and Rockdale.
#' This function gives a crude approximation for Bayside by combining the rows for Botany Bay and Rockdale.
#' It only works with a one dimensional dataset (one row per LGA), although it would be a great extension
#' to let it work with arbitrary numbers of additional dimensions as well (eg age by sex at the same time).
#'
#' Kalamunda (S) was also renamed Kalamunda (C).
#'
#' @section Warning:
#' This is only a crude approximation of the changes to LGAs in 2017.  See
#' \href{http://www.abs.gov.au/ausstats/abs@.nsf/Latestproducts/3218.0Appendix12016-17?opendocument&tabname=Notes&prodno=3218.0&issue=2016-17&num=&view=}{the ABS on changes to LGAs in ASGS 2017}
#' for the real rundown.  In particular, no account is taken by \code{LGA16_to_17} of the shifts between
#' local government areas in Western Australia (eg Bayswater (C) gained from Swan (C), etc). The aim of this
#' function is to provide a work around for people using LGA 2017 boundaries who want at least
#' some approximation of census data.
#' @examples
#' dim(LGA__medianTotalHouseholdIncome)
#'  # one row less:
#' dim(LGA16_to_17(LGA__medianTotalHouseholdIncome, method = "average"))
#'
#' LGA17__Age_Sex <- LGA16_to_17(LGA__Age_Sex)
#'
#' # 22 rows less (11 age groups and 2 sexes):
#' dim(LGA__Age_Sex)
#' dim(LGA17__Age_Sex)
#'
#' # same total number of persons:
#' c(sum(LGA__Age_Sex$persons), sum(LGA17__Age_Sex$persons))
#'
#' # check which names have appeared and disappeared
#' r17 <- unique(LGA__Age_Sex$LGA_NAME16)
#' r16 <- unique(LGA17__Age_Sex$LGA_NAME17)
#' r17[!r17 %in% r16]
#' r16[!r16 %in% r17]
#'
#' @author Peter Ellis
#' @export LGA16_to_17
LGA16_to_17 <- function(x,
                        method = c("sum", "average"),
                        value_var = names(x)[ncol(x)],
                        return. = NULL){
  if (is.data.table(x)) {
    return(LGA16_to_17_data.table(x,
                                  method = method,
                                  value_var = value_var,
                                  return. = return.))
  } else if (!requireNamespace("dplyr", quietly = TRUE)) {
    message("`x` is not a data.table, but package:dplyr is not usable.")
    return(LGA16_to_17_data.table(as.data.table(x),
                                  method = method,
                                  value_var = value_var,
                                  return. = return.))
  }

  #-------check arguments------------------
  if(!"LGA_NAME16" %in% names(x)){
    stop("Expected a data frame with 2 or more columns, one of them LGA_NAME16.")
  }

  if(!value_var %in% names(x)){
    stop(paste("Couldn't find the", value_var, "column in x."))
  }

  method <- match.arg(method)

  #--------------------summarise the data-----------
  value <- NULL
  names(x)[names(x) == value_var] <- "value"

  grouping_vars <- c("LGA_NAME17", names(x)[!names(x) %in% c("value", "LGA_NAME16")])

  x <- dplyr::mutate(x, LGA_NAME17 = case_when(
    LGA_NAME16 %in% c("Botany Bay (C)", "Rockdale (C)") ~ "Bayside (A)",
    LGA_NAME16 == "Kalamunda (S)" ~ "Kalamunda (C)",
    TRUE ~ LGA_NAME16))

  x <- dplyr::group_by_at(x, grouping_vars)

  if(method == "sum"){
    x <- dplyr::summarise(x, value = sum(value))
  }
  if(method == "average"){
    # Rockdale had 109404 persons and Botany Bay had 46654 in 2016
    w <- NULL
    x <- dplyr::mutate(x, w = dplyr::case_when(
      LGA_NAME17 != "Bayside (A)" ~ 1,
      LGA_NAME16 == "Botany Bay (C)" ~ 46654,
      LGA_NAME16 == "Rockdale (C)" ~  109404
    ))
    x <- dplyr::summarise(x, value = sum(value * w) / sum(w))
    x$w <- NULL
  }

  names(x)[names(x) == "value"] <- value_var
  x <- dplyr::ungroup(x)

  if (!is.null(return.)) {
    switch(return.,
           "tibble" = return(x),
           "tbl_df" = return(x),
           "data.table" = return(setDT(x)[]),
           "data.frame" = return(as.data.frame(x)))
  }
  return(x)
}


LGA16_to_17_data.table <- function(x,
                                   method = c("sum", "average"),
                                   value_var = names(x)[ncol(x)],
                                   return. = NULL) {
  method <- match.arg(method)
  stopifnot(is.data.table(x))
  the_colorder <- copy(names(x))
  if (hasntName(x, "LGA_NAME16")) {
    stop("Expected a data frame with 2 or more columns, one of them LGA_NAME16.")
  }
  LGA_NAME16 <- NULL
  if (hasntName(x, value_var)) {
    stop(paste("Couldn't find the", value_var, "column in x."))
  }

  LGA_NAME17 <- NULL
  x[, LGA_NAME17 := LGA_NAME16]
  setindexv(x, "LGA_NAME16")
  x[LGA_NAME16 %in% c("Botany Bay (C)", "Rockdale (C)"), LGA_NAME17 := "Bayside (A)"]
  x[LGA_NAME16 == "Kalamunda (S)", LGA_NAME17 :=  "Kalamunda (C)"]


  switch(method,
         "sum" = {
          x[,
            lapply(.SD, sum),
            by = c(names(x)[names(x) != value_var])]
         },
         "average" = {
           w <- NULL
           if (hasName(x, "w")) {
             .w. <- paste0(names(x), collapse = "")
             setnames(x, "w", .w.)  # will temporarily revert
           } else {
             .w. <- "w"
           }

           x[, w := 1]
           x[LGA_NAME16 == "Botany Bay (C)", w := 0.46654]
           x[LGA_NAME16 == "Rockdale (C)",   w := 1.09404]
           x[, lapply(.SD, weighted.mean, w = w),
             by = c(names(x)[names(x) != value_var])]
           setnames(x, .w., "w")
           if (.w. != "w") {
             hutils::drop_col(x, .w.)
           }
         })
  x[, LGA_NAME16 := NULL]
  setcolorder(x, the_colorder)
  if (!is.null(return.)) {
    if (return. %in% c("tibble", "tbl_df") &&
        !requireNamespace("tibble", quietly = TRUE)) {
      warning("`return. = ", return., ", yet package:tibble not usable. ",
              "Returning a data.table")
      return(x[])
    }
    switch(return.,
           "tibble" = return(tibble::as_tibble(x)),
           "tbl_df" = return(tibble::as_tibble(x)),
           "data.table" = return(setDT(x)[]),
           "data.frame" = return(as.data.frame(x)))
  }
  x[]
}
