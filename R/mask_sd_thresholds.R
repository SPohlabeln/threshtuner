#' Apply standard deviation threshold mask
#'
#' Creates a logical mask from one or more raster bands using mean ± k * sd thresholds.
#'
#' @param x A `terra::SpatRaster`.
#' @param bands Character vector of band names.
#' @param params A data.frame with rows named by `bands` and columns `lower` and `upper`.
#' @param side Which side to mask. One of `"upper"`, `"lower"`, `"outside"`, or `"inside"`.
#' @param combine How to combine masks if multiple bands are used. Either `"and"` or `"or"`.
#'
#' @return A logical `terra::SpatRaster`.
#' @export
mask_sd_thresholds <- function(
  x,
  bands,
  params,
  side = c("upper", "lower", "outside", "inside"),
  combine = "and"
) {
  check_spatraster(x)
  check_bands(x, bands)

  side <- match.arg(side)
  combine <- match.arg(combine, c("and", "or"))

  if (!is.data.frame(params)) {
    params <- as.data.frame(params)
  }

  if (!all(c("lower", "upper") %in% names(params))) {
    stop("`params` must contain columns `lower` and `upper`.", call. = FALSE)
  }

  if (is.null(rownames(params))) {
    stop("`params` must have row names matching `bands`.", call. = FALSE)
  }

  missing_params <- setdiff(bands, rownames(params))

  if (length(missing_params) > 0) {
    stop(
      "`params` must contain rows for: ",
      paste(missing_params, collapse = ", "),
      call. = FALSE
    )
  }

  params <- params[bands, , drop = FALSE]

  masks <- vector("list", length(bands))

  for (i in seq_along(bands)) {
    band <- bands[i]
    r <- x[[band]]

    lower <- params[band, "lower"]
    upper <- params[band, "upper"]

    masks[[i]] <- switch(
      side,
      "upper" = r > upper,
      "lower" = r < lower,
      "outside" = r < lower | r > upper,
      "inside" = r >= lower & r <= upper
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

  names(out) <- "mask"

  out
}