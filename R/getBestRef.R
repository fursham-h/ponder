#' Title
#'
#' @param queryGRanges 
#' @param basicTxGRanges 
#'
#' @return
#' @export
#'
#' @examples
getBestRef <- function(queryGRanges, basicTxGRanges){
  
  # this function attempts to select the best reference for analysis if multiple
  # reference transcripts exists
    # build GRanges object for query and GRangeslist object for reference

    # calculate the coverage of query and reference transcripts as a percentage
    # of the mean width of query and reference
    overlapHits = IRanges::mergeByOverlaps(queryGRanges, basicTxGRanges)

    overlapHitsMeta = base::mapply(function(x,y){
      widthQuery = sum(IRanges::width(x))
      widthRef = sum(IRanges::width(y))
      aveWidth = (widthQuery + widthRef) / 2
      commonCoverage = sum(IRanges::width(GenomicRanges::reduce(GenomicRanges::intersect(x, y))))
      Shared_coverage = commonCoverage/aveWidth
      return(Shared_coverage)
    }, overlapHits$queryGRanges, overlapHits$basicTxGRanges) %>%
      as.data.frame() # output list as a dataframe
    
    if(nrow(overlapHitsMeta) == 0) {
      return(list(Ref_transcript_ID = as.character(NA),
                  Coverage = 0))
    }

    # append reference tx IDs, sort dataframe and select best reference
    overlapHitsMeta$Ref_transcript_ID = names(overlapHits$basicTxGRanges)
    names(overlapHitsMeta) = c('Coverage', 'Ref_transcript_ID')
    overlapHitsMeta = overlapHitsMeta %>%
      dplyr::arrange(desc(Coverage)) %>%
      dplyr::select(Ref_transcript_ID, Coverage)

    return(overlapHitsMeta[1,])
    
}