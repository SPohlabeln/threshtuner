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

```r
brightness_mask <- tune_band_thresholds(
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

After clicking **Use thresholds**, the selected settings are returned to R and can be applied reproducibly:

```r
mask <- mask_band_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  thresholds = brightness_mask$thresholds,
  operators = brightness_mask$operators,
  combine = brightness_mask$combine
)
```

The mask can then be inspected again or used in downstream processing:

```r
plot_rgb_mask_fill(
  x,
  mask,
  bands = c("B02", "B03", "B04"),
  overlay_col = "#fffb01",
  alpha = 0.45
)
```

### App controls used in this example

| Control | Purpose |
|---|---|
| Threshold sliders | Adjust thresholds for each selected band |
| Exact value boxes | Enter precise threshold values |
| Operator selectors | Choose `>`, `>=`, `<`, or `<=` for each band |
| Combine masks | Combine band conditions with `and` or `or` |
| Overlay color | Set the mask overlay color |
| Overlay alpha | Set mask transparency |
| Use thresholds | Return selected settings to R |

---

## Installation

```r
# install.packages("remotes")
remotes::install_github("SPohlabeln/threshtuner")
```

---

## Setup

```r
library(terra)
library(threshtuner)

# Example raster with Sentinel-2 style band names
# x should be a terra::SpatRaster
names(x)
#> "B02" "B03" "B04" "B08" "B11" "B12"
```

Most examples below use an RGB preview:

```r
rgb_bands <- c("B02", "B03", "B04")
```

---

## Overview of tuning functions

| Function | Purpose | Typical use case |
|---|---|---|
| `tune_band_thresholds()` | Tune one threshold per band or index | Brightness-based ice, snow, or cloud masks |
| `tune_range_thresholds()` | Tune lower and upper limits | NDVI vegetation ranges or valid reflectance intervals |
| `tune_sd_thresholds()` | Tune `mean ± k × sd` thresholds | Detect unusually bright or dark pixels |
| `tune_percentile_thresholds()` | Tune percentile-based thresholds | Scene-adaptive outlier, cloud, or ice masks |

---

## 1. Band threshold tuning

Use `tune_band_thresholds()` when each selected band or index should be compared to one threshold.

### Example: brightness-based ice mask

Bright ice or snow surfaces often show high reflectance in visible bands. A simple first mask can be created by tuning thresholds for blue, green, and red reflectance.

```r
result <- tune_band_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  thresholds = c(B02 = 9000, B03 = 9000, B04 = 9000),
  operators = ">",
  combine = "and",
  display_mode = "rgb_overlay",
  rgb_bands = rgb_bands
)
```

Apply the selected thresholds:

```r
mask <- mask_band_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  thresholds = result$thresholds,
  operators = result$operators,
  combine = result$combine
)
```

### App options

| Option | Description |
|---|---|
| Threshold slider | Adjust the threshold interactively |
| Exact value | Enter a precise threshold value |
| Operator | Choose `>`, `>=`, `<`, or `<=` |
| Combine masks | Use `and` or `or` for multiple bands |
| Overlay alpha | Adjust mask transparency |
| Overlay color | Choose the overlay color |
| Use thresholds | Return selected parameters to R |

---

## 2. Range threshold tuning

Use `tune_range_thresholds()` when pixels should be selected based on a lower and upper limit.

### Example: vegetation mask from NDVI

First, add NDVI to the raster:

```r
x_idx <- add_indices(
  x,
  indices = "NDVI",
  bands = list(
    blue = "B02",
    green = "B03",
    red = "B04",
    nir = "B08",
    swir1 = "B11",
    swir2 = "B12"
  )
)
```

Then tune an NDVI range:

```r
ranges <- tune_range_thresholds(
  x_idx,
  bands = "NDVI",
  ranges = rbind(
    NDVI = c(min = 0.2, max = 0.8)
  ),
  display_mode = "rgb_overlay",
  rgb_bands = rgb_bands
)
```

Apply the selected range:

```r
mask <- mask_range_thresholds(
  x_idx,
  bands = "NDVI",
  ranges = ranges
)
```

### App options

| Option | Description |
|---|---|
| Range slider | Adjust lower and upper threshold |
| Min / max fields | Enter precise range limits |
| Mask values inside ranges | If checked, pixels inside the range are masked |
| Combine masks | Use `and` or `or` for multiple bands |
| Overlay alpha | Adjust mask transparency |
| Overlay color | Choose the overlay color |
| Use ranges | Return selected ranges to R |

---

## 3. Standard deviation threshold tuning

Use `tune_sd_thresholds()` to create statistical masks based on:

```text
mean ± k × sd
```

This is useful for identifying unusually bright or dark pixels relative to the current scene.

### Example: bright outlier mask

Bright outliers in visible bands may indicate snow, ice, clouds, or other high-reflectance surfaces.

```r
sd_params <- tune_sd_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  k = c(B02 = 2, B03 = 2, B04 = 2),
  side = "upper",
  combine = "and",
  display_mode = "rgb_overlay",
  rgb_bands = rgb_bands
)
```

Apply the selected standard deviation thresholds:

```r
mask <- mask_sd_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  params = sd_params,
  side = "upper",
  combine = "and"
)
```

### App options

| Option | Description |
|---|---|
| `k` slider | Adjust the standard deviation multiplier |
| Exact `k` | Enter a precise multiplier |
| Threshold side | Choose which part of the distribution is masked |
| Combine masks | Use `and` or `or` for multiple bands |
| Overlay alpha | Adjust mask transparency |
| Overlay color | Choose the overlay color |
| Use SD thresholds | Return selected parameters to R |

### Threshold side options

| Side | Masked pixels |
|---|---|
| `upper` | Values above `mean + k × sd` |
| `lower` | Values below `mean - k × sd` |
| `outside` | Values outside `mean ± k × sd` |
| `inside` | Values inside `mean ± k × sd` |

---

## 4. Percentile threshold tuning

Use `tune_percentile_thresholds()` for scene-adaptive thresholds based on image percentiles. This is often more robust than fixed thresholds because values are derived from the current raster distribution.

### Example: upper-percentile brightness mask

```r
p_params <- tune_percentile_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  lower_p = 5,
  upper_p = 95,
  side = "upper",
  combine = "and",
  display_mode = "rgb_overlay",
  rgb_bands = rgb_bands
)
```

Apply the selected percentile thresholds:

```r
mask <- mask_percentile_thresholds(
  x,
  bands = c("B02", "B03", "B04"),
  params = p_params,
  side = "upper",
  combine = "and"
)
```

### Example: low NDVI mask

```r
p_params <- tune_percentile_thresholds(
  x_idx,
  bands = "NDVI",
  lower_p = 10,
  upper_p = 90,
  side = "lower",
  display_mode = "rgb_overlay",
  rgb_bands = rgb_bands
)
```

### App options

| Option | Description |
|---|---|
| Percentile range | Adjust lower and upper percentiles |
| Lower / upper percentile fields | Enter exact percentile values |
| Threshold side | Choose which part of the distribution is masked |
| Combine masks | Use `and` or `or` for multiple bands |
| Overlay alpha | Adjust mask transparency |
| Overlay color | Choose the overlay color |
| Use percentile thresholds | Return selected parameters to R |

### Threshold side options

| Side | Masked pixels |
|---|---|
| `upper` | Values above the upper percentile |
| `lower` | Values below the lower percentile |
| `outside` | Values below lower or above upper percentile |
| `inside` | Values between lower and upper percentile |

---

## RGB overlay preview

All tuning apps can display the mask as a transparent overlay on an RGB image:

```r
display_mode = "rgb_overlay"
rgb_bands = c("B02", "B03", "B04")
```

This helps visually assess whether the selected threshold captures the intended surface.

---

## Spectral indices

`threshtuner` can add common spectral indices before tuning:

```r
x_idx <- add_indices(
  x,
  indices = c("NDVI", "NDWI", "NDSI", "NBR")
)
```

| Index | Formula |
|---|---|
| NDVI | `(NIR - Red) / (NIR + Red)` |
| NDWI | `(Green - NIR) / (Green + NIR)` |
| MNDWI | `(Green - SWIR1) / (Green + SWIR1)` |
| NDSI | `(Green - SWIR1) / (Green + SWIR1)` |
| NBR | `(NIR - SWIR2) / (NIR + SWIR2)` |

---

## Why use `threshtuner`?

Threshold-based masks are simple, transparent, and easy to reproduce, but they are rarely universal. A threshold that works for one image may fail for another because of differences in:

- sensor type,
- reflectance scaling,
- season,
- illumination,
- atmospheric correction,
- land cover,
- study region.

`threshtuner` makes threshold selection more transparent by combining histograms, visual RGB overlays, and reproducible returned parameters.

---

