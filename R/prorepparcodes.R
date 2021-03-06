#' Extract a list of unique, most recent product, reporter and partner codes from Comext
#'
#' Takes a raw codes table from comext, select codes which have the most
#' recent \code{datestart} and make sure they are unique.
#' @param RMariaDBcon database connection object created by RMySQL \code{\link[DBI]{dbConnect}}
#' @param tableread character name of the table to read from
#' @param tablewrite character name of the table to write to
#' @param codevariable unquoted code variable (à la dplyr verbs)
#' @return TRUE on success
#' The output is actually a database table containing the cleaned codes.
#' @examples \dontrun{ # Clean product and country codes
#' # Connect to the database
#' con <- RMariaDB::dbConnect(RMariaDB::MariaDB(), dbname = "test")
#' # Write dummy codes to the database table "raw_code"
#' raw_code <- data.frame(code = c(4L, 4L), datestart = c(1L, 2L))
#' RMariaDB::dbWriteTable(con, "raw_code", raw_code, row.names = FALSE, overwrite = TRUE)
#' # Clean the codes and write them to the database table "vld_code" (for validated code)
#' cleancode(con, tableread = "raw_code", tablewrite = "vld_code", codevariable = "code")
#'
#' # Comext codes
#' if(FALSE){ # If raw codes are not present, transfer them
#' createdbstructure(sqlfile = "raw_comext.sql", dbname = "test")
#' tradeharvester::transfertxtcodesfolder2db(con, 
#'     rawdatacomextfolder = "~/R/tradeharvester/data_raw/comext/201707/text/english/")
#' }
#' # Clean comext product, reporter and partner codes
#' cleanallcomextcodes(con)
#' # Disconnect from the database
#' RMariaDB::dbDisconnect(con)
#' }
#' @export
cleancode <- function(RMariaDBcon, tableread, tablewrite, codevariable){
    # Implementation based on the "programming with dplyr" vignette
    # https://cran.r-project.org/web/packages/dplyr/vignettes/programming.html
    codevariable <- enquo(codevariable)
    
    # Check if output fields are in input fields
    inputfields <- RMariaDB::dbListFields(RMariaDBcon, tableread)
    outputfields <- RMariaDB::dbListFields(RMariaDBcon, tablewrite)
    stopifnot(outputfields %in% inputfields)
    
    # This function cannot use  RMariaDB::dbWriteTable with overwrite = TRUE
    # because this would also overwrites the field types and indexes.
    # dbWriteTable chooses default types that are not optimal,
    # for example, it changes date fields to text fields.
    # Therefore use RMariaDB::dbWriteTable with append = TRUE,
    # but first check if the table is empty
    # and if it is not empty, ask to recreate the database
    # structure with empty tables.
    # Check if the output table is empty
    res <- RMariaDB::dbSendQuery(RMariaDBcon, sprintf("SELECT COUNT(*) as nrow FROM %s;",tablewrite))
    sqltable <- RMariaDB::dbFetch(res)
    RMariaDB::dbClearResult(res)
    if(sqltable$nrow > 0){
        stop("Table ", tablewrite, " is not empty.",
             "You can recreate an empty table structure with:\n",
             sprintf("createdbstructure(sqlfile = 'vld_comext.sql', dbname = '%s')",
                     RMariaDB::dbGetInfo(RMariaDBcon)$dbname))
    }
    
    # load all codes  
    rawcode <- tbl(RMariaDBcon, tableread) %>%
        collect() 
    
    # Fix issue 5
    # "Not determined" is a slightly better qualifier of the absence of partner,
    # remove "No data" from the raw table.
    if("partner" %in% names(rawcode) & sum(rawcode$partnercode==0)>1){
        rawcode <- rawcode[rawcode$partner!="No data",]
    }
    
    vldcode <- rawcode %>%
        group_by(!!codevariable) %>%
        # keep only the most recent codes
        filter(datestart == max(datestart)) %>%
        select(outputfields) %>% 
        # remove duplicates
        unique()
    
    # Operations that are not generic 
    # Remove duplicates where one product code with the same datestart has 2 descriptions
    # based on the example product code 38249992 which has 2 descriptions
    if("productcode" %in% outputfields){
        vldcode <- vldcode [!duplicated(vldcode$productcode),]
    }
    # Remove trailing white space in reporter and partner country names
    if("reporter" %in% outputfields){ vldcode$reporter <- trimws(vldcode$reporter)}
    if("partner" %in% outputfields){ vldcode$partner <- trimws(vldcode$partner)}
    
    # After cleaning, 
    # the number of distinct rows for all columns should be equal to
    # the number of distinct codes in the raw dataset
    stopifnot(identical(nrow(vldcode),
                        nrow(distinct(rawcode, !!codevariable))))
   

    # Write back to the database
    RMariaDB::dbWriteTable(RMariaDBcon, tablewrite, vldcode,
                         row.names = FALSE, append = TRUE)
}


#' @rdname cleancode
#' @export
cleanunit <- function(RMariaDBcon, 
                      tableread = "raw_comext_unit",
                      tablewrite = "vld_comext_unit"){
    # Check if the output table is empty
    res <- RMariaDB::dbSendQuery(RMariaDBcon, sprintf("SELECT COUNT(*) as nrow FROM %s;",tablewrite))
    sqltable <- RMariaDB::dbFetch(res)
    RMariaDB::dbClearResult(res)
    if(sqltable$nrow > 0){
        stop("Table ", tablewrite, " is not empty.",
             "You can recreate an empty table structure with:\n",
             sprintf("createdbstructure(sqlfile = 'vld_comext.sql', dbname = '%s')",
                     RMariaDB::dbGetInfo(RMariaDBcon)$dbname))
    }
    
    # Load raw units 
    rawunits <- tbl(RMariaDBcon, tableread) %>%
        collect() 
    
    # Change start and end dates to a period in month
    vldunits <- rawunits %>% 
        mutate(periodstart = gsub("-", "", substr(datestart,1,7)),
               periodend   = gsub("-", "", substr(dateend,1,7))) %>% 
        select(-datestart, -dateend)
    
    # Write back to the database
    RMariaDB::dbWriteTable(RMariaDBcon, tablewrite, vldunits,
                         row.names = FALSE, append = TRUE)
}


