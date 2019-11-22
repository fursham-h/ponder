

#' _ workflow: Test transcripts for NMD feature
#' 
#' @description 
#' THIS FUNCTION IS PART OF THE _ PROGRAM WORKFLOW.
#' This function will analyze the assembled transcripts for NMD features
#'
#' @param report_df 
#' dataframe of a list of assembled transcripts. It is recommended to create this object using
#' prepareAnalysis function from the workflow. see ?prepareAnalysis
#' @param basicTX_df 
#' dataframe of a list of reference CDS transcripts. It is recommended to create this object using
#' prepareAnalysis function from the workflow. see ?prepareAnalysis
#' @param inputExonsbyTx 
#' GRangesList of exon coordinates of assembled transcripts grouped by transcript name. It is recommended to create this object using
#' prepareAnalysis function from the workflow. see ?prepareAnalysis
#' @param basicExonsbyCDS 
#' GRangesList of exon coordinates of reference CDS grouped by transcript name. It is recommended to create this object using
#' prepareAnalysis function from the workflow. see ?prepareAnalysis
#' @param genome 
#' DNAstring containing genome sequence
#' @param PTC_dist 
#' Numerical value referring to minimium distance of premature stop codon to last exon junction
#' @param testNonClassicalNMD 
#' Boolean value (TRUE/FALSE) on whether to test for non-classical NMD features
#'
#' @return
#' updated form of report_df
#'
#' @examples
runMain <- function(report_df, inputExonsbyTx, basicExonsbyCDS, 
                            basicExonsbyTx, genome, 
                            testforNMD = TRUE, PTC_dist = 50, 
                            testNonClassicalNMD = FALSE, 
                            testforAS = FALSE) {
  
  # this is an internal function for testing NMD features on report_df rowwise
  internalfunc = function(x) {
    
    # convert each line into a list so that elements 
    # can be referenced as thisline$_
    thisline = as.list(x)
    
    # Prepare list of reference transcript and GRanges
    thisline$Ref_transcript_ID = strsplit(thisline$Ref_transcript_ID, split = '_')
    queryGRanges = inputExonsbyTx %>% 
      dplyr::filter(group_name == thisline$Transcript_ID) %>%
      dplyr::arrange(ifelse(strand == '+', start, desc(start))) %>% 
      GenomicRanges::makeGRangesListFromDataFrame(keep.extra.columns = TRUE, split = 'group_name')
    
    basicTxGRanges = basicExonsbyTx %>% 
      dplyr::filter(group_name %in% thisline$Ref_transcript_ID[[1]]) %>%
      dplyr::arrange(ifelse(strand == '+', start, desc(start))) %>% 
      GenomicRanges::makeGRangesListFromDataFrame(keep.extra.columns = TRUE, split = 'group_name')

    # this function attempts to select the best reference for analysis 
    outBestRef = getBestRef(queryGRanges, basicTxGRanges)
    
    if(is.na(outBestRef$Ref_transcript_ID)){
      # return as query and reference do not match
      return(thisline)
    } else {
      # create new GRanges
      basicCDSGRanges = basicExonsbyCDS %>% 
        dplyr::filter(group_name %in% outBestRef$Ref_transcript_ID) %>%
        dplyr::arrange(ifelse(strand == '+', start, desc(start))) %>% 
        GenomicRanges::makeGRangesListFromDataFrame(keep.extra.columns = TRUE, split = 'group_name')
      basicTxGRanges = basicExonsbyTx %>% 
        dplyr::filter(group_name %in% outBestRef$Ref_transcript_ID) %>%
        dplyr::arrange(ifelse(strand == '+', start, desc(start))) %>% 
        GenomicRanges::makeGRangesListFromDataFrame(keep.extra.columns = TRUE, split = 'group_name')
      
      # update reference transcript and coverage
      thisline$Ref_transcript_ID = outBestRef$Ref_transcript_ID
      thisline$Coverage = outBestRef$Coverage
      
      # set query ORF if it is similar to reference
      if(outBestRef$Coverage == 1) {
        thisline$ORF_considered = basicCDSGRanges
        thisline$ORF_start = 'Annotated'
        thisline$ORF_found = TRUE
      }
    }
    
    # attempt to build ORF for query if absent
    if(thisline$ORF_found == FALSE){
      # attempt to build Open Reading Frame for query
      ORFreport = getORF(basicCDSGRanges, queryGRanges,
                         genome, thisline$Gene_ID,
                         thisline$NMDer_ID)
      thisline = utils::modifyList(thisline, ORFreport)
    }

    # if requested, test for NMD features and update line entry
    if (testforNMD == TRUE) {
      NMDreport = testNMD(thisline$ORF_considered, 
                          queryGRanges, 
                          PTC_dist, 
                          testNonClassicalNMD,
                          genome)
      thisline = utils::modifyList(thisline, NMDreport)
    }
    
    # if requested, classify alternative splicing events and update line entry
    if (testforAS == TRUE) {
      if (testforNMD == FALSE) {
        ORF = NA
        is_NMD = NA
      } else {
        ORF = thisline$ORF_considered
        is_NMD = thisline$is_NMD
      }
      
      altevents = getASevents(basicTxGRanges, queryGRanges, 
                              testforNMD, ORF, is_NMD)
      
      thisline = utils::modifyList(thisline, altevents)
      
    }
    
    
    # update analyzed ORF coordinates into output
    if (!is.na(thisline$ORF_considered[1])) {
      thisline$ORF_considered = thisline$ORF_considered %>% as.data.frame()
    }
    rm(list = c('queryGRanges','basicCDSGRanges', 'basicTxGRanges'))
    return(thisline)

  }
  
  # run the above function on report_df
  report_df = report_df %>% 
    dplyr::rowwise() %>% 
    do(data.frame(internalfunc(.), stringsAsFactors = FALSE)) 
  
  return(report_df)
}





