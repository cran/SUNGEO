#' Area and population weighted polygon-to-polygon interpolation
#'
#' Function for interpolating values from a source polygon layer to an overlapping (but spatially misaligned) destination polygon layer, using area and/or population weights.
#'
#' @param poly_from Source polygon layer. \code{sf} object.
#' @param poly_to Destination polygon layer. Must have identical CRS to \code{poly_from}. \code{sf} object.
#' @param poly_to_id Name of unique ID column for destination polygon layer. Character string.
#' @param geo_vor Voronoi polygons object (used internally by \code{point2poly_tess}). \code{sf} object.
#' @param methodz Area interpolation method(s). Could be either of "aw" (areal weighting, default) and/or "pw" (population weighting). See "details". Character string or vector of character strings.
#' @param char_methodz Interpolation method(s) for character strings. Could be either of "aw" (areal weighting, default) or "pw" (population weighting). See "details". Character string.
#' @param pop_raster Population raster to be used for population weighting, Must be supplied if \code{methodz="pw"}. Must have identical CRS to \code{poly_from}. \code{raster} or \code{SpatRaster} object.
#' @param varz Names of numeric variable(s) to be interpolated from source polygon layer to destination polygons. Character string or vector of character strings.
#' @param funz Aggregation function to be applied to variables specified in \code{varz}. Must take as an input a numeric vector \code{x} and vector of weights \code{w}. Function or list of functions.
#' @param pycno_varz  Names of spatially extensive numeric variables for which the pycnophylactic (mass-preserving) property should be preserved. Character string or vector of character strings.
#' @param char_varz  Names of character string variables to be interpolated from source polygon layer to destination polygons. Character string or vector of character strings.
#' @param char_assign Assignment rule to be used for variables specified in \code{char_varz}. Could be either "biggest_overlap" (default) or "all_overlap". See "details". Character string or vector of character strings.
#' @param seed Seed for generation of random numbers. Default is 1. Numeric.
#' @return \code{sf} polygon object, with variables from \code{poly_from} interpolated to the geometries of \code{poly_to}.
#' @details Currently supported integration methods (\code{methodz}) include:
#' \itemize{
##'  \item Areal weighting ("aw"). Values from \code{poly_from} weighted in proportion to relative area of spatial overlap between source features and geometries of \code{poly_to}.
##'  \item Population weighting ("pw"). Values from \code{poly_from} weighted in proportion to relative population sizes in areas of spatial overlap between source features and geometries of \code{poly_to}. This routine uses a third layer (supplied in \code{pop_raster}) to calculate the weights.
##' }
#' It is possible to pass multiple arguments to \code{methodz} (e.g. \code{methodz=c("aw","pw")}), in which case the function will calculate both sets of weights, and append the resulting columns to the output.
#'
#' Interpolation procedures are handled somewhat differently for numeric and character string variables. For numeric variables supplied in \code{varz}, "aw" and/or "pw" weights are passed to the function specified in \code{funz}. If different sets of numeric variables are to be aggregated with different functions, both \code{varz} and \code{funz} should be specified as lists (see examples below).
#'
#' For character string (and any other) variables supplied in \code{char_varz}, "aw" and/or "pw" weights are passed to the assignment rule(s) specified in \code{char_assign}. Note that the \code{char_varz} argument may include numerical variables, but \code{varz} cannot include character string variables.
#'
#' Currently supported assignment rules for character strings (\code{char_assign}) include:
#' \itemize{
##'  \item "biggest_overlap". For each variable in \code{char_varz}, the features in \code{poly_to} are assigned a single value from overlapping \code{poly_from} features, corresponding to the intersection with largest area and/or population weight.
##'  \item "all_overlap". For each variable in \code{char_varz}, the features in \code{poly_to} are assigned all values from overlapping \code{poly_from} features, ranked by area and/or population weights (largest-to-smallest) of intersections.
##' }
#' It is possible to pass multiple arguments to \code{char_assign} (e.g. \code{char_assign=c("biggest_overlap","all_overlap")}), in which case the function will calculate both, and append the resulting columns to the output.
#' @import sf
#' @importFrom stats as.dist weighted.mean
#' @importFrom data.table data.table rbindlist as.data.table
#' @importFrom terra extract
#' @importFrom methods as
#' @importFrom dplyr full_join left_join
#' @importFrom purrr reduce
#' @examples
#' # Interpolation of a single variable, with area weights
#' \dontrun{
#' data(clea_deu2009)
#' data(hex_05_deu)
#' out_1 <- poly2poly_ap(poly_from = clea_deu2009,
#'               poly_to = hex_05_deu,
#'               poly_to_id = "HEX_ID",
#'               varz = "to1"
#'              )
#' }
#'
#' # Interpolation of multiple variables, with area weights
#' \dontrun{
#' out_2 <- poly2poly_ap(
#'               poly_from = clea_deu2009,
#'               poly_to = hex_05_deu,
#'               poly_to_id = "HEX_ID",
#'               varz = list(
#'                 c("to1","pvs1_margin"),
#'                 c("vv1") ),
#'               pycno_varz = "vv1",
#'               funz = list(
#'                 function(x,w){stats::weighted.mean(x,w)},
#'                 function(x,w){sum(x*w)} ),
#'               char_varz = c("incumb_pty_n","win1_pty_n")
#'              )
#' }
#'
#' # Interpolation of a single variable, with population weights
#' \dontrun{
#' data(gpw4_deu2010)
#' out_3 <- poly2poly_ap(poly_from = clea_deu2009,
#'                          poly_to = hex_05_deu,
#'                          poly_to_id = "HEX_ID",
#'                          varz = "to1",
#'                          methodz = "pw",
#'                          pop_raster = gpw4_deu2010)
#' }
#'
#' # Interpolation of a single variable, with area and population weights
#' \dontrun{
#' out_4 <- poly2poly_ap(poly_from = clea_deu2009,
#'                          poly_to = hex_05_deu,
#'                          poly_to_id = "HEX_ID",
#'                          varz = "to1",
#'                          methodz = c("aw","pw"),
#'                          pop_raster = gpw4_deu2010)
#' }
#' @export



