#' Automatically convert geographic (degree) to planar coordinates (meters)
#'
#' Function to automatically convert simple feature, spatial and raster objects with geographic coordinates (longitude, latitude / WGS 1984, EPSG:4326) to planar UTM coordinates. If the study region spans multiple UTM zones, defaults to Albers Equal Area.
#'
#' @param x Layer to be reprojected. \code{sf}, \code{sp}, \code{SpatRaster} or \code{RasterLayer} object.
#' @param max_zones Maximum number of UTM zones for single layer. Default is 5. Numeric.
#' @param return_list Return list object instead of reprojected layer (see Details). Default is \code{FALSE}. Logical.
#' @return Re-projected layer. \code{sf} or \code{RasterLayer} object, depending on input.
#'
#' If \code{return_list=TRUE}, returns a list object containing
#' \itemize{
##'  \item "x_out". The re-projected layer. \code{sf} or \code{RasterLayer} object, depending on input.
##'  \item "proj4_best".proj4string of the projection. Character string.
##'  }
#' @details Optimal map projection for the object \code{x} is defined by matching its horizontal extent with that of the 60 UTM zones. If object spans multiple UTM zones, uses either the median zone (if number of zones is equal to or less than \code{max_zones}) or Albers Equal Area projection with median longitude as projection center (if number of zones is greater than \code{max_zones}).
#' @importFrom sf st_bbox st_transform st_coordinates
#' @importFrom terra ext project crds
#' @importFrom stats median
#' @examples
#' # Find a planar projection for an unprojected (WSG 1984) hexagonal grid of Germany
#' \dontrun{
#' data(hex_05_deu)
#' out_1 <- utm_select(hex_05_deu)
#' }
#' # Find a planar projection for a raster
#' \dontrun{
#' data(gpw4_deu2010)
#' out_2 <- utm_select(gpw4_deu2010)
#' }
#' @export

utm_select <- function(x, max_zones=5, return_list=FALSE){

  # Turn off s2 processing
  suppressMessages({
    sf::sf_use_s2(FALSE)
  })

  # Fix sf geometry type
  if(any(grepl("sf", class(x)))){
    if(grepl("GEOMETRY",sf::st_geometry_type(x,by_geometry = FALSE))&any(grepl("POLYGON",sf::st_geometry_type(x)))){
      x <- sf::st_cast(x,"MULTIPOLYGON")
    }
    if(grepl("GEOMETRY",sf::st_geometry_type(x,by_geometry = FALSE))&any(grepl("LINE",sf::st_geometry_type(x)))){
      x <- sf::st_cast(x,"MULTILINESTRING")
    }
    if(grepl("GEOMETRY",sf::st_geometry_type(x,by_geometry = FALSE))&any(grepl("POINT",sf::st_geometry_type(x)))){
      x <- sf::st_cast(x,"POINT")
    }
  }

  # Extract bounding box & median x coordinate
  if(any(grepl("sp", attr(class(x), 'package')))){
    bb <- sf::st_bbox(x)
    median_x <- median(sf::st_coordinates(sf::st_as_sf(x))[,1],na.rm=T)
  }
  if(any(grepl("sf", class(x)))){
    bb <- sf::st_bbox(x)
    median_x <- median(sf::st_coordinates(x)[,"X"],na.rm=TRUE)
  }
  if(any(grepl("raster", attr(class(x), 'package')))) {
    x <- as(x,"SpatRaster")
  }
  if(any(grepl("terra", attr(class(x), 'package')))) {
    bb <- as.vector(terra::ext(x))[c("xmin","ymin","xmax","ymax")]
    median_x <- median(terra::crds(x)[,"x"],na.rm=TRUE)
  }

  # Conversion table
  UTM_Converter_Table <- data.frame(
    Begin = as.numeric(seq(-180, 174, by = 6)),
    End = as.numeric(seq(-174, 180, by = 6) - .000000001),
    UTM = as.numeric(seq(1, 60, by = 1)),
    CRS = paste0("+proj=utm +zone=", seq(1, 60, by = 1), " +datum=WGS84"),
    stringsAsFactors = FALSE)
  # Find UTM zone
  Location_UTM_Begin <- which(bb[3] >= UTM_Converter_Table$Begin)
  Location_UTM_End <- which(bb[1] <= UTM_Converter_Table$End)
  Location_UTM <- base::intersect(Location_UTM_Begin, Location_UTM_End)
  proj_out <- ifelse(length(Location_UTM) <= max_zones, as.character(UTM_Converter_Table$CRS[median(Location_UTM)]),paste0("+proj=aea +lon_0=", median_x," +lat_1=", bb[2]," +lat_2=",bb[4]))
  # Re-project
  if(any(grepl("sf", class(x)))){
    x_out <- sf::st_transform(x, proj_out)
  }
  if(any(grepl("terra", attr(class(x), 'package')))){
    x_out <- terra::project(x, y = proj_out)
  }
  if(any(grepl("sp", attr(class(x), 'package')))){
    suppressMessages({
      suppressWarnings({
        x_out <- as(sf::st_transform(sf::st_as_sf(x), proj_out),"Spatial")
      })
    })
  }
  # Output
  if (return_list == TRUE) {
    return(list(x_out = x_out, proj_out = proj_out))
  }
  if (return_list == FALSE) {
    return(x_out)
  }
}
