# threshtuner

## Interactive threshold tuning for raster data

`threshtuner` provides Shiny-based tools for interactively tuning threshold masks for `terra::SpatRaster` objects. It is intended for remote sensing workflows where threshold-based masks are used for ice, snow, water, vegetation, clouds, shadows, brightness anomalies, or index-based filtering.

Thresholds are often predefined in scripts or adopted from literature, but optimal values vary with sensor, region, season, preprocessing level, illumination, and reflectance scaling. `threshtuner` helps inspect threshold behavior visually before applying masks in a reproducible workflow.

Instead of guessing a threshold and repeatedly plotting the result manually, `threshtuner` lets you:

1. inspect value distributions in histograms,
2. adjust thresholds interactively,
3. preview masks as RGB overlays,
4. return selected threshold parameters for reproducible masking.

---

## Overview of tuning functions

| Function | What it tunes | Example applications |
|---|---|---|
| `tune_band_thresholds()` | One threshold per band or index, using `>`, `<`, `>=`, or `<=` | Brightness masks, ice/snow/cloud screening, shadow masks, simple index masks such as `NDVI > 0.3` |
| `tune_range_thresholds()` | Lower and upper limits for one or more bands or indices | NDVI/NDWI/NDSI value ranges, valid reflectance intervals, class-specific index ranges |
| `tune_sd_thresholds()` | Statistical thresholds based on `mean ± k × sd` | Brightness anomalies, dark outliers, spectral outlier filtering, index anomaly masks |
| `tune_percentile_thresholds()` | Scene-adaptive percentile thresholds | Upper-percentile brightness masks, low-index masks, robust outlier screening, adaptive cloud/ice filtering |

---

## Use case example: brightness-based ice masking

`tune_band_thresholds()` can be used to test brightness thresholds across visible bands. In the example below, pixels are masked where the selected RGB-band thresholds are met. This is useful for visually tuning masks for bright ice, snow, clouds, or other high-reflectance surfaces.

The yellow overlay shows the currently masked pixels. Overlay color and transparency can be adjusted directly in the app, making it easier to inspect mask behavior against the underlying RGB image. Operators such as `>`, `>=`, `<`, and `<=` can also be changed interactively for each band.

<img width="1154" height="617" alt="Brightness threshold tuning app showing an RGB image with a transparent mask overlay" src="https://github.com/user-attachments/assets/59456365-a589-4234-9fa0-f462648b651e" />


After clicking **Use thresholds**, the selected settings are returned to R and can be applied reproducibly:

---

# How to use threshtuner

## Installation

```r
# install.packages("remotes")
remotes::install_github("SPohlabeln/threshtuner")
```

```r
library(threshtuner)
library(terra)
```

---

## Add simple spectral indices

For many thresholding workflows, it is useful to work not only with the original raster bands but also with simple spectral indices. `add_indices()` adds commonly used indices to a `terra::SpatRaster`, so they can be tuned in the same way as any other raster layer.
For computing indices, bands must be named like S2 band naming: "B02", "B03", "B04", "B08", "B11", "B12"

```r
x_idx <- add_indices(
  x,
  indices = c("NDVI", "NDWI", "MNDWI", "NDSI", "NBR")
)
```

The added index layers can then be passed to the tuning functions through the `bands` argument.

---

## Main workflow

All tuning functions follow the same basic logic:

```r
# Input example
x <- c(B02, B03, B04, B08, B11, B12)
names(x) <- c("B02", "B03", "B04", "B08", "B11", "B12")

# 1. Tune thresholds interactively
params <- tune_*()

# 2. Apply the selected parameters reproducibly
mask <- mask_*()
```

The Shiny apps are used for visual inspection and parameter selection. The corresponding `mask_*()` functions apply the selected settings without reopening the interactive app.

---

## `tune_band_thresholds()`

`tune_band_thresholds()` tunes one threshold per selected band or index. It is the most direct option for simple rules such as high brightness, low reflectance, or index thresholds.

```r
# Version with commonly used arguments
band_params <- tune_band_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  thresholds = c(B02 = 9000, B03 = 9000, B04 = 9000),
  operators = ">",
  combine = "and",
  display_mode = "rgb_overlay",
  rgb_bands = c("B02", "B03", "B04"),
  overlay_col = "#fffb01",
  alpha = 0.45
)
```

```r
# Minimal version
band_params <- tune_band_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  rgb_bands = c("B02", "B03", "B04")
)
```

After clicking **Use thresholds**, apply the selected values reproducibly:

```r
mask <- mask_band_thresholds(
  x,
  bands = names(band_params),
  thresholds = band_params,
  operators = ">",
  combine = "and"
)
```

Lastly, to visualize the created mask:
```r
plot_rgb_mask_fill(
  x,
  mask,
  bands = c("B02", "B03", "B04"),
  alpha = 0.4,
  overlay_col = "#ff0101"
)
```

**Main arguments**

