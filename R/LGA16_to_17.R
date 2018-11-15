# Rockdale had 109404 persons and Botany Bay had 46654

# LGA__Persons %>%
#   filter(grepl("Bayside", LGA_NAME16) | grepl("Botany", LGA_NAME16) | grepl("Rockdale", LGA_NAME16))

#' Translate LGA 2016 values to LGA 207
#'
#' @param x A data frame with 2 columns, one of which must by LGA_NAME16 and the other should be some
#' kind of numeric value
#' @param method Whether the values should be combined by adding them or by taking an average weighted
#' by the populations of Botany Bay and Rockdale (note that these are not always the appropriate weights,
#' hence this method is only going to be an approximation for values that cannot be summed)
#' @details In late 2016, Botany Bay (C) and Rockdale (C) merged into Bayside (A), in New South Wales.
#' Do not confuse this with Bayside (C), in Victoria... The Census datapack uses Botany Bay and Rockdale.
#' This function gives a crude approximation for Bayside by combining the rows for Botany Bay and Rockdale.
#' It only works with a one dimensional dataset (one row per LGA), although it would be a great extension
#' to let it work with arbitrary numbers of additional dimensions as well (eg age by sex at the same time).
#' @author Peter Ellis peter.ellis2013nz@gmail.com
#' @importFrom dplyr mutate group_by summarise case_when
LGA16_to_17 <- function(x, method = c("sum", "average")){
  #-------check arguments------------------
  if(ncol(x) != 2 | !"LGA_NAME16" %in% names(x)){
    stop("Expected a data frame with 2 columns, one of them LGA_NAME16")
  }

  method <- match.arg(method)

  #--------------------summarise the data-----------
  value_var <- names(x)[names(x) != "LGA_NAME16"]
  names(x)[names(x) == value_var] <- "value"

  x <- dplyr::mutate(x, LGA_NAME17 = ifelse(LGA_NAME16 %in% c("Botany Bay (C)", "Rockdale (C)"),
                                     "Bayside (A)", LGA_NAME16))

  x <- dplyr::group_by(x, LGA_NAME17)

  if(method == "sum"){
    x <- dplyr::summarise(x, value = sum(value))
  }
  if(method == "average"){
    x <- dplyr::mutate(x, w = dplyr::case_when(
      LGA_NAME17 != "Bayside (A)" ~ 1,
      LGA_NAME16 == "Botany Bay (C)" ~ 46654,
      LGA_NAME16 == "Rockdale (C)" ~ 109404
    ))
    x <- dplyr::summarise(x, value = sum(value * w) / sum(w))
    x$w <- NULL
  }

  names(x)[names(x) == "value"] <- value_var
  return(x)
}
