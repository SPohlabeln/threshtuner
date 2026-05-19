app_theme <- function() {
  bslib::bs_theme(
    version = 5,
    bootswatch = "flatly"
  )
}


app_css <- function() {
  shiny::tags$head(
    shiny::tags$style(shiny::HTML("
      .app-header {
        padding: 16px 20px;
        margin-bottom: 20px;
        border-radius: 12px;
        background: #f8f9fa;
        border: 1px solid #e9ecef;
      }

      .app-header h2 {
        margin-top: 0;
        margin-bottom: 6px;
        font-weight: 700;
      }

      .app-header p {
        margin-bottom: 0;
        color: #6c757d;
      }

      .control-section {
        margin-top: 12px;
        margin-bottom: 18px;
      }

      .control-section h4 {
        margin-bottom: 12px;
        font-weight: 650;
      }

      .metric-box {
        padding: 12px 14px;
        border-radius: 10px;
        background: #f1f3f5;
        border: 1px solid #dee2e6;
        margin-bottom: 12px;
      }

      .metric-box span {
        display: block;
        color: #6c757d;
        font-size: 0.9em;
      }

      .metric-box strong {
        font-size: 1.2em;
      }

      .small-muted {
        color: #6c757d;
        font-size: 0.9em;
      }

      .action-row {
        margin-top: 18px;
      }
    "))
  )
}


app_header <- function(title, subtitle = NULL) {
  shiny::div(
    class = "app-header",
    shiny::h2(title),
    if (!is.null(subtitle)) shiny::p(subtitle)
  )
}


metric_box <- function(label, output_id) {
  shiny::div(
    class = "metric-box",
    shiny::span(label),
    shiny::strong(shiny::textOutput(output_id, inline = TRUE))
  )
}


control_section <- function(title, ...) {
  shiny::div(
    class = "control-section",
    shiny::h4(title),
    ...
  )
}


overlay_controls <- function(alpha = 0.45, overlay_col = "#fffb01") {
  control_section(
    "Overlay display",

    shiny::sliderInput(
      "overlay_alpha",
      label = "Overlay alpha",
      min = 0,
      max = 1,
      value = alpha,
      step = 0.05
    ),

    colourpicker::colourInput(
      inputId = "overlay_col",
      label = "Overlay color",
      value = overlay_col,
      showColour = "both",
      palette = "limited"
    )
  )
}


plot_cards <- function(hist_height = "650px", mask_height = "650px") {
  shiny::mainPanel(
    shiny::fluidRow(
      shiny::column(
        width = 6,
        bslib::card(
          bslib::card_header("Histogram"),
          shiny::plotOutput("hist_plot", height = hist_height)
        )
      ),
      shiny::column(
        width = 6,
        bslib::card(
          bslib::card_header("Mask preview"),
          shiny::plotOutput("mask_plot", height = mask_height)
        )
      )
    )
  )
}