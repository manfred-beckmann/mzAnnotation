#' m/z relationship prediction
#' @description adduct, isotope and biotransfromation prediction.
#' @param mz numeric \code{vector} of accurate m/z
#' @param mode string of either 'p' or 'n; denoting the acquisition mode
#' @param limit limit of deviation for thresholding associations. Defaults to 0.001
#' @author Jasen Finch
#' @export
#' @importFrom utils combn
#' @examples 
#' res <- relationshipPredictor(c(132.03023,133.01425,133.03359,168.00691),'n')

relationshipPredictor <- function(mz,mode,limit=0.001){
  adducts <- MZedDB$ADDUCT_FORMATION_RULES
  isotopes <- MZedDB$ISOTOPE_RULES
  isotopes <- isotopes[!(isotopes$Isotope %in% c('Cl37','K41')),]
  isotopes <- data.frame(Isotope = c(NA,isotopes$Isotope),Difference = c(0,isotopes$Mass.Difference),stringsAsFactors = F)
  transformations <- MZedDB$BIOTRANSFORMATION_RULES
  transformations <- data.frame(Transformation = c(NA,transformations$MF.Change),Difference = c(0,transformations$Difference),stringsAsFactors = F)
  if (mode == 'p') {
    adducts <- adducts[adducts$Nelec < 0,]  
  }
  if (mode == 'n') {
    adducts <- adducts[adducts$Nelec > 0,]
  }
  
  M  <- lapply(mz,function(x,add,charge,xM,name){
    m <- ((x - add)*charge)/xM
    names(m) <- name
    return(m)
  },add = adducts$Add,charge = adducts$Charge,xM = adducts$xM,name = adducts$Name)
  
  names(M) <- mz
  
  combinations <- combn(mz,2)
  
  diffs <- apply(combinations, MARGIN = 2,function(x,M,limit,isotopes,transformations){
    add1 <- M[[as.character(x[1])]]
    add2 <- M[[as.character(x[2])]]
    diffs <- lapply(add1,function(x,a){
      abs(x - a)
    },a = add2)
    diffs <- as.data.frame(diffs)
    colnames(diffs) <- rownames(diffs)
    res <- apply(isotopes,1,function(y,diffs,limit,transformations){
      diffs <- abs(diffs - as.numeric(y[2]))
      res <- apply(transformations,1,function(z,diffs,limit){
        diffs <- abs(diffs - as.numeric(z[2]))
        res <- data.frame(Adduct1 = colnames(diffs)[which(diffs < limit,arr.ind = T)[,2]],
                          Adduct2 = rownames(diffs)[which(diffs < limit,arr.ind = T)[,1]],
                          stringsAsFactors = F)
        if (nrow(res) > 0) {
          errors <- apply(res,1,function(a,diffs){diffs[a[2],a[1]]},diffs = diffs)
          res <- data.frame(res,Error = errors,stringsAsFactors = F)
        }
        return(res)
      },diffs = diffs,limit = limit)
     names(res) <- transformations$Transformation
     res <- ldply(res,.id = 'Transformation')
     return(res)
    },diffs = diffs,limit = limit,transformations = transformations)
   names(res) <- isotopes$Isotope
   res <- ldply(res,.id = 'Isotope')
   return(res)
  },M = M,limit = limit,isotopes = isotopes,transformations = transformations)
  
  names(diffs) <- apply(combinations,2,function(x){paste(x,collapse = '~')})
  
  diffs <- ldply(diffs,stringsAsFactors = F)
  mzS <- strsplit(diffs$.id,'~')
  mzS <- ldply(mzS,stringsAsFactors = F)
  mzS <- data.frame(matrix(apply(mzS,2,as.numeric),ncol = 2))
  colnames(mzS) <- c('mz1','mz2')
  diffs <- diffs[,-1]
  diffs <- data.frame(mzS,diffs,stringsAsFactors = F)
  return(diffs)
}
