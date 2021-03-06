#' Test transcripts for annotated start codons
#'
#' @description This function will test whether the query transcript contain an annotated 
#' Start codon from a reference CCDS of the gene
#' 
#' @usage 
#' testTXforStart(refCDS, queryTranscript, full.output = FALSE)
#' 
#' @param refCDS A GRanges object containing CCDS information of a gene family
#' @param queryTranscript A GRanges object containing exon structure of a query transcript from
#' the same gene family
#' @param full.output If TRUE, function will output additional information 

#' @return
#' By default, function will return a TRUE/FALSE boolean (annotatedStart)
#' 
#' If full.output is TRUE, function will output other information which include:
#' (1) the length of the first coding exon (firstexlen), 
#' (2) queryTranscript GRanges with 5' end appended to the start codon  (ORF),  
#' (3) a list of GRanges objects similar to 'indentifyAddedRemovedRegions()' output (txrevise_out). 
#' ?indentifyAddedRemovedRegions for more information
#' 
#' 
#' @author Fursham Hamid
#' 
#' @examples
#' 
#' testTXforStart(ptbp2Data$transcripts$ENSMUST00000197833, ptbp2Data$refCDS)
#' testTXforStart(ptbp2Data$afCDS, ptbp2Data$refCDS)
#' 
#' 
testTXforStart <- function(queryTranscript, refCDS, full.output = FALSE) {
  
  # prepare output of function
  output = list(ORF_start = 'Not found',
                txrevise_out = NA,
                firstexlen = NA)
  
  # combine both GRanges objects into a list and identify segments which are different
  combinedList = list(refTx = refCDS, testTx = queryTranscript)
  diffSegments = suppressWarnings(indentifyAddedRemovedRegions("refTx", "testTx", combinedList[c("refTx", "testTx")]))
  
  # test if the transcript contain same start codon as in CDS
    # do not test if transcript and CDS do not overlap at all
  if (is.null(diffSegments)) {
    output = utils::modifyList(output, 
                        list(txrevise_out = NA, 
                             ORF_start = 'Not found'))
  } else if (length(diffSegments$refTx$upstream[diffSegments$refTx$upstream == TRUE]) == 0) {
    # transcripts that contain same start codon as CDS will return true for the above if statement
    
    # and also calculate size of first coding exon
    lenfirstsharedexon = IRanges::width(sort(diffSegments$shared_exons[1], decreasing = (as.character(strand(refCDS))[1] == '-')))
    output = utils::modifyList(output, 
                        list(txrevise_out = diffSegments, 
                             ORF_start = 'Annotated', 
                             firstexlen = lenfirstsharedexon))
  } else {
    # transcripts that overlap with CDS but do not contain an annotated start codon
    output = utils::modifyList(output, 
                        list(txrevise_out = diffSegments, 
                             ORF_start = 'Not found'))
  }
  ifelse(full.output == TRUE, return(output), return(output["ORF_start"]))
}





