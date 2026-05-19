# Ausgelagerte zentrale Maskierungslogik

#' Apply band-wise threshold mask
#'
#' Creates a logical mask from one or more raster bands and thresholds.
#'
#' @param x A `terra::SpatRaster`.
#' @param bands Character vector of band names.
#' @param thresholds Named numeric vector with one threshold per band.
#' @param operators Character vector of threshold operators. One of ">", ">=", "<", "<=".
#' @param combine How to combine masks. Either "and" or "or".
#' @param keep_non_masked Logical. If `FALSE`, pixels matching the condition are `TRUE`.
#'
#' @return A logical `terra::SpatRaster`.
#' @export
mask_band_thresholds <- function(
  x,
  bands,
  thresholds,
  operators = rep(">", length(bands)),
  combine = "and",
  keep_non_masked = FALSE
) {
  check_spatraster(x)
  check_bands(x, bands)
  check_thresholds(thresholds, bands)

  if (length(operators) == 1) {
    operators <- rep(operators, length(bands))
  }

  if (length(operators) != length(bands)) {
    stop("`operators` must have length 1 or the same length as `bands`.", call. = FALSE)
  }

  if (!all(operators %in% c(">", ">=", "<", "<="))) {
    stop("`operators` must only contain '>', '>=', '<', or '<='.", call. = FALSE)
  }

  combine <- match.arg(combine, c("and", "or"))

  masks <- vector("list", length(bands))

  for (i in seq_along(bands)) {
    band <- bands[i]
    r <- x[[band]]
    thr <- thresholds[[band]]
    op <- operators[i]

    masks[[i]] <- switch(
      op,
      ">"  = r > thr,
      ">=" = r >= thr,
      "<"  = r < thr,
      "<=" = r <= thr
    )
  }

  out <- masks[[1]]

  if (length(masks) > 1) {
    for (i in 2:length(masks)) {
      if (combine == "and") {
        out <- out & masks[[i]]
      } else {
        out <- out | masks[[i]]
      }
    }
  }

  if (keep_non_masked) {
    out <- !out
  }

  names(out) <- "mask"

  out
}