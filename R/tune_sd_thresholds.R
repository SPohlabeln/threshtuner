#' Interactive standard deviation threshold tuning app
#'
#' Launches a Shiny app for tuning mean ± k * sd thresholds.
#'
#' @param x A `terra::SpatRaster`.
#' @param bands Character vector of band names to tune.
#' @param k Named numeric vector or single numeric value. Initial standard deviation multiplier.
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
#' @return A data.frame with selected `mean`, `sd`, `k`, `lower`, and `upper` values.
#' @export
tune_sd_thresholds <- function(
  x,
  bands,
  k = 2,
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
        "Standard Deviation Threshold Tuning",
        "Tune mean ± k × sd thresholds for one or more bands."
      ),

      shiny::sidebarLayout(
        shiny::sidebarPanel(
          width = 3,

          control_section(
            "Standard deviation factor",

            shiny::tagList(
              lapply(seq_along(bands), function(i) {
                band <- bands[i]

                shiny::tagList(
                  shiny::sliderInput(
                    inputId = paste0("k_", i),
                    label = paste0(band, " k"),
                    min = 0,
                    max = 5,
                    value = round(k[[band]], 4),
                    step = 0.05
                  ),

                  shiny::numericInput(
                    inputId = paste0("k_num_", i),
                    label = paste0(band, " exact k"),
                    value = round(k[[band]], 4),
                    min = 0,
                    max = 20,
                    step = 0.01
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
              "upper: values above mean + k × sd.",
              "lower: values below mean - k × sd.",
              "outside: values outside mean ± k × sd.",
              "inside: values inside mean ± k × sd."
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
              "Use SD thresholds",
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

      # Synchronize k sliders and numeric inputs without feedback loops
      for (i in seq_along(bands)) {
        local({
          ii <- i
          slider_id <- paste0("k_", ii)
          num_id <- paste0("k_num_", ii)

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

      current_k <- shiny::reactive({
        out <- vapply(seq_along(bands), function(i) {
          input[[paste0("k_num_", i)]]
        }, numeric(1))

        names(out) <- bands
        out
      })

      current_params <- shiny::reactive({
        compute_sd_thresholds(
          values = vals,
          bands = bands,
          k = current_k()
        )
      })

      current_mask <- shiny::reactive({
        mask_sd_thresholds(
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
            ": mean = ", round(params[band, "mean"], 4),
            ", sd = ", round(params[band, "sd"], 4),
            ", lower = ", round(params[band, "lower"], 4),
            ", upper = ", round(params[band, "upper"], 4)
          )
        }, character(1))

        paste(lines, collapse = "\n")
      })

      output$mask_info <- shiny::renderText({
        frac <- mask_fraction(current_mask())
        paste0(round(frac * 100, 2), "%")
      })

      output$hist_plot <- shiny::renderPlot({
        plot_sd_threshold_hist(
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
            main = "RGB + SD mask"
          )
        } else {
          terra::plot(
            current_mask(),
            main = "SD mask",
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