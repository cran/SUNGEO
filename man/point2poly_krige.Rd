% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/point2poly_krige.R
\name{point2poly_krige}
\alias{point2poly_krige}
\title{Point-to-polygon interpolation, ordinary and universal Kriging method}
\usage{
point2poly_krige(
  pointz,
  polyz,
  rasterz = NULL,
  yvarz = NULL,
  xvarz = NULL,
  pycno_yvarz = NULL,
  funz = base::mean,
  use_grid = FALSE,
  nz_grid = 25,
  blockz = 0,
  pointz_x_coord = NULL,
  pointz_y_coord = NULL,
  polyz_x_coord = NULL,
  polyz_y_coord = NULL,
  messagez = ""
)
}
\arguments{
\item{pointz}{Source points layer. \code{sf}, \code{sp}, or data frame object.}

\item{polyz}{Destination polygon layer. Must have identical CRS to \code{pointz}. \code{sf}, \code{sp}, or data frame object.}

\item{rasterz}{Source raster layer (or list of raster), with covariate(s) used for universal kriging. Must have identical CRS to \code{polyz}.  \code{RasterLayer} object or list of \code{RasterLayer} objects.}

\item{yvarz}{Names of numeric variable(s) to be interpolated from source points layer to destination polygons. Character string or vector of character strings.}

\item{xvarz}{Names of numeric variable(s) for universal Kriging, in which yvarz is linearly dependent. Character string or vector of character strings.}

\item{pycno_yvarz}{Names of spatially extensive numeric variables for which the pycnophylactic (mass-preserving) property should be preserved. Must be a subset of \code{yvarz}. Character string or vector of character strings.}

\item{funz}{Aggregation function to be applied to values in \code{rasterz} and to interpolated values. Must take as an input a vector \code{x}. Default is mean.  Function.}

\item{use_grid}{Use regular grid as destination layer for interpolation, before aggregating to polygons? Default is FALSE.}

\item{nz_grid}{Number of grid cells in x and y direction (columns, rows). Integer of length 1 or 2. Default is 25. Ignored if use_grid=FALSE.}

\item{blockz}{Size of blocks used for Block Kriging, in meters. Integer of length 1 or 2. Default is 0.}

\item{pointz_x_coord}{Name of numeric variable corresponding to a measure of longitude (Easting) in a data frame object for \code{pointz}. Character string.}

\item{pointz_y_coord}{Name of numeric variable corresponding to a measure of Latitude (Northing) in a data frame object for \code{pointz}. Character string.}

\item{polyz_x_coord}{Name of numeric variable corresponding to a measure of longitude (Easting) in a data frame object for \code{polyz}. Character string.}

\item{polyz_y_coord}{Name of numeric variable corresponding to a measure of Latitude (Northing) in a data frame object for \code{polyz}. Character string.}

\item{messagez}{Optional message to be printed during Kriging estimation. Character string.}
}
\value{
\code{sf} polygon object, with variables from \code{pointz} interpolated to the geometries of \code{polyz}.
}
\description{
Function for interpolating values from a source points layer to an overlapping destination polygon layer, using ordinary and universal kriging with automatic variogram fitting
}
\details{
This function performs Ordinary and Universal Kriging, automatically selecting a variogram model with the smallest residual sum of squares from the sample variogram. See \link[automap]{autofitVariogram}.

Unlike other available point-to-polygon interpolation techniques, this function currently only accepts numeric variables in \code{varz} and does not support interpolation of character strings.
}
\examples{
# Ordinary Kriging with one variable
\dontrun{
data(clea_deu2009)
data(clea_deu2009_pt)
out_1 <- point2poly_krige(pointz = clea_deu2009_pt,
                         polyz = clea_deu2009,
                         yvarz = "to1")
par(mfrow=c(1,2))
plot(clea_deu2009["to1"], key.pos = NULL, reset = FALSE)
plot(out_1["to1.pred"], key.pos = NULL, reset = FALSE)
}

# Ordinary Kriging with multiple variables
\dontrun{
out_2 <- point2poly_krige(pointz = clea_deu2009_pt,
                         polyz = clea_deu2009,
                         yvarz = c("to1","pvs1_margin"))
par(mfrow=c(1,2))
plot(clea_deu2009["pvs1_margin"], key.pos = NULL, reset = FALSE)
plot(out_2["pvs1_margin.pred"], key.pos = NULL, reset = FALSE)
}

# Universal Kriging with one variable from a raster
\dontrun{
data(gpw4_deu2010)
data(clea_deu2009)
data(clea_deu2009_pt)
out_3 <- point2poly_krige(pointz = clea_deu2009_pt,
                         polyz = clea_deu2009,
                         yvarz = "to1",
                         rasterz = gpw4_deu2010)
par(mfrow=c(1,2))
plot(clea_deu2009["to1"], key.pos = NULL, reset = FALSE)
plot(out_3["to1.pred"], key.pos = NULL, reset = FALSE)
}

# Block Kriging with block size of 100 km
\dontrun{
data(clea_deu2009)
data(clea_deu2009_pt)
out_4 <- point2poly_krige(pointz = clea_deu2009_pt,
                         polyz = clea_deu2009,
                         yvarz = "to1",
                         blockz = 100000)
par(mfrow=c(1,2))
plot(clea_deu2009["to1"], key.pos = NULL, reset = FALSE)
plot(out_4["to1.pred"], key.pos = NULL, reset = FALSE)
}
}
