% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/scrapcomext.R
\name{scraplinks}
\alias{scraplinks}
\alias{scrapcomextfoldername}
\alias{extractfilepath}
\alias{scraplistoffilesincomext}
\alias{scraplistoffilesincomextfolder}
\title{Extract link texts and urls from a web page}
\usage{
scraplinks(url)

scrapcomextfoldername(pattern, urlparameter = "dir")

extractfilepath(url, urlparameter = "downfile")

scraplistoffilesincomext(folderurl, urlparameter = "downfile")

scraplistoffilesincomextfolder(
  comextfolderpath = getOption("comext")["datafolder"],
  extension = ".7z"
)
}
\arguments{
\item{url}{character, an url}

\item{pattern}{character string containing a regular expression, see \code{\link{grepl}}}

\item{folderurl}{character url of the comext folder of interest}

\item{comextfolderpath}{path on the comext site (subfolder of the "comext" folder)}

\item{extension}{character file extension of interest}

\item{parameter}{character the url parameter where the file path is located}
}
\value{
a data frame of link text and urls

a character vector containing the name of the folder

A comext folder name

a character vector

a data frame containing folder paths and file names
}
\description{
A group of functions that use \code{rvest::\link{html_nodes}} to extract information
from the Eurostat Comext bulk download repository.
\code{scraplinks}, the main function, extracts links from a web page.
}
\examples{
\dontrun{
scraplinks("http://localhost/")
glinks <- scraplinks("http://google.com/")
}
\dontrun{ # Scrap the name of Comext recent and archive folders
# Name of the most recent monthly folder
scrapcomextfoldername(format(Sys.Date(),"\\\\[\%Y"))
# Character escape needed, because "[" and "]" have a special meaning in a regular expression
# Name of the monthly data archive folder.
scrapcomextfoldername("S1\\\\]")
# Name of the yearly data archive folder
scrapcomextfoldername("S2\\\\]")
}
# Extract the file path form a Eurostat URL
eurostat_url_1 <- "http://ec.europa.eu/eurostat/estat-navtree-portlet-prod/BulkDownloadListing?sort=1&downfile=comext\%2F201706\%2Fdata\%2Fnc201702.7z"
extractfilepath(eurostat_url_1, "downfile")
eurostat_url_2 <- "http://ec.europa.eu/eurostat/estat-navtree-portlet-prod/BulkDownloadListing?sort=1&file=comext\%2F201706\%2Fdata\%2Fnc201702.7z"
extractfilepath(eurostat_url_2, "file")
extractfilepath(eurostat_url_2, "nonesense") # returns NA

\dontrun{ # List files in the given comext folder
# Most recent data folder (url will change through time, this example will break)
recentfiles <- scraplistoffilesincomext("http://ec.europa.eu/eurostat/estat-navtree-portlet-prod/BulkDownloadListing?sort=1&dir=comext\%2F201706\%2Fdata")
str(recentfiles)
# Archive folder
archive <- scraplistoffilesincomext("http://ec.europa.eu/eurostat/estat-navtree-portlet-prod/BulkDownloadListing?sort=1&dir=comext\%2F2016S1\%2Fdata")
}
\dontrun{
# List files available on the comext metadata page
comextmetadata <- scraplistoffilesincomextfolder(comextfolderpath = getOption("comext")["metadatafolder"],
                                                 extension = ".txt")

# List files available on the comext COMEXT_DATA/PRODUCTS page
comextcontent <- scraplistoffilesincomextfolder(comextfolderpath = getOption("comext")["datafolder"]) \%>\%
    # Extract year and month information from the file name
    mutate(year = as.numeric(substr(file,5,8)),
           month = as.numeric(substr(file,9,10)))
comextcontent$file
# keep only monhly data
comextmonthly <- comextcontent \%>\%
    filter(month < 20)
# filter yearly data
comextyearly <- comextcontent \%>\%
    filter(month > 20)
# keep only monthly data from the past 4 years
comextmonthlyrecent <- comextcontent \%>\%
    filter(year > as.numeric(format(Sys.time(), "\%Y")) - 5 &
               month < 20)
}
}
