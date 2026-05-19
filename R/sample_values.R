#' Sample raster values
#'
#' Randomly samples values from selected raster bands.
#'
#' @param x A `terra::SpatRaster`.
#' @param bands Character vector of band names.
#' @param sample_size Number of pixels to sample.
#' @param seed Optional random seed.
#'
#' @return A data.frame with sampled values.
#' @export
sample_band_values <- function(
  x,
  bands,
  sample_size = 20000,
  seed = 1
) {
  check_spatraster(x)
  check_bands(x, bands)

  if (!is.null(seed)) {
    set.seed(seed)
  }

  ncell_total <- terra::ncell(x)
  size <- min(sample_size, ncell_total)

  cells <- sample.int(
    ncell_total,
    size = size,
    replace = FALSE
  )

  vals <- terra::extract(
    x[[bands]],
    cells
  )

  vals <- vals[, bands, drop = FALSE]
  vals <- vals[stats::complete.cases(vals), , drop = FALSE]

  vals
}