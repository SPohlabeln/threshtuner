#' Compute standard deviation thresholds
#'
#' Computes mean, standard deviation, and lower/upper thresholds for one or more bands.
#'
#' @param values A data.frame with sampled raster values.
#' @param bands Character vector of band names.
#' @param k Named numeric vector or single numeric value. Standard deviation multiplier.
#'
#' @return A data.frame with columns `mean`, `sd`, `k`, `lower`, and `upper`.
#' @export
compute_sd_thresholds <- function(
  values,
  bands,
  k = 2
) {
  if (!is.data.frame(values)) {
    stop("`values` must be a data.frame.", call. = FALSE)
  }

  if (!all(bands %in% names(values))) {
    stop("Not all `bands` were found in `values`.", call. = FALSE)
  }

  if (length(k) == 1) {
    k <- stats::setNames(rep(k, length(bands)), bands)
  }

  if (is.null(names(k))) {
    stop("`k` must be named if it has length > 1.", call. = FALSE)
  }

  missing_k <- setdiff(bands, names(k))

  if (length(missing_k) > 0) {
    stop(
      "`k` must contain values for: ",
      paste(missing_k, collapse = ", "),
      call. = FALSE
    )
  }

  out <- data.frame(
    mean = rep(NA_real_, length(bands)),
    sd = rep(NA_real_, length(bands)),
    k = rep(NA_real_, length(bands)),
    lower = rep(NA_real_, length(bands)),
    upper = rep(NA_real_, length(bands)),
    row.names = bands
  )

  for (band in bands) {
    mu <- mean(values[[band]], na.rm = TRUE)
    sig <- stats::sd(values[[band]], na.rm = TRUE)
    kk <- k[[band]]

    out[band, "mean"] <- mu
    out[band, "sd"] <- sig
    out[band, "k"] <- kk
    out[band, "lower"] <- mu - kk * sig
    out[band, "upper"] <- mu + kk * sig
  }

  out
}
