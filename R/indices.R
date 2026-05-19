#' Compute a normalized difference index
#'
#' @param x A `terra::SpatRaster`.
#' @param band1 Name of first band.
#' @param band2 Name of second band.
#' @param name Name of the output layer.
#'
#' @return A single-layer `terra::SpatRaster`.
#' @export
compute_normalized_difference <- function(
  x,
  band1,
  band2,
  name = "ND"
) {
  check_spatraster(x)
  check_bands(x, c(band1, band2))

  out <- (x[[band1]] - x[[band2]]) / (x[[band1]] + x[[band2]])
  names(out) <- name

  out
}

#' Compute NDVI
#'
#' @param x A `terra::SpatRaster`.
#' @param nir Name of near-infrared band.
#' @param red Name of red band.
#'
#' @return A single-layer `terra::SpatRaster`.
#' @export
compute_ndvi <- function(
  x,
  nir = "B08",
  red = "B04"
) {
  compute_normalized_difference(
    x,
    band1 = nir,
    band2 = red,
    name = "NDVI"
  )
}


#' Compute NDWI
#'
#' McFeeters-style NDWI: `(green - nir) / (green + nir)`.
#'
#' @param x A `terra::SpatRaster`.
#' @param green Name of green band.
#' @param nir Name of near-infrared band.
#'
#' @return A single-layer `terra::SpatRaster`.
#' @export
compute_ndwi <- function(
  x,
  green = "B03",
  nir = "B08"
) {
  compute_normalized_difference(
    x,
    band1 = green,
    band2 = nir,
    name = "NDWI"
  )
}


#' Compute MNDWI
#'
#' Modified NDWI: `(green - swir1) / (green + swir1)`.
#'
#' @param x A `terra::SpatRaster`.
#' @param green Name of green band.
#' @param swir1 Name of SWIR1 band.
#'
#' @return A single-layer `terra::SpatRaster`.
#' @export
compute_mndwi <- function(
  x,
  green = "B03",
  swir1 = "B11"
) {
  compute_normalized_difference(
    x,
    band1 = green,
    band2 = swir1,
    name = "MNDWI"
  )
}


#' Compute NDSI
#'
#' Normalized Difference Snow Index: `(green - swir1) / (green + swir1)`.
#'
#' @param x A `terra::SpatRaster`.
#' @param green Name of green band.
#' @param swir1 Name of SWIR1 band.
#'
#' @return A single-layer `terra::SpatRaster`.
#' @export
compute_ndsi <- function(
  x,
  green = "B03",
  swir1 = "B11"
) {
  compute_normalized_difference(
    x,
    band1 = green,
    band2 = swir1,
    name = "NDSI"
  )
}


#' Compute NBR
#'
#' Normalized Burn Ratio: `(nir - swir2) / (nir + swir2)`.
#'
#' @param x A `terra::SpatRaster`.
#' @param nir Name of near-infrared band.
#' @param swir2 Name of SWIR2 band.
#'
#' @return A single-layer `terra::SpatRaster`.
#' @export
compute_nbr <- function(
  x,
  nir = "B08",
  swir2 = "B12"
) {
  compute_normalized_difference(
    x,
    band1 = nir,
    band2 = swir2,
    name = "NBR"
  )
}

#' Add spectral indices to a raster
#'
#' Computes one or more spectral indices and appends them as new layers.
#'
#' @param x A `terra::SpatRaster`.
#' @param indices Character vector of indices to compute.
#'   Supported values are `"NDVI"`, `"NDWI"`, `"MNDWI"`, `"NDSI"`, `"NBR"`.
#' @param bands Named list defining band names. Supported names are
#'   `blue`, `green`, `red`, `nir`, `swir1`, and `swir2`.
#' @param overwrite Logical. If `FALSE`, existing layers with the same name cause an error.
#'
#' @return A `terra::SpatRaster` with the requested indices appended.
#' @export
add_indices <- function(
  x,
  indices = c("NDVI"),
  bands = list(
    blue = "B02",
    green = "B03",
    red = "B04",
    nir = "B08",
    swir1 = "B11",
    swir2 = "B12"
  ),
  overwrite = FALSE
) {
  check_spatraster(x)

  indices <- toupper(indices)

  supported <- c("NDVI", "NDWI", "MNDWI", "NDSI", "NBR")

  unsupported <- setdiff(indices, supported)

  if (length(unsupported) > 0) {
    stop(
      "Unsupported indices: ",
      paste(unsupported, collapse = ", "),
      ". Supported indices are: ",
      paste(supported, collapse = ", "),
      call. = FALSE
    )
  }

  new_layers <- list()

  for (idx in indices) {
    if (idx %in% names(x) && !overwrite) {
      stop(
        "Layer `", idx, "` already exists in `x`. ",
        "Use `overwrite = TRUE` to replace it.",
        call. = FALSE
      )
    }

    new_layers[[idx]] <- switch(
      idx,
      "NDVI" = compute_ndvi(
        x,
        nir = bands$nir,
        red = bands$red
      ),
      "NDWI" = compute_ndwi(
        x,
        green = bands$green,
        nir = bands$nir
      ),
      "MNDWI" = compute_mndwi(
        x,
        green = bands$green,
        swir1 = bands$swir1
      ),
      "NDSI" = compute_ndsi(
        x,
        green = bands$green,
        swir1 = bands$swir1
      ),
      "NBR" = compute_nbr(
        x,
        nir = bands$nir,
        swir2 = bands$swir2
      )
    )
  }

  if (overwrite) {
    keep <- !names(x) %in% names(new_layers)
    x <- x[[keep]]
  }

  out <- c(x, terra::rast(new_layers))
  names(out) <- make.unique(names(out))

  out
}