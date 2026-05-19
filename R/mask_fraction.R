#' Calculate mask fraction
#'
#' Calculates the fraction of TRUE pixels in a logical raster mask.
#'
#' @param mask A logical `terra::SpatRaster`.
#'
#' @return Numeric value between 0 and 1.
#' @export
mask_fraction <- function(mask) {
  check_spatraster(mask)

  freq <- terra::freq(mask)

  if (is.null(freq) || nrow(freq) == 0) {
    return(NA_real_)
  }

  true_row <- freq[freq$value == 1, , drop = FALSE]

  if (nrow(true_row) == 0) {
    return(0)
  }

  true_count <- true_row$count
  total_count <- sum(freq$count)

  true_count / total_count
}
