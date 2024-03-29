% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/hot_spot.R
\name{hot_spot}
\alias{hot_spot}
\title{Automatically calculate Local G hot spot intensity}
\usage{
hot_spot(
  insert,
  variable = NULL,
  style = "W",
  k = 9,
  remove_missing = TRUE,
  NA_Value = 0,
  include_Moran = FALSE
)
}
\arguments{
\item{insert}{Spatial point, spatial polygon, or single raster layer object. Acceptable formats include \code{sf}, \code{SpatialPolygonsDataFrame}, \code{SpatialPointsDataFrame}, and \code{RasterLayer}.}

\item{variable}{Column name or numeric vector containing the variable from which the local G statistic will be calculated. Must possess a natural scale that orders small and large observations (i.e. number, percentage, ratio and not model residuals).}

\item{style}{Style can take values \code{'W'}, \code{'B'}, \code{'C'}, \code{'U'}, \code{'mimax'}, \code{'S'} (see  \code{\link[spdep]{nb2listw}}). Character string.}

\item{k}{Number of neighbors. Default is 9. Numeric.}

\item{remove_missing}{Whether to calculate statistic without missing values. If \code{FALSE}, substitute value must be supplied to \code{NA_Value}.}

\item{NA_Value}{Substitute for missing values. Default value is 0. Numeric.}

\item{include_Moran}{Calculate local Moran's I statistics. Default is \code{FALSE}. Logical.}
}
\value{
If \code{input} is \code{sf}, \code{SpatialPolygonsDataFrame} or \code{SpatialPointsDataFrame} object, returns \code{sf} object with same geometries and columns as \code{input}, appended with additional column containing Local G estimates (\code{LocalG}). If \code{input} is \code{RasterLayer} object, returns \code{RasterBrick} object containing original values (\code{Original}) and Local G estimates (\code{LocalG}).
}
\description{
Function automatically calculates the Local G hot spot intensity measure for spatial points, spatial polygons, and single raster layers. Uses RANN for efficient nearest neighbor calculation (spatial points and single raster layers only); users can specify the number of neighbors (k). Users can specify the neighborhood style (see spdep::nb2listw) with default being standardized weight matrix (W).
}
\examples{
# Calculate Local G for sf point layer

\dontrun{
data(clea_deu2009_pt)
out_1 <- hot_spot(insert=clea_deu2009_pt, variable = clea_deu2009_pt$to1)
class(out_1)
plot(out_1["LocalG"])
}

# Calculate Local G for sf polygon layer (variable as numeric vector)

\dontrun{
data(clea_deu2009)
out_2 <- hot_spot(insert=clea_deu2009, variable = clea_deu2009$to1)
summary(out_2$LocalG)
plot(out_2["LocalG"])
}

# Calculate Local G for sf polygon layer (variable as column name)

\dontrun{
out_3 <- hot_spot(insert=clea_deu2009, variable = "to1")
summary(out_3$LocalG)
plot(out_3["LocalG"])
}

# Calculate Local G for sf polygon SpatialPolygonsDataFrame (variable as column name)

\dontrun{
out_4 <- hot_spot(insert=as(clea_deu2009,"Spatial"), variable = "to1")
summary(out_4$LocalG)
plot(out_4["LocalG"])
}

# Calculate Local G for RasterLayer
\dontrun{
data(gpw4_deu2010)
out_5 <- hot_spot(insert=gpw4_deu2010)
class(out_5)
terra::plot(out_5$LocalG)
}
}
