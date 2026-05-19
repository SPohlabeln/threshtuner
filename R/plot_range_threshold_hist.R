#' Plot histograms with range thresholds
#'
#' @param values A data.frame with sampled raster values.
#' @param bands Character vector of band names.
#' @param ranges A matrix or data.frame with columns `min` and `max`.
#'
#' @return A ggplot object.
#' @export
plot_range_threshold_hist <- function(
  values,
  bands,
  ranges
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package `ggplot2` is required.", call. = FALSE)
  }

  if (!all(bands %in% names(values))) {
    stop("Not all `bands` were found in `values`.", call. = FALSE)
  }

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

  ranges <- ranges[bands, c("min", "max"), drop = FALSE]

  vals_long <- stats::reshape(
    values[, bands, drop = FALSE],
    varying = bands,
    v.names = "value",
    timevar = "band",
    times = bands,
    direction = "long"
  )

  range_df <- data.frame(
    band = rownames(ranges),
    min = ranges$min,
    max = ranges$max,
    row.names = NULL
  )

  vals_long <- merge(
    vals_long,
    range_df,
    by = "band",
    all.x = TRUE
  )

  ggplot2::ggplot(vals_long, ggplot2::aes(x = .data$value)) +
    ggplot2::geom_histogram(bins = 80) +
    ggplot2::geom_vline(
      ggplot2::aes(xintercept = .data$min),
      linewidth = 1
    ) +
    ggplot2::geom_vline(
      ggplot2::aes(xintercept = .data$max),
      linewidth = 1
    ) +
    ggplot2::facet_wrap(~ band, scales = "free") +
    ggplot2::theme_bw() +
    ggplot2::labs(
      x = "Value",
      y = "Pixel count"
    )
}