poly2poly_ap <- function(
    poly_from,
    poly_to,
    poly_to_id,
    geo_vor = NULL,
    methodz="aw",
    char_methodz = "aw",
    pop_raster=NULL,
    varz=NULL,
    pycno_varz=NULL,
    char_varz=NULL,
    char_assign="biggest_overlap",
    funz=function(x,w){stats::weighted.mean(x,w,na.rm=TRUE)},
    seed = 1){

  set.seed(seed)

  # Turn off s2 processing
  suppressMessages({
    sf::sf_use_s2(FALSE)
  })

  ###########################################################
  #Section A - Preparing the Gemetries for Tessalation Prcess
  ###########################################################
  # Put variables and functions into list
  #Part i -
  if(length(varz) != length(funz) && is.list(varz) && is.list(funz)){
    stop("ERROR: Length of variable list does not equal length of function list. Pleasse ensure that each set of variables correspsonds to a specific function argument.")
  }

  #Part ii -
  if(inherits(varz,"character")){varz <- list(varz)}

  #Part iii -
  if(!inherits(funz,"list")){funz <- list(funz)}
  funz <- lapply(funz, function(sub_iter){
    if(class(sub_iter)%in%"function" == FALSE && class(sub_iter)%in%'character'){
      funzInt <- get(sub_iter, mode = 'function')
      return(funzInt)
    } else {
      return(sub_iter)
    }
  })

  #
  #
  #

  # Stop if no population raster
  if("pw"%in%methodz & length(pop_raster)==0){stop("No population raster provided.")}

  # Area-weights (part 1)
  if("aw"%in%methodz|"aw"%in%char_methodz){
    # Calculate polygon areas
    poly_from$AREA_TOTAL_FROM <- as.numeric(sf::st_area(poly_from))
    poly_to$AREA_TOTAL_TO <- as.numeric(sf::st_area(poly_to))
  }

  # Population-weights (part 1)
  if("pw"%in%methodz){
    # Calculate polygon total
    poly_from$POP_TOTAL_FROM <- unlist(terra::extract(pop_raster,methods::as(poly_from,"Spatial"),fun=sum,na.rm=TRUE))
    poly_to$POP_TOTAL_TO <- unlist(terra::extract(pop_raster,methods::as(poly_to,"Spatial"),fun=sum,na.rm=TRUE))
  }

  #
  #
  #
  #

  ###########################################################
  #Section B -
  ###########################################################
  #Part i -
  poly_to$Return_ID <- 1:nrow(poly_to)

  #Part ii - Intersection
  suppressWarnings({
    suppressMessages({
      int_1 <- sf::st_buffer(sf::st_intersection(sf::st_buffer(poly_from,dist=0),sf::st_buffer(poly_to,dist=0)),dist=0)
    })
  })

  # Drop empty geometries
  if(any(sf::st_is_empty(int_1))){int_1 <- int_1[!sf::st_is_empty(int_1),]}


  #
  #

  #############################
  #Part iii -
  #############################
  # Area-weights (part 2)
  if("aw"%in%methodz|"aw"%in%char_methodz){
    # Calculate weights
    int_1$AREA_INT <- as.numeric(sf::st_area(int_1))
    int_1$AREA_W_EXV <- int_1$AREA_INT/int_1$AREA_TOTAL_FROM
    int_1$AREA_W_INV <- int_1$AREA_INT/int_1$AREA_TOTAL_TO
  }

  # Population-weights (part 2)
  if("pw"%in%methodz){
    # Calculate weights
    int_1$POP_INT <- unlist(terra::extract(pop_raster,int_1,fun=sum,na.rm=TRUE))
    int_1$POP_W_EXV <- int_1$POP_INT/int_1$POP_TOTAL_FROM
    int_1$POP_W_INV <- int_1$POP_INT/int_1$POP_TOTAL_TO
  }

  #
  #

  #########################
  #Part v - Convert to dt
  #########################
  int_1_dt <- data.table::data.table(int_1) #Convert to Data Table Object
  int_1_dt$geometry <- NULL #Remove Geometry

  #
  #
  ################################################
  #Part v - Interpolate missing population values
  ################################################
  if("pw"%in%methodz){
    ############
    #Section A -
    ############
    if(sum(is.na(int_1_dt$POP_INT))==1){
      #Part a -
      suppressWarnings({
        w <- as.matrix(sf::st_distance(sf::st_centroid(int_1)))
      })


      #Part b -
      diag(w) <- NA

      #Part c -
      int_1_dt$POP_INT[is.na(int_1_dt$POP_INT)] <- median(int_1_dt$POP_INT[t(apply(w, 1, order)[1:min(10,nrow(int_1_dt)), is.na(int_1_dt$POP_INT)])],na.rm=TRUE)

      #Part d -
      int_1_dt$POP_W_EXV[is.na(int_1_dt$POP_W_EXV)] <- min(1,int_1_dt$POP_INT[is.na(int_1_dt$POP_W_EXV)]/int_1_dt$POP_TOTAL_FROM[is.na(int_1_dt$POP_W_EXV)])
      int_1_dt$POP_W_INV[is.na(int_1_dt$POP_W_INV)] <- min(1,int_1_dt$POP_INT[is.na(int_1_dt$POP_W_INV)]/int_1_dt$POP_TOTAL_TO[is.na(int_1_dt$POP_W_INV)])

    }

    ############
    #Section b -
    ############

    if(sum(is.na(int_1_dt$POP_INT))>1){
      #Part a -
      suppressWarnings({
        w <- as.matrix(sf::st_distance(sf::st_centroid(int_1)))
      })

      #Part b -
      diag(w) <- NA

      #Part c -
      int_1_dt$POP_INT[is.na(int_1_dt$POP_INT)] <- apply(t(apply(w, 1, order)[ 1:min(10,nrow(int_1_dt)), is.na(int_1_dt$POP_INT)]),1,function(x){mean(int_1_dt$POP_INT[x],na.rm=TRUE)})

      #Part d -
      int_1_dt$POP_W_EXV[is.na(int_1_dt$POP_W_EXV)] <- min(1,int_1_dt$POP_INT[is.na(int_1_dt$POP_W_EXV)]/int_1_dt$POP_TOTAL_FROM[is.na(int_1_dt$POP_W_EXV)])
      int_1_dt$POP_W_INV[is.na(int_1_dt$POP_W_INV)] <- min(1,int_1_dt$POP_INT[is.na(int_1_dt$POP_W_INV)]/int_1_dt$POP_TOTAL_TO[is.na(int_1_dt$POP_W_INV)])
    }
  }

  #
  #

  #############################
  #Part vi - Aggregate Estimates
  #############################
  if(!is.null(geo_vor)){
    #Part a -
    geo_vor_dt <- geo_vor

    #Part b -
    sf::st_geometry(geo_vor_dt) <- NULL

    #Part B -
    geo_vor_dt <- data.table::data.table('Unique_ID' = geo_vor_dt$Unique_ID)

    #Part c -
    Aggregation_Matrix <- data.table::data.table(dplyr::full_join(geo_vor_dt, int_1_dt, by = 'Unique_ID'))
  } else {
    #Part a -
    poly_from$Unique_ID <- 1:nrow(poly_from)

    #Part b -
    geo_vor_dt <- poly_from

    #Part c -
    sf::st_geometry(geo_vor_dt) <- NULL

    #Part d -
    geo_vor_dt <- data.table::data.table('Unique_ID' = geo_vor_dt$Unique_ID)

    #Part e -
    sf::st_geometry(geo_vor_dt) <- sf::st_geometry(poly_from)

    #Part e -
    suppressWarnings({
      suppressMessages(
        Aggregation_Matrix <- data.table::data.table(sf::st_intersection(geo_vor_dt, int_1))
      )
    })

  }


  #
  #
  #
  #
  #
  #
  #

  ##########################################
  #Section C - Aggregate (numeric variables)
  ##########################################
  #Part i -
  ClassTypes_Variables <- data.table::data.table('Varz' = varz, 'Funz' = funz, 'methodz' = methodz)

  #Part ii -
  ClassTypes_Variables <- lapply(1:length(ClassTypes_Variables$Varz), function(sub_iter) {
    Varz_Int <- unlist(ClassTypes_Variables$Varz[sub_iter])

    Funz_Int <- unlist(ClassTypes_Variables$Funz[sub_iter], recursive = TRUE)

    Methodz_Int <- unlist(ClassTypes_Variables$methodz[sub_iter], recursive = TRUE)

    NAValue <- unlist(ClassTypes_Variables$NAval[sub_iter], recursive = TRUE)

    OutputMatrix <- data.table::data.table('Varz' = Varz_Int, 'Funz' = Funz_Int, 'methodz' = Methodz_Int)

    return(OutputMatrix)

  })
  ClassTypes_Variables <- data.table::rbindlist(ClassTypes_Variables,fill=TRUE)

  #Part iii -
  if(any('pw'%in%char_methodz)){
    CharacterVariables <- data.table::data.table('Varz' = char_varz, 'Funz' = NA, 'methodz' = 'pw')
  } else {
    CharacterVariables <- data.table::data.table('Varz' = char_varz, 'Funz' = NA, 'methodz' = 'aw')
  }

  #Part iv -
  if(is.null(char_varz) == FALSE){
    ClassTypes_Variables <- data.table::rbindlist(list(
      ClassTypes_Variables,
      CharacterVariables
    ),fill=TRUE)
  }

  #Part v -
  ClassTypes_Variables$Character <- FALSE
  ClassTypes_Variables$Character[ClassTypes_Variables$Varz%in%char_varz] <- TRUE

  #

  ###########################################################
  #Section C - Character string variables
  ###########################################################
  if(any(ClassTypes_Variables$Character)){
    #Part i -
    Character_Subset <- ClassTypes_Variables[ClassTypes_Variables$Character%in%TRUE,]

    #Part ii -
    Character_Aggregation_Matrix <- lapply(1:nrow(Character_Subset), function(sub_iter){
      if("biggest_overlap"%in%char_assign){
        #########################
        #Part A - Areal Weighting
        #########################
        if("aw"%in%Character_Subset$methodz[sub_iter]){
          #Part i - Locate Variables
          locVar <- which(names(Aggregation_Matrix)%in%c('Return_ID', 'AREA_W_INV', Character_Subset$Varz[sub_iter]))

          #Part ii - Subset Columns
          Internal_Matrix <- Aggregation_Matrix[,locVar, with = FALSE]

          #Part iii - Rename Value Column
          names(Internal_Matrix)[!names(Internal_Matrix)%in%c('Return_ID', 'AREA_W_INV')] <- 'var_'

          #Part iv - Collapse Data Frame
          Internal_Matrix <- by(data=Internal_Matrix,INDICES=Internal_Matrix$Return_ID,FUN=function(x){paste0(unique(x$var_[x$AREA_W_INV%in%max(x$AREA_W_INV, na.rm = TRUE)]),collapse="|")},simplify=TRUE)
          Internal_Matrix <- data.table::data.table(Return_ID=as.numeric(names(Internal_Matrix)),V1=c(Internal_Matrix))

          #Part v -
          names(Internal_Matrix)[2] <- Character_Subset$Varz[sub_iter]


        }

        ##############################
        #Part B - Populating Weighting
        ##############################
        if("pw"%in%Character_Subset$methodz[sub_iter]){
          #Part i - Locate Variables
          locVar <- which(names(Aggregation_Matrix)%in%c('Return_ID', 'POP_W_INV', Character_Subset$Varz[sub_iter]))

          #Part ii - Subset Columns
          Internal_Matrix <- Aggregation_Matrix[,locVar, with = FALSE]

          #Part iii - Rename Value Column
          names(Internal_Matrix)[names(Internal_Matrix)%in%c('Return_ID', 'POP_W_INV') == FALSE] <- 'var_'

          #Part iv - Collapse Data Frame
          Internal_Matrix <- Internal_Matrix[,list(paste(unique(var_[POP_W_INV%in%max(POP_W_INV, na.rm = TRUE)]), collapse = '|')), by = list(Return_ID)]

          #Part v -
          names(Internal_Matrix)[2] <- Character_Subset$Varz[sub_iter]


        }

      }

      ##############################################
      #All Collapse - Collapse Values that Intersect
      ##############################################
      if("all_overlap"%in%char_assign){
        #########################
        #Part A - Areal Weighting
        #########################
        if("aw"%in%Character_Subset$methodz[sub_iter]){
          #Part i - Locate Variables
          locVar <- which(names(Aggregation_Matrix)%in%c('Return_ID', 'AREA_W_INV', Character_Subset$Varz[sub_iter]))

          #Part ii - Subset Columns
          Internal_Matrix <- Aggregation_Matrix[,locVar, with = FALSE]

          #Part iii - Rename Value Column
          names(Internal_Matrix)[names(Internal_Matrix)%in%c('Return_ID', 'AREA_W_INV') == FALSE] <- 'var_'

          #Part iv - Collapse Data Frame
          Internal_Matrix <- Internal_Matrix[,list(paste(unique(var_), collapse = '|')), by = list(Return_ID)]

          #Part v -
          names(Internal_Matrix)[2] <- Character_Subset$Varz[sub_iter]


        }

        ##############################
        #Part B - Populating Weighting
        ##############################
        if("pw"%in%Character_Subset$methodz[sub_iter]){
          #Part i - Locate Variables
          locVar <- which(names(Aggregation_Matrix)%in%c('Return_ID', 'POP_W_INV', Character_Subset$Varz[sub_iter]))

          #Part ii - Subset Columns
          Internal_Matrix <- Aggregation_Matrix[,locVar, with = FALSE]

          #Part iii - Rename Value Column
          names(Internal_Matrix)[names(Internal_Matrix)%in%c('Return_ID', 'POP_W_INV') == FALSE] <- 'var_'

          #Part iv - Collapse Data Frame
          Internal_Matrix <- Internal_Matrix[,list(paste(unique(var_), collapse = '|')), by = list(Return_ID)]

          #Part v -
          names(Internal_Matrix)[2] <- Character_Subset$Varz[sub_iter]


        }

      }

      #
      #
      #

      return(Internal_Matrix)




    })

    #Part iiii -
    Empty_Sets <- sapply(Character_Aggregation_Matrix, function(x) is.null(x[,2]) || grepl('Error', x[,2]))
    if(TRUE%in%Empty_Sets){
      Character_Aggregation_Matrix <- Character_Aggregation_Matrix[Empty_Sets == FALSE]
    }

    #Part iv -
    Character_Aggregation_Matrix <-  purrr::reduce(Character_Aggregation_Matrix,dplyr::full_join, by = 'Return_ID')

  }


  #
  #
  #
  #
  #
  #
  #

  ###########################################################
  #Section D - Numeric Variables (intensive as default)
  ###########################################################
  #Part i -
  Numeric_Subset <- ClassTypes_Variables[ClassTypes_Variables$Character%in%FALSE,]

  #Part ii -
  Numeric_Aggregation_Matrix <- lapply(1:nrow(Numeric_Subset), function(sub_iter){
    #Part a - Locate Variables
    if("aw"%in%Numeric_Subset$methodz[sub_iter]){
      locVar <- which(names(Aggregation_Matrix)%in%c('Return_ID', 'AREA_W_INV', Numeric_Subset$Varz[sub_iter]))
    }

    #Part a - Locate Variables
    if("pw"%in%Numeric_Subset$methodz[sub_iter]){
      locVar <- which(names(Aggregation_Matrix)%in%c('Return_ID', 'POP_W_INV', Numeric_Subset$Varz[sub_iter]))
    }

    #Part b - Subset Columns
    Internal_Matrix <- data.table::as.data.table(Aggregation_Matrix[,locVar, with = FALSE])

    #Part c - Rename Value Column
    if("aw"%in%Numeric_Subset$methodz[sub_iter]){
      names(Internal_Matrix)[!names(Internal_Matrix)%in%c('Return_ID', 'AREA_W_INV')] <- 'var_'
    }

    if("pw"%in%Numeric_Subset$methodz[sub_iter]){
      names(Internal_Matrix)[!names(Internal_Matrix)%in%c('Return_ID', 'POP_W_INV')] <- 'var_'
    }

    #Part c -
    IntermediateFunction <- Numeric_Subset$Funz[sub_iter][[1]]

    #Part d -
    searchWeight <- c('weighted', 'w')

    if(grepl(paste(searchWeight, collapse = '|'), paste(as.character(attributes(IntermediateFunction)$srcref),collapse=""))){
      if("aw"%in%Numeric_Subset$methodz[sub_iter]){
        Output <- by(data=Internal_Matrix,INDICES=Internal_Matrix$Return_ID,FUN=function(x){IntermediateFunction(x$var_, w = x$AREA_W_INV)},simplify=TRUE)
        Output <- data.table::data.table(Return_ID=as.numeric(names(Output)),V1=c(Output))
      }

      if("pw"%in%Numeric_Subset$methodz[sub_iter]){
        Output <- by(data=Internal_Matrix,INDICES=Internal_Matrix$Return_ID,FUN=function(x){IntermediateFunction(x$var_, w = x$POP_W_INV)},simplify=TRUE)
        Output <- data.table::data.table(Return_ID=as.numeric(names(Output)),V1=c(Output))
      }

    } else {
      suppressWarnings({
        Output <- by(data=Internal_Matrix,INDICES=Internal_Matrix$Return_ID,FUN=function(x){IntermediateFunction(x$var_)},simplify=TRUE)
        Output <- data.table::data.table(Return_ID=as.numeric(names(Output)),V1=c(Output))
      })

    }

    #Part e -
    if("pw"%in%Numeric_Subset$methodz[sub_iter]){
      names(Output)[2] <- paste0(Numeric_Subset$Varz[sub_iter], '_pw')
    }

    if("aw"%in%Numeric_Subset$methodz[sub_iter]){
      names(Output)[2] <- paste0(Numeric_Subset$Varz[sub_iter], '_aw')
    }

    #RETURN
    return(Output)
  })

  #Part iii -
  Empty_Sets <- sapply(Numeric_Aggregation_Matrix, function(x){is.null(x[,2]) || grepl('Error', x[,2])})

  if(TRUE%in%Empty_Sets){
    Numeric_Aggregation_Matrix <- Numeric_Aggregation_Matrix[Empty_Sets == FALSE]
  }

  #Part iv -
  Numeric_Aggregation_Matrix <-  purrr::reduce(Numeric_Aggregation_Matrix,dplyr::full_join, by = 'Return_ID')

  #
  #
  #
  #
  #

  ###########################################################
  #Section E - Pycnophylactic variables
  ###########################################################

  if(!is.null(pycno_varz)){
    # Loop over pycno_varz
    for(p0 in 1:length(pycno_varz)){
      # Find sum of original variable
      sum_from <- data.table::as.data.table(poly_from)[,sum(get(pycno_varz[p0]),na.rm=TRUE)]

      # Find matching processed variables in target geometry
      pycno_varz_to <- grep(paste0("^",pycno_varz[p0]),Numeric_Subset[,paste0(Numeric_Subset$Varz,"_",Numeric_Subset$methodz)],value=TRUE)

      #Part i -
      Extensive_Subset <- ClassTypes_Variables[ClassTypes_Variables$Character%in%FALSE&Varz%in%pycno_varz[p0],]

      #Part ii -
      Extensive_Aggregation_Matrix <- lapply(1:nrow(Extensive_Subset), function(sub_iter){
      
        #Part a - Locate Variables
        if("aw"%in%Extensive_Subset$methodz[sub_iter]){
          locVar <- which(names(Aggregation_Matrix)%in%c('Return_ID', 'AREA_W_EXV', Extensive_Subset$Varz[sub_iter]))
        }

        #Part a - Locate Variables
        if("pw"%in%Extensive_Subset$methodz[sub_iter]){
          locVar <- which(names(Aggregation_Matrix)%in%c('Return_ID', 'POP_W_EXV', Extensive_Subset$Varz[sub_iter]))
        }

        #Part b - Subset Columns
        Internal_Matrix <- data.table::as.data.table(Aggregation_Matrix[,locVar, with = FALSE])

        #Part c - Rename Value Column
        if("aw"%in%Extensive_Subset$methodz[sub_iter]){
          names(Internal_Matrix)[!names(Internal_Matrix)%in%c('Return_ID', 'AREA_W_EXV')] <- 'var_'
        }

        if("pw"%in%Extensive_Subset$methodz[sub_iter]){
          names(Internal_Matrix)[!names(Internal_Matrix)%in%c('Return_ID', 'POP_W_EXV')] <- 'var_'
        }

        #Part c & d - weighted sum
        if("aw"%in%Extensive_Subset$methodz[sub_iter]){
          Output <- by(data=Internal_Matrix,INDICES=Internal_Matrix$Return_ID,FUN=function(x){sum(x$var_*x$AREA_W_EXV)},simplify=TRUE)
          Output <- data.table::data.table(Return_ID=as.numeric(names(Output)),V1=c(Output))
        }
        if("pw"%in%Extensive_Subset$methodz[sub_iter]){
          Output <- by(data=Internal_Matrix,INDICES=Internal_Matrix$Return_ID,FUN=function(x){sum(x$var_*x$POP_W_EXV)},simplify=TRUE)
          Output <- data.table::data.table(Return_ID=as.numeric(names(Output)),V1=c(Output))
        }

        #Part e -
        if("pw"%in%Extensive_Subset$methodz[sub_iter]){
          names(Output)[2] <- paste0(Extensive_Subset$Varz[sub_iter], '_pw')
        }

        if("aw"%in%Extensive_Subset$methodz[sub_iter]){
          names(Output)[2] <- paste0(Extensive_Subset$Varz[sub_iter], '_aw')
        }

        #RETURN
        return(Output)
      })

      #Part iii -
      Empty_Sets <- sapply(Extensive_Aggregation_Matrix, function(x){is.null(x[,2]) || grepl('Error', x[,2])})

      if(TRUE%in%Empty_Sets){
        Extensive_Aggregation_Matrix <- Extensive_Aggregation_Matrix[Empty_Sets == FALSE]
      }

      #Part iv -
      Extensive_Aggregation_Matrix <-  purrr::reduce(Extensive_Aggregation_Matrix,dplyr::full_join, by = 'Return_ID')

      # Rescale variables in target geometry
      for(p00 in 1:length(pycno_varz_to)){
        Extensive_Aggregation_Matrix[,eval(pycno_varz_to[p00]) := get(pycno_varz_to[p00])*sum_from/sum(get(pycno_varz_to[p00]),na.rm = TRUE)]
        # Copy to intensive matrix
        Numeric_Aggregation_Matrix[,eval(pycno_varz_to[p00]):=Extensive_Aggregation_Matrix[,get(pycno_varz_to[p00])]]
      }

      # # Check if numbers align
      # Numeric_Aggregation_Matrix[,sum(get(pycno_varz_to[1]))]
      # Extensive_Aggregation_Matrix[,sum(get(pycno_varz_to[1]))]
      # sum_from
    }
  }


  ###########################################################
  #Section F - Combine
  ###########################################################
  if(any(ClassTypes_Variables$Character)){
    #Part 1 -
    Output_Matrix <- purrr::reduce(list(Character_Aggregation_Matrix, Numeric_Aggregation_Matrix),dplyr::full_join, by = 'Return_ID')
  } else {
    Output_Matrix <- Numeric_Aggregation_Matrix
  }

  #Part 2 -
  polyz_ <- dplyr::left_join(poly_to, Output_Matrix, by = 'Return_ID')

  #Part 3 -
  polyz_$Return_ID <- NULL

  #Part 4 - Output
  polyz_ <- sf::st_cast(polyz_,"MULTIPOLYGON")
  return(polyz_)

}
