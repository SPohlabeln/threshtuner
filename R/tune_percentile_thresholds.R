#' Interactive percentile threshold tuning app
#'
#' Launches a Shiny app for tuning percentile-based thresholds.
#'
#' @param x A `terra::SpatRaster`.
#' @param bands Character vector of band names to tune.
#' @param lower_p Named numeric vector or single numeric value. Initial lower percentile.
#' @param upper_p Named numeric vector or single numeric value. Initial upper percentile.
#' @param side Which side to mask. One of `"upper"`, `"lower"`, `"outside"`, or `"inside"`.
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
#' @return A data.frame with selected percentile thresholds.
#' @export
tune_percentile_thresholds <- function(
  x,
  bands,
  lower_p = 5,
  upper_p = 95,
  side = c("upper", "lower", "outside", "inside"),
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

  side <- match.arg(side)
  combine <- match.arg(combine, c("and", "or"))
  display_mode <- match.arg(display_mode)

  if (display_mode == "auto") {
    display_mode <- if (all(rgb_bands %in% names(x))) "rgb_overlay" else "mask"
  }

  if (display_mode == "rgb_overlay") {
    if (length(rgb_bands) != 3) {
      stop("`rgb_bands` must have length 3.", call. = FALSE)
    }

    check_bands(x, rgb_bands)
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

  vals <- sample_band_values(
    x,
    bands = bands,
    sample_size = sample_size,
    seed = 1
  )

  app <- shiny::shinyApp(
    ui = shiny::fluidPage(
      theme = app_theme(),
      app_css(),

      app_header(
        "Percentile Threshold Tuning",
        "Tune percentile-based thresholds for one or more bands."
      ),

      shiny::sidebarLayout(
        shiny::sidebarPanel(
          width = 3,

          control_section(
            "Percentiles",

            shiny::tagList(
              lapply(seq_along(bands), function(i) {
                band <- bands[i]

                shiny::tagList(
                  shiny::sliderInput(
                    inputId = paste0("p_", i),
                    label = paste0(band, " percentile range"),
                    min = 0,
                    max = 100,
                    value = c(
                      round(lower_p[[band]], 4),
                      round(upper_p[[band]], 4)
                    ),
                    step = 0.1
                  ),

                  shiny::fluidRow(
                    shiny::column(
                      width = 6,
                      shiny::numericInput(
                        inputId = paste0("lower_p_", i),
                        label = paste0(band, " lower p"),
                        value = round(lower_p[[band]], 4),
                        min = 0,
                        max = 100,
                        step = 0.1
                      )
                    ),
                    shiny::column(
                      width = 6,
                      shiny::numericInput(
                        inputId = paste0("upper_p_", i),
                        label = paste0(band, " upper p"),
                        value = round(upper_p[[band]], 4),
                        min = 0,
                        max = 100,
                        step = 0.1
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
              "side",
              label = "Threshold side",
              choices = c("upper", "lower", "outside", "inside"),
              selected = side
            ),

            shiny::selectInput(
              "combine",
              label = "Combine masks",
              choices = c("and", "or"),
              selected = combine
            ),

            shiny::helpText(
              "upper: values above the upper percentile.",
              "lower: values below the lower percentile.",
              "outside: values below lower or above upper percentile.",
              "inside: values between lower and upper percentile."
            )
          ),

          overlay_controls(
            alpha = alpha,
            overlay_col = overlay_col
          ),

          control_section(
            "Summary",
            shiny::div(
              class = "small-muted",
              shiny::verbatimTextOutput("threshold_info")
            ),
            metric_box("Masked pixels", "mask_info"),
            shiny::textOutput("color_info")
          ),

          shiny::div(
            class = "action-row",
            shiny::actionButton(
              "done",
              "Use percentile thresholds",
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

      # Synchronize percentile sliders and numeric inputs without feedback loops
      for (i in seq_along(bands)) {
        local({
          ii <- i
          slider_id <- paste0("p_", ii)
          lower_id <- paste0("lower_p_", ii)
          upper_id <- paste0("upper_p_", ii)

          shiny::observeEvent(input[[slider_id]], {
            vals_p <- sort(input[[slider_id]])

            lower_val <- shiny::isolate(input[[lower_id]])
            upper_val <- shiny::isolate(input[[upper_id]])

            current_num <- c(lower_val, upper_val)

            if (values_differ(vals_p, current_num)) {
              shiny::updateNumericInput(
                session,
                inputId = lower_id,
                value = round(vals_p[1], 4)
              )

              shiny::updateNumericInput(
                session,
                inputId = upper_id,
                value = round(vals_p[2], 4)
              )
            }
          }, ignoreInit = TRUE)

          shiny::observeEvent(list(input[[lower_id]], input[[upper_id]]), {
            lower_val <- input[[lower_id]]
            upper_val <- input[[upper_id]]

            if (
              is.null(lower_val) || is.null(upper_val) ||
              !is.finite(lower_val) || !is.finite(upper_val)
            ) {
              return(NULL)
            }

            vals_p <- sort(c(lower_val, upper_val))
            vals_p <- pmax(0, pmin(100, vals_p))

            slider_val <- shiny::isolate(sort(input[[slider_id]]))

            if (values_differ(vals_p, slider_val)) {
              shiny::updateSliderInput(
                session,
                inputId = slider_id,
                value = vals_p
              )
            }
          }, ignoreInit = TRUE)
        })
      }

      current_percentiles <- shiny::reactive({
        lower <- vapply(seq_along(bands), function(i) {
          input[[paste0("lower_p_", i)]]
        }, numeric(1))

        upper <- vapply(seq_along(bands), function(i) {
          input[[paste0("upper_p_", i)]]
        }, numeric(1))

        lower <- pmax(0, pmin(100, lower))
        upper <- pmax(0, pmin(100, upper))

        names(lower) <- bands
        names(upper) <- bands

        list(
          lower_p = lower,
          upper_p = upper
        )
      })

      current_params <- shiny::reactive({
        ps <- current_percentiles()

        compute_percentile_thresholds(
          values = vals,
          bands = bands,
          lower_p = ps$lower_p,
          upper_p = ps$upper_p
        )
      })

      current_mask <- shiny::reactive({
        mask_percentile_thresholds(
          x,
          bands = bands,
          params = current_params(),
          side = input$side,
          combine = input$combine
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

      output$threshold_info <- shiny::renderText({
        params <- current_params()

        lines <- vapply(rownames(params), function(band) {
          paste0(
            band,
            ": p", round(params[band, "lower_p"], 2),
            " = ", round(params[band, "lower"], 4),
            ", p", round(params[band, "upper_p"], 2),
            " = ", round(params[band, "upper"], 4)
          )
        }, character(1))

        paste(lines, collapse = "\n")
      })

      output$mask_info <- shiny::renderText({
        frac <- mask_fraction(current_mask())
        paste0(round(frac * 100, 2), "%")
      })

      output$hist_plot <- shiny::renderPlot({
        plot_percentile_threshold_hist(
          values = vals,
          bands = bands,
          params = current_params(),
          side = input$side
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
            main = "RGB + percentile mask"
          )
        } else {
          terra::plot(
            current_mask(),
            main = "Percentile mask",
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
        shiny::stopApp(current_params())
      })
    }
  )

  shiny::runApp(app)
}