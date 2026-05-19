#' Interactive range threshold tuning app
#'
#' Launches a Shiny app for interactive tuning of lower and upper thresholds
#' for one or more raster bands.
#'
#' @param x A `terra::SpatRaster`.
#' @param bands Character vector of band names to tune.
#' @param ranges Optional matrix or data.frame with columns `min` and `max`
#'   and rows named by `bands`.
#' @param combine How to combine masks if multiple bands are used. Either `"and"` or `"or"`.
#' @param sample_size Number of sampled pixels for histogram display.
#' @param display_mode Display mode. One of `"auto"`, `"mask"`, or `"rgb_overlay"`.
#' @param rgb_bands Character vector of length 3 used for RGB overlay.
#' @param alpha Initial overlay transparency.
#' @param overlay_col Initial overlay color.
#' @param stretch Optional RGB stretch object.
#' @param smooth_viz Logical; smooth mask for visualization only.
#' @param smooth_iters Number of smoothing iterations.
#' @param display_agg Optional aggregation factor for plotting.
#'
#' @return A matrix with selected `min` and `max` values.
#' @export
tune_range_thresholds <- function(
  x,
  bands,
  ranges = NULL,
  combine = "and",
  sample_size = 20000,
  display_mode = c("auto", "mask", "rgb_overlay"),
  rgb_bands = c("B02", "B03", "B04"),
  alpha = 0.45,
  overlay_col = "#fffb01",
  stretch = NULL,
  smooth_viz = FALSE,
  smooth_iters = 1,
  display_agg = NULL
) {
  check_spatraster(x)
  check_bands(x, bands)

  combine <- match.arg(combine, c("and", "or"))
  display_mode <- match.arg(display_mode)

  if (display_mode == "auto") {
    display_mode <- if (all(rgb_bands %in% names(x))) "rgb_overlay" else "mask"
  }

  if (display_mode == "rgb_overlay") {
    check_bands(x, rgb_bands)

    if (length(rgb_bands) != 3) {
      stop("`rgb_bands` must have length 3.", call. = FALSE)
    }
  }

  vals <- sample_band_values(
    x,
    bands = bands,
    sample_size = sample_size,
    seed = 1
  )

  mins <- vapply(vals[, bands, drop = FALSE], min, numeric(1), na.rm = TRUE)
  maxs <- vapply(vals[, bands, drop = FALSE], max, numeric(1), na.rm = TRUE)

  if (is.null(ranges)) {
    q25 <- vapply(
      vals[, bands, drop = FALSE],
      stats::quantile,
      numeric(1),
      probs = 0.25,
      na.rm = TRUE,
      names = FALSE
    )

    q75 <- vapply(
      vals[, bands, drop = FALSE],
      stats::quantile,
      numeric(1),
      probs = 0.75,
      na.rm = TRUE,
      names = FALSE
    )

    ranges <- cbind(
      min = q25,
      max = q75
    )

    rownames(ranges) <- bands
  } else {
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

    ranges <- as.matrix(ranges[bands, c("min", "max"), drop = FALSE])
  }

  app <- shiny::shinyApp(
    ui = shiny::fluidPage(
      theme = app_theme(),
      app_css(),

      app_header(
        "Range Threshold Tuning",
        "Tune lower and upper limits for one or more bands."
      ),

      shiny::sidebarLayout(
        shiny::sidebarPanel(
          width = 3,

          control_section(
            "Ranges",

            shiny::tagList(
              lapply(seq_along(bands), function(i) {
                band <- bands[i]

                slider <- make_slider_params(
                  data_min = mins[[band]],
                  data_max = maxs[[band]],
                  value = c(
                    ranges[band, "min"],
                    ranges[band, "max"]
                  ),
                  digits = 4
                )

                shiny::tagList(
                  shiny::sliderInput(
                    inputId = paste0("range_", i),
                    label = paste0(band, " range"),
                    min = slider$min,
                    max = slider$max,
                    value = c(
                      round(ranges[band, "min"], 4),
                      round(ranges[band, "max"], 4)
                    ),
                    step = slider$step
                  ),

                  shiny::fluidRow(
                    shiny::column(
                      width = 6,
                      shiny::numericInput(
                        inputId = paste0("range_min_", i),
                        label = paste0(band, " min"),
                        value = round(ranges[band, "min"], 4),
                        min = slider$min,
                        max = slider$max,
                        step = slider$step
                      )
                    ),
                    shiny::column(
                      width = 6,
                      shiny::numericInput(
                        inputId = paste0("range_max_", i),
                        label = paste0(band, " max"),
                        value = round(ranges[band, "max"], 4),
                        min = slider$min,
                        max = slider$max,
                        step = slider$step
                      )
                    )
                  )
                )
              })
            )
          ),

          control_section(
            "Mask logic",

            shiny::selectInput(
              "combine",
              label = "Combine masks",
              choices = c("and", "or"),
              selected = combine
            ),

            shiny::checkboxInput(
              "keep_inside",
              label = "Mask values inside ranges",
              value = TRUE
            ),

            shiny::helpText(
              "If enabled, pixels inside the selected range are masked.",
              "If disabled, pixels outside the selected range are masked."
            )
          ),

          overlay_controls(
            alpha = alpha,
            overlay_col = overlay_col
          ),

          control_section(
            "Summary",
            metric_box("Masked pixels", "mask_info"),
            shiny::textOutput("color_info")
          ),

          shiny::div(
            class = "action-row",
            shiny::actionButton(
              "done",
              "Use ranges",
              class = "btn-primary"
            )
          )
        ),

        plot_cards(
          hist_height = "650px",
          mask_height = "650px"
        )
      )
    ),

    server = function(input, output, session) {

      # Keep range sliders and numeric inputs synchronized without feedback loops
      for (i in seq_along(bands)) {
        local({
          ii <- i
          range_id <- paste0("range_", ii)
          min_id <- paste0("range_min_", ii)
          max_id <- paste0("range_max_", ii)

          shiny::observeEvent(input[[range_id]], {
            range_val <- sort(input[[range_id]])

            min_val <- shiny::isolate(input[[min_id]])
            max_val <- shiny::isolate(input[[max_id]])

            current_num <- c(min_val, max_val)

            if (values_differ(range_val, current_num)) {
              shiny::updateNumericInput(
                session,
                inputId = min_id,
                value = round(range_val[1], 4)
              )

              shiny::updateNumericInput(
                session,
                inputId = max_id,
                value = round(range_val[2], 4)
              )
            }
          }, ignoreInit = TRUE)

          shiny::observeEvent(list(input[[min_id]], input[[max_id]]), {
            min_val <- input[[min_id]]
            max_val <- input[[max_id]]

            if (
              is.null(min_val) || is.null(max_val) ||
              !is.finite(min_val) || !is.finite(max_val)
            ) {
              return(NULL)
            }

            num_val <- sort(c(min_val, max_val))
            range_val <- shiny::isolate(sort(input[[range_id]]))

            if (values_differ(num_val, range_val)) {
              shiny::updateSliderInput(
                session,
                inputId = range_id,
                value = num_val
              )
            }
          }, ignoreInit = TRUE)
        })
      }

      current_ranges <- shiny::reactive({
        out <- matrix(
          NA_real_,
          nrow = length(bands),
          ncol = 2,
          dimnames = list(bands, c("min", "max"))
        )

        for (i in seq_along(bands)) {
          band <- bands[i]
          val <- sort(c(
            input[[paste0("range_min_", i)]],
            input[[paste0("range_max_", i)]]
          ))

          out[band, "min"] <- val[1]
          out[band, "max"] <- val[2]
        }

        out
      })

      current_mask <- shiny::reactive({
        mask_range_thresholds(
          x,
          bands = bands,
          ranges = current_ranges(),
          combine = input$combine,
          keep_inside = input$keep_inside
        )
      })

      overlay_col_current <- shiny::reactive({
        col <- input$overlay_col

        if (is_valid_color(col)) {
          col
        } else {
          overlay_col
        }
      })

      output$color_info <- shiny::renderText({
        if (!is_valid_color(input$overlay_col)) {
          paste0("Invalid color. Falling back to ", overlay_col)
        } else {
          ""
        }
      })

      output$mask_info <- shiny::renderText({
        frac <- mask_fraction(current_mask())
        paste0(round(frac * 100, 2), "%")
      })

      output$hist_plot <- shiny::renderPlot({
        plot_range_threshold_hist(
          values = vals,
          bands = bands,
          ranges = current_ranges()
        )
      })

      output$mask_plot <- shiny::renderPlot({
        if (display_mode == "rgb_overlay") {
          plot_rgb_mask_fill(
            x = x,
            mask = current_mask(),
            bands = rgb_bands,
            stretch = stretch,
            alpha = input$overlay_alpha,
            overlay_col = overlay_col_current(),
            smooth_viz = smooth_viz,
            smooth_iters = smooth_iters,
            display_agg = display_agg,
            main = "RGB + range mask"
          )
        } else {
          terra::plot(
            current_mask(),
            main = "Range mask",
            col = c(
              "transparent",
              grDevices::adjustcolor(
                overlay_col_current(),
                alpha.f = input$overlay_alpha
              )
            ),
            legend = FALSE
          )
        }
      })

      shiny::observeEvent(input$done, {
        shiny::stopApp(current_ranges())
      })
    }
  )

  shiny::runApp(app)
}