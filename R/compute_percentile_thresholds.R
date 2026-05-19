#' Compute percentile thresholds
#'
#' Computes lower and upper percentile thresholds for one or more bands.
#'
#' @param values A data.frame with sampled raster values.
#' @param bands Character vector of band names.
#' @param lower_p Named numeric vector or single numeric value. Lower percentile.
#' @param upper_p Named numeric vector or single numeric value. Upper percentile.
#'
#' @return A data.frame with columns `lower_p`, `upper_p`, `lower`, and `upper`.
#' @export
compute_percentile_thresholds <- function(
  values,
  bands,
  lower_p = 5,
  upper_p = 95
) {
  if (!is.data.frame(values)) {
    stop("`values` must be a data.frame.", call. = FALSE)
  }

  if (!all(bands %in% names(values))) {
    stop("Not all `bands` were found in `values`.", call. = FALSE)
  }

  if (length(lower_p) == 1) {
    lower_p <- stats::setNames(rep(lower_p, length(bands)), bands)
  }

  if (length(upper_p) == 1) {
    upper_p <- stats::setNames(rep(upper_p, length(bands)), bands)
  }

  if (is.null(names(lower_p))) {
    stop("`lower_p` must be named if it has length > 1.", call. = FALSE)
  }

  if (is.null(names(upper_p))) {
    stop("`upper_p` must be named if it has length > 1.", call. = FALSE)
  }

  missing_lower <- setdiff(bands, names(lower_p))
  missing_upper <- setdiff(bands, names(upper_p))

  if (length(missing_lower) > 0) {
    stop(
      "`lower_p` must contain values for: ",
      paste(missing_lower, collapse = ", "),
      call. = FALSE
    )
  }

  if (length(missing_upper) > 0) {
    stop(
      "`upper_p` must contain values for: ",
      paste(missing_upper, collapse = ", "),
      call. = FALSE
    )
  }

  out <- data.frame(
    lower_p = rep(NA_real_, length(bands)),
    upper_p = rep(NA_real_, length(bands)),
    lower = rep(NA_real_, length(bands)),
    upper = rep(NA_real_, length(bands)),
    row.names = bands
  )

  for (band in bands) {
    lp <- lower_p[[band]]
    up <- upper_p[[band]]

    if (
      !is.finite(lp) || !is.finite(up) ||
      lp < 0 || lp > 100 ||
      up < 0 || up > 100
    ) {
      stop("Percentiles must be finite values between 0 and 100.", call. = FALSE)
    }

    ps <- sort(c(lp, up))

    lower_val <- stats::quantile(
      values[[band]],
      probs = ps[1] / 100,
      na.rm = TRUE,
      names = FALSE
    )

    upper_val <- stats::quantile(
      values[[band]],
      probs = ps[2] / 100,
      na.rm = TRUE,
      names = FALSE
    )

    out[band, "lower_p"] <- ps[1]
    out[band, "upper_p"] <- ps[2]
    out[band, "lower"] <- lower_val
    out[band, "upper"] <- upper_val
  }

  out
}