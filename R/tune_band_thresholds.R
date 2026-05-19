#' Interactive band threshold tuning app
#'
#' Launches a Shiny app for interactive tuning of band-wise thresholds.
#'
#' @param x A `terra::SpatRaster`.
#' @param bands Character vector of band names to tune.
#' @param thresholds Named numeric vector with one threshold per band.
#' @param operators Character vector of threshold operators. One of ">", ">=", "<", "<=".
#' @param combine How to combine masks. Either "and" or "or".
#' @param sample_size Number of sampled pixels for histogram display.
#'
#' @return A named numeric vector of selected thresholds if the app is closed with "Use thresholds".
#' @export
tune_band_thresholds <- function(
  x,
  bands,
  thresholds = NULL,
  operators = rep(">", length(bands)),
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
    if (length(rgb_bands) != 3) {
      stop("`rgb_bands` must have length 3.", call. = FALSE)
    }

    check_bands(x, rgb_bands)
  }
  vals <- sample_band_values(
    x,
    bands = bands,
    sample_size = sample_size,
    seed = 1
  )

  mins <- vapply(vals, min, numeric(1), na.rm = TRUE)
  maxs <- vapply(vals, max, numeric(1), na.rm = TRUE)

  if (is.null(thresholds)) {
    thresholds <- stats::setNames(
      (mins + maxs) / 2,
      bands
    )
  }

  check_thresholds(thresholds, bands)

  if (length(operators) == 1) {
    operators <- rep(operators, length(bands))
  }

  if (length(operators) != length(bands)) {
    stop("`operators` must have length 1 or the same length as `bands`.", call. = FALSE)
  }

  if (!all(operators %in% c(">", ">=", "<", "<="))) {
    stop("`operators` must only contain '>', '>=', '<', or '<='.", call. = FALSE)
  }

  app <- shiny::shinyApp(
    ui = shiny::fluidPage(
      theme = app_theme(),
      app_css(),

      app_header(
        "Band Threshold Tuning",
        "Tune one threshold per band and inspect the resulting mask."
      ),

      shiny::sidebarLayout(
        shiny::sidebarPanel(
          width = 3,

          control_section(
            "Thresholds",

            shiny::tagList(
              lapply(seq_along(bands), function(i) {
                band <- bands[i]

                slider <- make_slider_params(
                  data_min = mins[[band]],
                  data_max = maxs[[band]],
                  value = thresholds[[band]],
                  digits = 4
                )

                shiny::tagList(
                  shiny::sliderInput(
                    inputId = paste0("thr_", i),
                    label = paste0(band, " threshold"),
                    min = slider$min,
                    max = slider$max,
                    value = round(thresholds[[band]], 4),
                    step = slider$step
                  ),

                  shiny::fluidRow(
                    shiny::column(
                      width = 6,
                      shiny::numericInput(
                        inputId = paste0("thr_num_", i),
                        label = paste0(band, " exact value"),
                        value = round(thresholds[[band]], 4),
                        min = slider$min,
                        max = slider$max,
                        step = slider$step
                      )
                    ),
                    
                    shiny::column(
                      width = 6,
                      shiny::selectInput(
                        inputId = paste0("op_", i),
                        label = paste0(band, " operator"),
                        choices = c(">", ">=", "<", "<="),
                        selected = operators[[i]]
                      )
                    )
                  )
                )
              })
            ),

            shiny::helpText(
              "The operator defines which pixels are masked for each band:",
              "> masks values above the threshold; < masks values below the threshold.",
              "Use >= or <= to include pixels exactly equal to the threshold."
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

            shiny::helpText(
              "and: all band conditions must be TRUE.",
              "or: at least one band condition must be TRUE."
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
              "Use thresholds",
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

      # Keep sliders and numeric inputs synchronized without feedback loops
      for (i in seq_along(bands)) {
        local({
          ii <- i
          slider_id <- paste0("thr_", ii)
          num_id <- paste0("thr_num_", ii)

          shiny::observeEvent(input[[slider_id]], {
            slider_val <- input[[slider_id]]
            num_val <- shiny::isolate(input[[num_id]])

            if (values_differ(slider_val, num_val)) {
              shiny::updateNumericInput(
                session,
                inputId = num_id,
                value = round(slider_val, 4)
              )
            }
          }, ignoreInit = TRUE)

          shiny::observeEvent(input[[num_id]], {
            num_val <- input[[num_id]]
            slider_val <- shiny::isolate(input[[slider_id]])

            if (is.null(num_val) || !is.finite(num_val)) {
              return(NULL)
            }

            if (values_differ(num_val, slider_val)) {
              shiny::updateSliderInput(
                session,
                inputId = slider_id,
                value = num_val
              )
            }
          }, ignoreInit = TRUE)
        })
      }

      current_thresholds <- shiny::reactive({
        out <- vapply(seq_along(bands), function(i) {
          input[[paste0("thr_num_", i)]]
        }, numeric(1))

        names(out) <- bands
        out
      })

      current_operators <- shiny::reactive({
        out <- vapply(seq_along(bands), function(i) {
          input[[paste0("op_", i)]]
        }, character(1))

        names(out) <- bands
        out
      })

      current_mask <- shiny::reactive({
        mask_band_thresholds(
          x,
          bands = bands,
          thresholds = current_thresholds(),
          operators = current_operators(),
          combine = input$combine,
          keep_non_masked = FALSE
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
        plot_band_threshold_hist(
          values = vals,
          bands = bands,
          thresholds = current_thresholds()
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
            main = "RGB + mask"
          )
        } else {
          terra::plot(
            current_mask(),
            main = "Threshold mask",
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
        shiny::stopApp(current_thresholds())
      })
    }
  )

  shiny::runApp(app)
}