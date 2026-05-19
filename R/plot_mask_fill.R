#' Plot RGB image with transparent mask overlay
#'
#' @param x A `terra::SpatRaster` with RGB bands.
#' @param mask A single-layer logical `terra::SpatRaster` (`TRUE` = masked).
#' @param bands Character vector of length 3.
#' @param stretch Optional stretch object or settings used by a custom RGB plotter.
#' @param main Plot title.
#' @param alpha Overlay transparency between 0 and 1.
#' @param overlay_col Color used for overlay.
#' @param smooth_viz Logical; if `TRUE`, applies a 3x3 majority filter to the mask
#'   for visualization only.
#' @param smooth_iters Number of smoothing iterations.
#' @param display_agg Optional aggregation factor for faster plotting.
#' @param ... Passed to the RGB plotting function.
#'
#' @return Invisibly `TRUE`.
#' @export
plot_rgb_mask_fill <- function(
  x,
  mask,
  bands = c("B02", "B03", "B04"),
  stretch = NULL,
  main = "RGB with mask overlay",
  alpha = 0.45,
  overlay_col = "#fffb01",
  smooth_viz = FALSE,
  smooth_iters = 1,
  display_agg = NULL,
  ...
) {
  check_spatraster(x)
  check_spatraster(mask)

  if (length(bands) != 3) {
    stop("`bands` must have length 3.", call. = FALSE)
  }

  if (terra::nlyr(mask) != 1) {
    stop("`mask` must be single-layer.", call. = FALSE)
  }

  check_bands(x, bands)

  if (!is.numeric(alpha) || length(alpha) != 1 || alpha < 0 || alpha > 1) {
    stop("`alpha` must be a number between 0 and 1.", call. = FALSE)
  }

  rgb <- x[[bands]]

  # Optional aggregation for faster plotting
  if (!is.null(display_agg)) {
    if (!is.numeric(display_agg) || display_agg < 1) {
      stop("`display_agg` must be NULL or a number >= 1.", call. = FALSE)
    }

    if (display_agg > 1) {
      f <- as.integer(display_agg)

      rgb <- terra::aggregate(rgb, fact = f, fun = "mean", na.rm = TRUE)

      m01 <- mask
      m01[mask] <- 1
      m01[!mask] <- 0
      mask <- terra::aggregate(m01, fact = f, fun = "max", na.rm = TRUE) > 0
    }
  }

  # Optional visualization smoothing
  if (isTRUE(smooth_viz)) {
    m01 <- mask
    m01[mask] <- 1
    m01[!mask] <- 0

    w <- matrix(1, 3, 3)
    iters <- max(1L, as.integer(smooth_iters))

    for (i in seq_len(iters)) {
      m01 <- terra::focal(m01, w = w, fun = "mean", na.rm = TRUE, fillvalue = 0)
      m01 <- m01 > 0.5

      tmp <- m01
      tmp[m01] <- 1
      tmp[!m01] <- 0
      m01 <- tmp
    }

    mask <- m01 > 0
  }

  # Plot RGB
  # If you already have a custom plot_rgb() helper, use it when stretch is provided.
  if (!is.null(stretch) && exists("plot_rgb", mode = "function")) {
    plot_rgb(rgb, stretch = stretch, main = main, ...)
  } else {
    terra::plotRGB(
      rgb,
      r = which(bands == bands[3]), # typically B04
      g = which(bands == bands[2]), # typically B03
      b = which(bands == bands[1]), # typically B02
      stretch = "lin",
      main = main,
      ...
    )
  }

  # Prepare overlay raster: masked pixels = 1, else NA
  overlay <- mask
  overlay[mask] <- 1
  overlay[!mask] <- NA

  col_fill <- grDevices::adjustcolor(overlay_col, alpha.f = alpha)

  terra::plot(
    overlay,
    add = TRUE,
    col = col_fill,
    legend = FALSE
  )

  invisible(TRUE)
}