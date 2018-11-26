
hasName2 <- function(x, name) {
  chmatch(name, names(x), nomatch = 0L) > 0L
}

hasName <- function(x, name) {
  match(name, names(x), nomatch = 0L) != 0L
}

hasntName <- function(x, name) {
  match(name, names(x), nomatch = 0L) == 0L
}

