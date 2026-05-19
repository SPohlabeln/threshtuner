#' Plot histograms with standard deviation thresholds
#'
#' @param values A data.frame with sampled raster values.
#' @param bands Character vector of band names.
#' @param params A data.frame with columns `mean`, `lower`, and `upper`.
#' @param side Which threshold side is currently used.
#'
#' @return A ggplot object.
#' @export
plot_sd_threshold_hist <- function(
  values,
  bands,
  params,
  side = c("upper", "lower", "outside", "inside")
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package `ggplot2` is required.", call. = FALSE)
  }

  side <- match.arg(side)

  if (!all(bands %in% names(values))) {
    stop("Not all `bands` were found in `values`.", call. = FALSE)
  }

  params <- as.data.frame(params)

  if (!all(c("mean", "lower", "upper") %in% names(params))) {
    stop("`params` must contain columns `mean`, `lower`, and `upper`.", call. = FALSE)
  }

  params <- params[bands, , drop = FALSE]

  vals_long <- stats::reshape(
    values[, bands, drop = FALSE],
    varying = bands,
    v.names = "value",
    timevar = "band",
    times = bands,
    direction = "long"
  )

  params_df <- data.frame(
    band = rownames(params),
    mean = params$mean,
    lower = params$lower,
    upper = params$upper,
    row.names = NULL
  )

  vals_long <- merge(
    vals_long,
    params_df,
    by = "band",
    all.x = TRUE
  )

  p <- ggplot2::ggplot(vals_long, ggplot2::aes(x = .data$value)) +
    ggplot2::geom_histogram(bins = 80) +
    ggplot2::geom_vline(
      ggplot2::aes(xintercept = mean),
      linewidth = 0.8,
      linetype = "dashed"
    ) +
    ggplot2::facet_wrap(~ band, scales = "free") +
    ggplot2::theme_bw() +
    ggplot2::labs(
      x = "Value",
      y = "Pixel count"
    )

  if (side %in% c("lower", "outside", "inside")) {
    p <- p +
      ggplot2::geom_vline(
        ggplot2::aes(xintercept = .data$lower),
        linewidth = 1
      )
  }

  if (side %in% c("upper", "outside", "inside")) {
    p <- p +
      ggplot2::geom_vline(
        ggplot2::aes(xintercept = .data$upper),
        linewidth = 1
      )
  }

  p
}