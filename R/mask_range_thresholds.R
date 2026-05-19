#' Apply range threshold masks
#'
#' Creates a logical mask from one or more raster bands using lower and upper thresholds.
#'
#' @param x A `terra::SpatRaster`.
#' @param bands Character vector of band names.
#' @param ranges A numeric matrix or data.frame with rows named by `bands`
#'   and two columns: `min` and `max`.
#' @param combine How to combine masks if multiple bands are used. Either `"and"` or `"or"`.
#' @param include_bounds Logical. If `TRUE`, values equal to the bounds are included.
#' @param keep_inside Logical. If `TRUE`, values inside the ranges are `TRUE`.
#'   If `FALSE`, values outside the ranges are `TRUE`.
#'
#' @return A logical `terra::SpatRaster`.
#' @export
mask_range_thresholds <- function(
  x,
  bands,
  ranges,
  combine = "and",
  include_bounds = TRUE,
  keep_inside = TRUE
) {
  check_spatraster(x)
  check_bands(x, bands)

  combine <- match.arg(combine, c("and", "or"))

  if (!is.matrix(ranges) && !is.data.frame(ranges)) {
    stop("`ranges` must be a matrix or data.frame.", call. = FALSE)
  }

  ranges <- as.data.frame(ranges)

  if (!all(c("min", "max") %in% names(ranges))) {
    stop("`ranges` must contain columns named `min` and `max`.", call. = FALSE)
  }

  if (is.null(rownames(ranges))) {
    stop("`ranges` must have row names matching `bands`.", call. = FALSE)
  }

  missing_ranges <- setdiff(bands, rownames(ranges))

  if (length(missing_ranges) > 0) {
    stop(
      "`ranges` must contain rows for: ",
      paste(missing_ranges, collapse = ", "),
      call. = FALSE
    )
  }

  ranges <- ranges[bands, c("min", "max"), drop = FALSE]

  masks <- vector("list", length(bands))

  for (i in seq_along(bands)) {
    band <- bands[i]
    r <- x[[band]]

    lo <- min(ranges[band, "min"], ranges[band, "max"], na.rm = TRUE)
    hi <- max(ranges[band, "min"], ranges[band, "max"], na.rm = TRUE)

    if (include_bounds) {
      masks[[i]] <- r >= lo & r <= hi
    } else {
      masks[[i]] <- r > lo & r < hi
    }
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

  if (!keep_inside) {
    out <- !out
  }

  names(out) <- "mask"

  out
}