#' @description \code{cleanallcomextcodes} extracts unique product
#' and country codes from the Comext raw data so that they are ready for use
#' as unique keys.
#' It is a porcelaine function based on the plumbing function \code{cleancode}.
#'
#' @rdname cleancode
#' @export
cleanallcomextcodes <- function(RMariaDBcon){
    createdbstructure(sqlfile = "vld_comext.sql",
                      # extract db name from the RMySQL connection object
                      dbname = RMariaDB::dbGetInfo(RMariaDBcon)$dbname)
    message("Cleaning product, reporter and partner codes...")
    cleancode(RMariaDBcon, "raw_comext_product", "vld_comext_product", productcode)
    cleancode(RMariaDBcon, "raw_comext_reporter", "vld_comext_reporter", reportercode)
    cleancode(RMariaDBcon, "raw_comext_partner", "vld_comext_partner", partnercode)
    message("Cleaning unit codes...")
    cleancode(RMariaDBcon, "raw_comext_unit_description", 
              "vld_comext_unit_description", unitcode)
    cleanunit(RMariaDBcon)
    
    # Diagnostics
    # Display row count information
    # based on https://stackoverflow.com/a/1775272/2641825
    res <- RMariaDB::dbSendQuery(RMariaDBcon, "SELECT
                               (SELECT COUNT(*) FROM   vld_comext_product)  AS product,
                               (SELECT COUNT(*) FROM   vld_comext_reporter) AS reporter,
                               (SELECT COUNT(*) FROM   vld_comext_partner)  AS partner")
    nrows <- RMariaDB::dbFetch(res)
    RMariaDB::dbClearResult(res)
    message("Transfered:\n",
            nrows$product, " rows to the vld_comext_product table\n",
            nrows$reporter, " rows to the vld_comext_reporter table\n",
            nrows$partner, " rows to the vld_comext_partner table.\n")
}


#' Add product reporter and partner to a tbl object
#' @return a tbl object left joined to the product, reporter and partner tables.
#' @param RMariaDBcon database connection object created by RMySQL \code{\link[DBI]{dbConnect}}
#' @param maintbl tbl containing trade data, with productcode, reportercode and partnercode
#' @examples \dontrun{
#' con <- RMariaDB::dbConnect(RMariaDB::MariaDB(), dbname = "test")
#' monthly <- tbl(con, "raw_comext_monthly_201707")
#' monthly %>%
#'     filter(productcode == 44) %>%
#'     addproreppar2tbl(con, .) %>%
#'     collect()
#' RMariaDB::dbDisconnect(con)
#' }
#' @export
addproreppar2tbl <- function(RMariaDBcon, maintbl){
    maintbl %>%
        left_join(tbl(RMariaDBcon, "vld_comext_product"),
                  by = "productcode") %>%
        left_join(tbl(RMariaDBcon, "vld_comext_reporter"),
                  by = "reportercode") %>%
        left_join(tbl(RMariaDBcon, "vld_comext_partner"),
                  by = "partnercode")
}


#' @details addunit2tbl joints all unit codes, 
#' then removes those which are out dated
#' @rdname addproreppar2tbl
#' @export
addunit2tbl <- function(RMariaDBcon, maintbl, 
                        tableunit = "vld_comext_unit"){
    maintbl2 <- maintbl %>% 
        left_join(tbl(RMariaDBcon, tableunit),
                  by = "productcode") %>% 
        filter((periodstart <= period & period <= periodend) | is.na(unitcode)) %>% 
        # Remove unnecessary columns
        select(-periodstart, -periodend)
    
    # Check that the number of rows didn't change
    d1 <- collect(count(maintbl))
    d2 <- collect(count(maintbl2))
    if(!identical(d1$n, d2$n)){
        stop("more than one unit for a period. The input table has",
             d1, "rows, the table with units has ", d2, "rows.")
    }

    # Check that the total tradevalue didn't change
    tv1 <- maintbl %>% summarise(n = sum(tradevalue, na.rm = TRUE)) %>% collect()
    tv2 <- maintbl2 %>% summarise(n = sum(tradevalue, na.rm = TRUE)) %>% collect()
    stopifnot(identical(tv1$n, tv2$n))
    
    return(maintbl2)
}


#' Count the number of distinct rows in a database table for a given variable
#' @param RMariaDBcon database connection object created by RMySQL \code{\link[DBI]{dbConnect}}
#' @param tablename character name of a database table 
#' @param variable character name of a variable in that database table
#' @return numeric value
#' @examples 
#' con <- RMariaDB::dbConnect(RMariaDB::MariaDB(), dbname = "test")
#' on.exit(RMariaDB::dbDisconnect(con))
#' # Transfer the iris data frame to the database
#' RMariaDB::dbWriteTable(con, "iris_in_db", iris, row.names = FALSE, overwrite = TRUE)
#' # Count the number of species
#' dbndistinct(con, "iris_in_db", Species)
#' @export
dbndistinct <- function(RMariaDBcon, tablename, variable){
    variable <- enquo(variable)
    dtf <- tbl(RMariaDBcon, tablename) %>% 
        distinct(!!variable) %>% 
        summarise(n = n()) %>% 
        collect() 
    return(dtf$n)
}