| Argument               | Description                                         |
| ---------------------- | --------------------------------------------------- |
| `bands`                | Raster layers or indices used for thresholding      |
| `thresholds`           | One threshold value per selected layer              |
| `operators`            | Threshold operator: `>`, `>=`, `<`, or `<=`         |
| `combine`              | Combine multiple layer masks with `"and"` or `"or"` |
| `display_mode`         | Display mode, for example `"rgb_overlay"`           |
| `rgb_bands`            | Bands used for the (RGB) background image             |
| `overlay_col`, `alpha` | Overlay color and transparency for visual preview   |

---

## `tune_range_thresholds()`
<img width="1165" height="457" alt="Screenshot 2026-05-20 012655" src="https://github.com/user-attachments/assets/a208b26b-c7af-4053-bee9-f022613b5a03" />

`tune_range_thresholds()` tunes lower and upper limits for one or more bands or indices. It is useful when values should be selected inside or outside a defined range.

```r
range_params <- tune_range_thresholds(
  x_idx,
  bands = "NDVI",
  ranges = rbind(
    NDVI = c(min = 0.2, max = 0.8)
  ),
  combine = "and",
  display_mode = "rgb_overlay",
  rgb_bands = c("B02", "B03", "B04"),
  overlay_col = "#00ff66",
  alpha = 0.4
)
```

After clicking **Use ranges**, apply the selected range reproducibly:

```r
mask <- mask_range_thresholds(
  x_idx,
  bands = rownames(range_params),
  ranges = range_params,
  combine = "and",
  keep_inside = TRUE
)
```

**Main arguments**

| Argument                    | Description                                              |
| --------------------------- | -------------------------------------------------------- |
| `bands`                     | Raster layers or indices used for range thresholding     |
| `ranges`                    | Lower and upper threshold limits                         |
| `combine`                   | Combine multiple layer masks with `"and"` or `"or"`      |
| `display_mode`, `rgb_bands` | RGB overlay preview settings                             |
| `overlay_col`, `alpha`      | Overlay color and transparency                           |
| `keep_inside`               | TRUE/FALSE option to mask inside/outside range           |

---

## `tune_sd_thresholds()`

`tune_sd_thresholds()` tunes standard deviation thresholds based on `mean ± k × sd`. This is useful when thresholds should adapt to the value distribution of the current raster rather than using fixed absolute values.

```r
sd_params <- tune_sd_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  k = c(B02 = 2, B03 = 2, B04 = 2),
  side = "upper",
  combine = "and",
  display_mode = "rgb_overlay",
  rgb_bands = c("B02", "B03", "B04"),
  overlay_col = "#ff9900",
  alpha = 0.45
)
```

After clicking **Use SD thresholds**, apply the selected parameters reproducibly:

```r
mask <- mask_sd_thresholds(
  x,
  bands = rownames(sd_params),
  params = sd_params,
  side = "upper",
  combine = "and"
)
```

**Main arguments**

| Argument                    | Description                                                                  |
| --------------------------- | ---------------------------------------------------------------------------- |
| `bands`                     | Raster layers or indices used for statistical thresholding                   |
| `k`                         | Standard-deviation multiplier in `mean ± k × sd`                             |
| `side`                      | Threshold side, for example `"upper"`, `"lower"`, `"inside"`, or `"outside"` |
| `combine`                   | Combine multiple layer masks with `"and"` or `"or"`                          |
| `display_mode`, `rgb_bands` | RGB overlay preview settings                                                 |
| `overlay_col`, `alpha`      | Overlay color and transparency                                               |

---

## `tune_percentile_thresholds()`

`tune_percentile_thresholds()` tunes thresholds based on percentiles of the selected raster layers. This is useful for scene-adaptive thresholds where absolute reflectance or index values vary between images.

```r
percentile_params <- tune_percentile_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  probs = c(B02 = 0.95, B03 = 0.95, B04 = 0.95),
  side = "upper",
  combine = "and",
  display_mode = "rgb_overlay",
  rgb_bands = c("B04", "B03", "B02"),
  overlay_col = "#ffff00",
  alpha = 0.45
)

mask <- mask_percentile_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  probs = percentile_params$probs,
  side = percentile_params$side,
  combine = percentile_params$combine
)
```

**Main arguments**

| Argument                    | Description                                                                  |
| --------------------------- | ---------------------------------------------------------------------------- |
| `bands`                     | Raster layers or indices used for percentile thresholding                    |
| `probs`                     | Percentile probabilities, for example `0.05`, `0.5`, or `0.95`               |
| `side`                      | Threshold side, for example `"upper"`, `"lower"`, `"inside"`, or `"outside"` |
| `combine`                   | Combine multiple layer masks with `"and"` or `"or"`                          |
| `display_mode`, `rgb_bands` | RGB overlay preview settings                                                 |
| `overlay_col`, `alpha`      | Overlay color and transparency                                               |

---

## Plot an RGB mask overlay

`plot_rgb_mask_fill()` can be used to inspect a mask outside the Shiny apps or to create quick diagnostic figures.

```r
plot_rgb_mask_fill(
  x,
  mask = mask,
  rgb_bands = c("B04", "B03", "B02"),
  mask_col = "#ffff00",
  alpha = 0.45
)
```

---


