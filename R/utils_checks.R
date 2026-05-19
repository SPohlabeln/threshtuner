check_spatraster <- function(x) {
  if (!inherits(x, "SpatRaster")) {
    stop("`x` must be a terra::SpatRaster.", call. = FALSE)
  }

  invisible(TRUE)
}


check_bands <- function(x, bands) {
  if (!is.character(bands)) {
    stop("`bands` must be a character vector.", call. = FALSE)
  }

  if (length(bands) < 1) {
    stop("`bands` must contain at least one band name.", call. = FALSE)
  }

  missing_bands <- setdiff(bands, names(x))

  if (length(missing_bands) > 0) {
    stop(
      "The following bands were not found in `x`: ",
      paste(missing_bands, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}


check_thresholds <- function(thresholds, bands) {
  if (!is.numeric(thresholds)) {
    stop("`thresholds` must be numeric.", call. = FALSE)
  }

  if (is.null(names(thresholds))) {
    stop("`thresholds` must be a named numeric vector.", call. = FALSE)
  }

  missing_thresholds <- setdiff(bands, names(thresholds))

  if (length(missing_thresholds) > 0) {
    stop(
      "`thresholds` must contain values for: ",
      paste(missing_thresholds, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

is_valid_color <- function(col) {
  tryCatch(
    {
      grDevices::col2rgb(col)
      TRUE
    },
    error = function(e) FALSE
  )
}