#' Reconstruct CDS with alternate 5' exons
#'
#' @description This function will reconstruct a CDS sequence with a 5' end 
#' taken from a query transcript from the same gene
#' 
#' @usage function(queryTranscript, refCDS, txrevise_out, fasta, full.output = FALSE)
#' 
#' @param refCDS A GRanges object containing reference CDS information of a gene family
#' @param queryTranscript A GRanges object containing exon structure of a query transcript from
#' the same gene family
#' @param txrevise_out Optional input. GRangesobject from 'indentifyAddedRemovedRegions()' 
#' or 'testTXforStart()' output. ?indentifyAddedRemovedRegions or ?testTXforStart
#' for more information
#' @param fasta Fasta sequence file
#' @param full.output if TRUE, function will output additional information
#' 
#' @return 
#' Default output (ORF_considered),
#' If reconstructed CDS contain an in-frame ATG, function will output a GRanges Object describing the
#' reconstructed CDS. Else, function will output 'NA'
#' 
#' If full.output == TRUE,
#' function will also return a list of GRanges objects similar to 'indentifyAddedRemovedRegions()' output (txrevise_out). 
#' ?indentifyAddedRemovedRegions for more information
#' 
#' 
#' @author Fursham Hamid
#'
#' @examples
#' 
#' reconstructCDSstart(ptbp2Data$afCDS, ptbp2Data$refCDS, fasta = Ensembl_mm10)
#' 
reconstructCDSstart <- function(queryTranscript, refCDS, fasta, txrevise_out = NULL, full.output = FALSE) {
  
  out = list(ORF_considered = NA, txrevise_out = NA, ORF_start = 'Not found')
  
  # check if txrevise_out input is provided, and build one if not.
  if (missing(refCDS) | missing(queryTranscript)) {
    stop('Please provide input GRanges objects')
  } else if (is.null(txrevise_out)) {
    combinedList = list(refTx = refCDS, testTx = queryTranscript)
    diffSegments = indentifyAddedRemovedRegions("refTx", "testTx", combinedList[c("refTx", "testTx")])
  } else {
    diffSegments = txrevise_out
  }
  
  # obtain strand information and anchor exon
  queryStrand = as.character(strand(diffSegments[[3]]))[1]
  
  # construct anew transcript with 5' exons coming from query and
  # 3' exons from CDS
  reconstructedTx = sort(append(
    diffSegments$shared_exons, c(
      reduce(diffSegments[[1]][diffSegments[[1]]$upstream != TRUE]),
      reduce(diffSegments[[2]][diffSegments[[2]]$upstream == TRUE]))),
    decreasing = queryStrand == '-')
  
  # prepares sequence of query
  thisqueryseq = unlist(Biostrings::getSeq(fasta, reconstructedTx))
  
  # find all in-frame start codons in reconstructed transcript
  # it is vital that the last codon is a stop codon
  list_startstopcodons = Biostrings::DNAStringSet(c('ATG',"TAA", "TAG", "TGA"))
  pdict_startstopcodons = Biostrings::PDict(list_startstopcodons)
  StartStopCodons = Biostrings::matchPDict(pdict_startstopcodons, thisqueryseq)
  
  if (length(unlist(StartStopCodons)) > 0) {
    
    # unlist the list of matches and annotate its type (Start/Stop)
    type = c(rep('Start', length(StartStopCodons[[1]])), 
             rep('Stop', length(unlist(StartStopCodons))- length(StartStopCodons[[1]])))
    StartStopCodons = unlist(StartStopCodons)
    elementMetadata(StartStopCodons)$type = type
    inFrameStartStopCodons = sort(StartStopCodons[(sum(IRanges::width(reconstructedTx)) - (end(StartStopCodons))) %%3 == 0,])
    len_inFrameStartStopCodons = length(inFrameStartStopCodons)
    
    if (len_inFrameStartStopCodons > 0) {
      
      # this part removes continuous stretches of Start or Stop codons
      # and chooses only its first alternating occurence 
      #   (ie Start,Start,Start,Stop,Stop,Start -> Start,Stop,Start)
      inFrameStartStopCodons = inFrameStartStopCodons[1:(len_inFrameStartStopCodons-1)]
      shiftype = c('Stop', head(elementMetadata(inFrameStartStopCodons)$type, 
                                length(elementMetadata(inFrameStartStopCodons)$type)-1))
      elementMetadata(inFrameStartStopCodons)$shiftype = shiftype
      inFrameStartStopCodons = inFrameStartStopCodons[elementMetadata(inFrameStartStopCodons)$type != elementMetadata(inFrameStartStopCodons)$shiftype]
      
      # return ORF only if an in-frame start codon is found
      #   done by checking if size of object is an odd number
      if (length(inFrameStartStopCodons) %% 2 == 1) {
        predictedStart = inFrameStartStopCodons[length(inFrameStartStopCodons)]
        
        # append 5' end of reconstructed transcript to the start codon
        upUTRsize = start(predictedStart) - 1
        setORF = resizeTranscripts(reconstructedTx, start = upUTRsize)
        
        # obtain txrevise output
        combinedList = list(refTx = setORF, testTx = queryTranscript)
        diffSegments = indentifyAddedRemovedRegions("refTx", "testTx", combinedList[c("refTx", "testTx")])
        out = list(ORF_considered = setORF, txrevise_out = diffSegments, ORF_start = 'In-frame ATG')
        
        if (is.null(diffSegments)) {
          out = list(ORF_considered = NA, txrevise_out = NA, ORF_start = 'Not found')
        }
      }
    }
  }
  ifelse(full.output == TRUE, return(out), return(out["ORF_considered"]))
}

