% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/df2sf.R
\name{df2sf}
\alias{df2sf}
\title{Convert data.frame object into simple features object}
\usage{
df2sf(
  x_coord,
  y_coord,
  input_data = NULL,
  file = NULL,
  n_max = Inf,
  start = 0,
  projection_input = "EPSG:4326",
  zero.policy = FALSE,
  show_removed = FALSE
)
}
\arguments{
\item{x_coord}{Numeric vector with longitude or easting projected coordinates. When \code{input_data} or \code{file} is supplied, can be either column name or numeric vector of the same length as \code{nrow(input_data)}.}

\item{y_coord}{Numeric vector with latitude or northing projected coordinates. Must be equal to the vector length of \code{x_coord}. When \code{input_data} or \code{file} is supplied, can be either column name or numeric vector of the same length as \code{nrow(input_data)}.}

\item{input_data}{Optional data frame object, containing \code{x_coord} and \code{y_coord}. \code{nrow(input_data)} must be equal to the vector length of \code{x_coord}. NOTE: Rows corresponding to non-usable coordinates are removed from the final output.}

\item{file}{Optional path to csv file. Overrides \code{input_data}.}

\item{n_max}{Maximum number of rows to read in \code{file}. Default is \code{Inf}.}

\item{start}{Number of rows to skip in \code{file}. Default is 0 (start on first row).}

\item{projection_input}{Projection string associated with \code{x_coord} and \code{y_coord}. Default is \code{'+proj=longlat'}.}

\item{zero.policy}{If \code{TRUE}, removes rows where corresponding coordinates equals (0,0). Default is \code{FALSE}.}

\item{show_removed}{If \code{TRUE}, returns a vector of indices corresponding to non-usable coordinates. Default is \code{FALSE}.}
}
\value{
If \code{show_removed==FALSE}, returns an \code{sf} object, with rows corresponding to non-usable coordinates removed. If \code{show_removed==TRUE}, returns a list, with an \code{sf} object (\code{Spatial_Coordinates}), and a vector of indices corresponding to non-usable coordinates removed (\code{Removed_Rows}).
}
\description{
Function takes in x-, y-coordinates, and a data.frame of variables (optional) and returns an SFC object
}
\examples{
# Coordinates supplied as vectors
\dontrun{
data(clea_deu2009_df)
out_1 <- df2sf(x_coord=clea_deu2009_df$longitude,y_coord = clea_deu2009_df$latitude)
class(out_1)
plot(out_1$geometry)
}
# Coordinates supplied as column mames
\dontrun{
out_2 <- df2sf(x_coord="longitude",y_coord ="latitude", input_data = clea_deu2009_df)
plot(out_2["geometry"])
}
# Load from external file
\dontrun{
tmp <- tempfile()
write.csv(clea_deu2009_df,file=tmp)
out_3 <- df2sf(x_coord="longitude",y_coord ="latitude", file=tmp)
plot(out_3["geometry"])
}
}
