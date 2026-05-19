nice_number <- function(x, round_value = TRUE) {
  if (!is.finite(x) || x <= 0) {
    return(1)
  }

  exponent <- floor(log10(x))
  fraction <- x / 10^exponent

  if (round_value) {
    nice_fraction <- if (fraction < 1.5) {
      1
    } else if (fraction < 3) {
      2
    } else if (fraction < 7) {
      5
    } else {
      10
    }
  } else {
    nice_fraction <- if (fraction <= 1) {
      1
    } else if (fraction <= 2) {
      2
    } else if (fraction <= 5) {
      5
    } else {
      10
    }
  }

  nice_fraction * 10^exponent
}


make_slider_params <- function(
  data_min,
  data_max,
  value = NULL,
  n_steps = 200,
  digits = 4,
  nice = TRUE
) {
  vals <- c(data_min, data_max, value)
  vals <- vals[is.finite(vals)]

  if (length(vals) == 0) {
    return(list(
      min = 0,
      max = 1,
      step = 0.01
    ))
  }

  raw_min <- min(vals, na.rm = TRUE)
  raw_max <- max(vals, na.rm = TRUE)

  if (raw_min == raw_max) {
    raw_min <- raw_min - 1
    raw_max <- raw_max + 1
  }

  raw_range <- raw_max - raw_min

  if (!isTRUE(nice)) {
    raw_step <- raw_range / n_steps

    if (raw_range > 20) {
      step <- max(1, signif(raw_step, 2))
    } else {
      step <- signif(raw_step, 2)
    }

    if (!is.finite(step) || step <= 0) {
      step <- 0.01
    }

    return(list(
      min = round(raw_min, digits),
      max = round(raw_max, digits),
      step = round(step, digits)
    ))
  }

  target_step <- raw_range / n_steps
  step <- nice_number(target_step, round_value = TRUE)

  # For large integer-like raster values, avoid decimal steps
  if (raw_range > 20 && step < 1) {
    step <- 1
  }

  # For medium/small continuous values, allow .5, .1, .05, .01, etc.
  slider_min <- floor(raw_min / step) * step
  slider_max <- ceiling(raw_max / step) * step

  # Keep min/max readable
  slider_min <- round(slider_min, digits)
  slider_max <- round(slider_max, digits)
  step <- round(step, digits)

  if (!is.finite(step) || step <= 0) {
    step <- if (raw_range <= 2) 0.01 else 1
  }

  list(
    min = slider_min,
    max = slider_max,
    step = step
  )
}

values_differ <- function(x, y, tol = 1e-8) {
  if (is.null(x) || is.null(y)) {
    return(TRUE)
  }

  if (length(x) != length(y)) {
    return(TRUE)
  }

  if (any(is.na(x)) || any(is.na(y))) {
    return(TRUE)
  }

  any(abs(x - y) > tol)
}