#' Plot threshold histograms for raster bands
#'
#' @param values A data.frame of sampled raster values.
#' @param bands Character vector of band names.
#' @param thresholds Named numeric vector of thresholds.
#'
#' @return A ggplot object.
#' @export
plot_band_threshold_hist <- function(
  values,
  bands,
  thresholds
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package `ggplot2` is required.", call. = FALSE)
  }

  check_thresholds(thresholds, bands)

  vals_long <- stats::reshape(
    values[, bands, drop = FALSE],
    varying = bands,
    v.names = "value",
    timevar = "band",
    times = bands,
    direction = "long"
  )

  vals_long$threshold <- thresholds[vals_long$band]

  ggplot2::ggplot(vals_long, ggplot2::aes(x = .data$value)) +
    ggplot2::geom_histogram(bins = 80) +
    ggplot2::geom_vline(
      ggplot2::aes(xintercept = .data$threshold),
      linewidth = 1
    ) +
    ggplot2::facet_wrap(~ band, scales = "free") +
    ggplot2::theme_bw() +
    ggplot2::labs(
      x = "Value",
      y = "Pixel count"
    )
}