#' @title Logo plot representation of an MFF file.
#'
#' @description Creates a logo plot representation of the probability distribution
#' of the different mismatch features - mismatch, flanking bases, strand break and
#' position of mismatch - for a single MFF (.csv) file.
#'
#' @param file a MismatchFeatureFormat (MFF) .csv file.
#' @param logo.control The control parameters for the logo plot representation of the sample.
#'                     Check the input parameters of \code{damageLogo5()} for the control parameters.
#' @param background if equals "modern", as in the default, compares enrichment
#'                   of mismatch features against a modern background - else
#'                   uses a background with equal probability of all mismatch
#'                   features.
#' @param title The name of the sample. If not provided, defaults to the filename.
#' @param output_file The filename (with path) of the constructed logo plot.
#'
#' @return Creates a logo plot of the mismatch features for a single
#'         MFF file.
#' @keywords archaic_view
#' @importFrom  Logolas get_viewport_logo nlogomaker
#' @import gridBase
#' @import grid
#' @import ggplot2
#' @export



archaic_view = function(file,
                        logo.control = list(),
                        background = "modern",
                        title = NULL,
                        output_file = NULL){

  header <- head(strsplit(rev((as.vector(strsplit(file, "/" )[[1]])))[1], ".csv")[[1]],1)
  if(is.null(title)){
    title <- header
  }

  if(length(strsplit(file, "/")[[1]]) == 1){
    dir <- getwd()
  }else{
    ss <- strsplit(file, "/")[[1]]
    ll <- length(ss)
    dir <- paste0(paste0(ss[1:(ll-1)],collapse="/"), "/")
  }



  logo.control.default <- list(max_pos = 20, flanking_bases=1,
                               mutlogo.control = list(),
                               breaklogo.control = list(),
                               base_probs_list = NULL,
                               clip = 0,
                               mut_ranges = c(0,0),
                               break_ranges = c(0,0),
                               logoport_x = 0.7,
                               logoport_y= 0.5,
                               logoport_width= 1, logoport_height= 1.2,
                               breaklogoport_x = 0.55, breaklogoport_y = 0.4,
                               breaklogoport_width=0.7,
                               breaklogoport_height=1, lineport_x = 0.65,
                               lineport_y=0.5,
                               lineport_width=0.8, lineport_height=1.3,
                               output_width = 1200, output_height = 700)
  if(background == "null"){
    logo.control.default$base_probs_list = NULL
  }else{
    data("base_probs_moderns")
    logo.control.default$base_probs_list = base_probs_moderns
    logo.control.default$mut_ranges = c(1, 1)
    logo.control.default$break_ranges = c(1, 1)
  }


  logo.control <- modifyList(logo.control.default, logo.control)


  if(file.exists(paste0(dir, tail(strsplit(dir, "/")[[1]],1), ".rda"))){
    message(".RData file present: using the .RData object to learn the feature probabilities")
    mff_dat <- get(load(paste0(dir, tail(strsplit(dir, "/")[[1]],1), ".rda")))
    index <- grep(paste0(header), rownames(mff_dat))
    clubbed_counts <- mff_dat[index, ]
    clubbed_counts_norm <- clubbed_counts/ sum(clubbed_counts)

    temp <- as.matrix(clubbed_counts_norm)
    rownames(temp) <- names(clubbed_counts_norm)

  }else{
    message(".RData file present: looking for the MFF .csv file")
    if(!file.exists(paste0(dir, header, ".csv"))){
      stop("The file is not found in the given directory")
    }
    files_to_process <- csvnames
    csvnames2 <- substr(csvnames, 1, nchar(csvnames) - 4)
    signature_counts_from_file <- vector(mode="list")
    signatures_file <- vector(mode="list")


    for(numfile in 1:length(files_to_process)){
      tmp_dat <- damage_build_bin_counts(file = paste0(dirs[numdir], files_to_process[numfile]),
                                         max_pos = max_pos,
                                         type=2)
      signature_counts_from_file[[numfile]] <- tmp_dat[,2]
      signatures_file[[numfile]] <- tmp_dat[,1]
      cat("Reading file ", paste0(dirs[numdir], files_to_process[numfile]), "\n")
    }

    merged_signatures <- signatures_file[[1]]

    if(length(files_to_process) >= 2){
      for(num in 2:length(files_to_process)){
        merged_signatures <- union(merged_signatures, signatures_file[[num]])
      }
    }

    ancient_counts <- matrix(0, length(files_to_process),
                             length(merged_signatures))
    for(num in 1:length(files_to_process)){
      ancient_counts[num, match(signatures_file[[num]],
                                merged_signatures)] <- signature_counts_from_file[[num]]
    }

    flanking_bases = 1
    signature_split <- do.call(rbind, lapply(merged_signatures,
                                             function(x) strsplit(as.character(x),
                                                                  split="")[[1]][1:(4+2*flanking_bases+6)]))
    indices1 <- which(signature_split[,(flanking_bases+1)]==signature_split[,(flanking_bases+4)])
    wrong_letters <- c("B", "D", "E", "F", "H", "I", "J", "K", "L", "M", "N", "O",
                       "P", "Q", "R", "S", "U", "V", "W", "X", "Y", "Z")
    temp <- list()
    for(l in 1:length(wrong_letters)){
      temp[[l]] <- grep(paste0(wrong_letters[l]), merged_signatures)
    }

    indices2 <- Reduce(union, temp)
    indices <- union(indices1, indices2)
    ancient_counts_filtered <- matrix(ancient_counts[, -indices],
                                      nrow = nrow(ancient_counts))

    rownames(ancient_counts_filtered) <- csvnames2
    if(length(indices) > 0){
      colnames(ancient_counts_filtered) <- merged_signatures[-indices]
    }else{
      colnames(ancient_counts_filtered) <- merged_signatures
    }

    outdat <- club_signature_counts(ancient_counts_filtered)
    clubbed_counts_norm <- clubbed_counts/ sum(clubbed_counts)

    temp <- t(clubbed_counts_norm)
  }

  if(is.null(output_file)){
    output_dir <- paste0(getwd(), "/", "logo.png")
  }

  do.call(damageLogo_six_temp, append(list(theta_pool = temp,
                                       output_dir = output_dir,
                                       filename = filename),
                                  logo.control))
}


# @title Builds damage logo plots based on full mutation signatures (mutation, flanking base, position, strand and strand break)
#
# @description Damage Logo plots for each cluster from the GoM model fit. It showcases the
# different mutational features - for example, mutation, flanking base, position on read,
# strand and strand break information for each cluster.
#
# @param theta_pool The theta matrix obtained from running the grade of membership model that stores for each cluster, the
# probability distribution over all the mutational signatures.
# @param sig_names The mutational signature names. Defaults to the rownames of the theta matrix above.
# @param max_pos The maximum distance from the end of the read upto which mutations are considered.
# @param flanking_bases The number of flanking bases of the mutational signature.
# @param mutlogo.control The control parameters for the mismatch and flanking bases logo.
# @param breaklogo.control The control parameters for the logo for strand break.
# @param logoport_x the X-axis position of the plot window for the logo plot
# @param logoport_y the Y-axis position of the plot window for the logo plot
# @param logoport_width the width of the plot window for the logo plot
# @param logoport_height the width of the plot window for the logo plot
# @param lineport_x the X-axis position of the plot window for the mutational profile line plot.
# @param lineport_y the Y-axis position of the plot window for the mutational profile line plot.
# @param lineport_width the width of the plot window for the mutational profile line plot.
# @param lineport_height the width of the plot window for the mutational profile line plot.
# @return Returns logo plots for each cluster
# @param breaklogoport_x the X-axis position of the plot window for strand break logo plot.
# @param breaklogoport_y the Y-axis position of the plot window for the strand break logo plot.
# @param breaklogoport_width the width of the plot window for the strand break logo plot.
# @param breaklogoport_height the width of the plot window for the strand break logo plot.
# @param output_dir The directory where the logo plot will be saved.
# @param output_width The width of the logo plot figure.
# @param output_height the height of the logo plot figure.
#
# @return Returns logo plot for each cluster
#
# @import grid
# @import gridBase
#
# @export


damageLogo_six_temp <- function(theta_pool,
                           sig_names = NULL,
                           max_pos = 20,
                           flanking_bases=1,
                           mutlogo.control = list(),
                           breaklogo.control = list(),
                           base_probs_list = NULL,
                           clip = 0,
                           mut_ranges  = c(0, 0),
                           break_ranges = c(0, 0),
                           logoport_x = 0.7,
                           logoport_y= 0.5,
                           logoport_width= 1.2,
                           logoport_height= 1.1,
                           breaklogoport_x = 0.5,
                           breaklogoport_y = 0.4,
                           breaklogoport_width=0.7,
                           breaklogoport_height=1,
                           lineport_x = 0.4,
                           lineport_y=0.5,
                           lineport_width=1,
                           lineport_height=1,
                           output_dir = NULL,
                           filename = NULL,
                           output_width = 1200,
                           output_height = 700){
  library(grid)
  library(gridBase)


  if(is.null(output_dir)){output_dir <- getwd();}
  flag <- 0
  if(dim(theta_pool)[2] == 1){
    flag = 1
    theta_pool <- cbind(theta_pool, theta_pool)
    colnames(theta_pool) <- c("sample1", "sample2")
  }
  signature_set <- rownames(theta_pool)
  signature_patterns <- substring(signature_set, 1, 4+2*flanking_bases)
  library(dplyr)
  theta2 <- dplyr::tbl_df(data.frame(theta_pool)) %>%
    dplyr::mutate(sig = signature_patterns) %>%
    dplyr::group_by(sig) %>%
    dplyr::summarise_all(funs(sum)) %>%
    as.data.frame()
  rownames(theta2) <-  theta2[,1]
  theta2 <- theta2[,-1, drop=FALSE]

  indices_minus <- grep("_-_", signature_set)
  strand_theta <- data.frame("minus" = colSums(theta_pool[indices_minus,]),
                             "plus" = colSums(theta_pool[-indices_minus,]))

  if(flag == 1){
    strand_theta <- data.frame("minus" = colSums(matrix(theta_pool[indices_minus,])),
                               "plus" = colSums(matrix(theta_pool[-indices_minus,])))
    strand_theta <- strand_theta/2;
  }
  breakbase <- substring(signature_set, 8+2*flanking_bases,  8+2*flanking_bases)

  theta_break <- dplyr::tbl_df(data.frame(theta_pool)) %>%
    dplyr::mutate(sig = breakbase) %>%
    dplyr::group_by(sig) %>%
    dplyr::summarise_all(funs(sum)) %>%
    as.data.frame()
  rownames(theta_break) <- theta_break[,1]
  theta_break <- theta_break[,-1]

  theta_break <- theta_break[match(c("A", "C", "G", "T"), rownames(theta_break)),]
  breaks_theta <- theta_break


  if(is.null(sig_names))
    sig_names <- rownames(theta_pool)

  # prob_mutation <- filter_by_pos(t(theta_pool), max_pos = max_pos)
  prob_mutation <- filter_signatures_only_location(t(theta_pool),
                                                   max_pos = max_pos, flanking_bases = flanking_bases)
  prob_mutation <- t(apply(prob_mutation, 1, function(x) {
    y <- x[!is.na(x)];
    return(y/sum(y))
  }))
  max_prob <- max(prob_mutation);
  clipped_bases <- setdiff(1:20, as.numeric(colnames(prob_mutation)))

  if(is.null(base_probs_list)){
    prob_limits = c(round(min(prob_mutation), 2)-0.01, round(max(prob_mutation), 2) + 0.01)
    prob_breaks = c(0, round(min(prob_mutation),2)-0.01,
                    round(0.5*(min(prob_mutation)+max(prob_mutation)), 2),
                    round(max(prob_mutation), 2)+0.01)
  }else{
    if(length(clipped_bases) > 0){
      prob1_mutation <- prob_mutation - t(replicate(dim(prob_mutation)[1], as.numeric(base_probs_list[[(2 * flanking_bases + 3)]])[-clipped_bases]))
    }else{
      prob1_mutation <- prob_mutation - t(replicate(dim(prob_mutation)[1], as.numeric(base_probs_list[[(2 * flanking_bases + 3)]])))
    }
    colnames(prob1_mutation) <- colnames(prob_mutation)
    prob_limits = c(round(min(prob1_mutation), 2)-0.01, round(max(prob1_mutation), 2) + 0.01)
    prob_breaks = c(0, round(min(prob1_mutation),2)-0.01,
                    round(0.5*(min(prob1_mutation)+max(prob1_mutation)), 2),
                    round(max(prob1_mutation), 2)+0.01)
  }

  sig_split <- do.call(rbind,
                       lapply(sig_names,
                              function(x) strsplit(as.character(x), split="")[[1]][1:(4+2*flanking_bases)]))

  ncol_sig <- (4+2*flanking_bases)

  if(flanking_bases%%1 != 0){
    stop("flanking bases not evenly distributed")
  }


  sub_pattern <- sapply(1:dim(sig_split)[1],
                        function(x) paste(sig_split[x,(flanking_bases+1):(flanking_bases+4)], collapse=""))

  new_sig_split <- cbind(sig_split[,1:flanking_bases], sub_pattern, sig_split[,((ncol_sig - flanking_bases +1):ncol_sig)])
  colnames(new_sig_split) = NULL

  prop_patterns_list <- list()

  for(l in 1:dim(theta_pool)[2]){
    prop_patterns_list[[l]] <- numeric();
    for(j in 1:ncol(new_sig_split)){
      temp2 <- tapply(theta_pool[,l], factor(new_sig_split[,j], levels=c("A", "C", "G", "T",
                                                                         "C->T", "C->A", "C->G",
                                                                         "T->A", "T->C", "T->G")), sum)

      prop_patterns_list[[l]] <- cbind(prop_patterns_list[[l]], temp2)
    }
  }


  grob_list <- list()
  if(flag == 1){
    l = 1
    if(is.null(filename)){
      filename <- "logo"
    }
    png(paste0(output_dir, filename, ".png"), width=output_width, height = output_height)
    damageLogo_six.skeleton_temp(pwm = prop_patterns_list[[l]],
                            probs = prob_mutation[l,],
                            breaks_theta_vec = breaks_theta[,l, drop=FALSE],
                            prob_limits = prob_limits,
                            prob_breaks = prob_breaks,
                            mutlogo.control = mutlogo.control,
                            breaklogo.control = breaklogo.control,
                            background = base_probs_list,
                            clip = clip,
                            mut_ranges = mut_ranges,
                            break_ranges = break_ranges,
                            flanking_bases = flanking_bases,
                            logoport_x = logoport_x,
                            logoport_y= logoport_y,
                            logoport_width= logoport_width,
                            logoport_height= logoport_height,
                            breaklogoport_x = breaklogoport_x,
                            breaklogoport_y = breaklogoport_y,
                            breaklogoport_width=breaklogoport_width,
                            breaklogoport_height=breaklogoport_height,
                            lineport_x = lineport_x,
                            lineport_y= lineport_y,
                            lineport_width=lineport_width,
                            lineport_height=lineport_height)
    dev.off()
  }else{
    for(l in 1:length(prop_patterns_list)){
      png(paste0(output_dir, "logo_clus_", l, ".png"), width=output_width, height = output_height)
      damageLogo_six.skeleton_temp(pwm = prop_patterns_list[[l]],
                              probs = prob_mutation[l,],
                              breaks_theta_vec = breaks_theta[,l, drop=FALSE],
                              prob_limits = prob_limits,
                              prob_breaks = prob_breaks,
                              mutlogo.control = mutlogo.control,
                              breaklogo.control = breaklogo.control,
                              background = base_probs_list,
                              clip = clip,
                              mut_ranges = mut_ranges,
                              break_ranges = break_ranges,
                              flanking_bases = flanking_bases,
                              logoport_x = logoport_x,
                              logoport_y= logoport_y,
                              logoport_width= logoport_width,
                              logoport_height= logoport_height,
                              breaklogoport_x = breaklogoport_x,
                              breaklogoport_y = breaklogoport_y,
                              breaklogoport_width=breaklogoport_width,
                              breaklogoport_height=breaklogoport_height,
                              lineport_x = lineport_x,
                              lineport_y= lineport_y,
                              lineport_width=lineport_width,
                              lineport_height=lineport_height)
      dev.off()
    }
  }
}


damageLogo_six.skeleton_temp <- function(pwm,
                                    probs,
                                    breaks_theta_vec,
                                    prob_limits,
                                    prob_breaks,
                                    mutlogo.control = list(),
                                    breaklogo.control = list(),
                                    background = NULL,
                                    clip = 0,
                                    mut_ranges = c(0, 0),
                                    break_ranges = c(0, 0),
                                    flanking_bases = 1,
                                    logoport_x = 0.7,
                                    logoport_y= 0.5,
                                    logoport_width= 1.2,
                                    logoport_height= 1.1,
                                    breaklogoport_x = 0.5,
                                    breaklogoport_y = 0.4,
                                    breaklogoport_width=0.7,
                                    breaklogoport_height=1,
                                    lineport_x = 0.4,
                                    lineport_y=0.5,
                                    lineport_width=1,
                                    lineport_height=1){

  mut_lowrange = mut_ranges[1]
  mut_uprange =  mut_ranges[2]

  break_lowrange = break_ranges[1]
  break_uprange =  break_ranges[2]

  mutlogo.control.default <- list(logoheight = "log",
                                  total_chars = c("A", "B", "C", "D", "E", "F", "G",
                                                  "H", "I", "J", "K", "L", "M", "N", "O",
                                                  "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y",
                                                  "Z", "zero", "one", "two",
                                                  "three", "four", "five", "six", "seven", "eight", "nine", "dot", "comma",
                                                  "dash", "colon", "semicolon", "leftarrow", "rightarrow"),
                                  frame_width=c(1,2,1), yscale_change=TRUE,
                                  pop_name = "Mismatch and \n flanking base composition",
                                  addlogos = NULL, addlogos_text = NULL, newpage = FALSE,
                                  yrange = NULL, xaxis=TRUE, yaxis=TRUE, xaxis_fontsize=23,
                                  y_fontsize=20, main_fontsize = 25,
                                  xlab_fontsize=25,
                                  start=0.001, xlab = "", ylab = "Enrichment Score",
                                  col_line_split="grey80", control = list(epsilon=0.25,gap_ylab=3.5, gap_xlab = 4,
                                                                          round_off = 1, posbins = 3, negbins = 3,
                                                                          lowrange = mut_lowrange, uprange = mut_uprange,
                                                                          size_port = 1, symm = FALSE))

  breaklogo.control.default <- list( logoheight = "log",
                                     total_chars = c("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
                                                     "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "zero", "one", "two",
                                                     "three", "four", "five", "six", "seven", "eight", "nine", "dot", "comma",
                                                     "dash", "colon", "semicolon", "leftarrow", "rightarrow"),
                                     frame_width=NULL, yscale_change=TRUE,
                                     pop_name = "base composition \n 5' of  strand break \n",
                                     addlogos = NULL, addlogos_text = NULL, newpage = FALSE,
                                     yrange = NULL, xaxis=FALSE, yaxis=TRUE, xaxis_fontsize=10,
                                     xlab_fontsize=18, y_fontsize=18, main_fontsize=25,
                                     start=0.001, xlab = "", ylab = "Enrichment Score",
                                     col_line_split="white", control = list(gap_ylab=3.5, epsilon = 0.01,
                                                                            round_off = 1, symm = TRUE,
                                                                            lowrange = break_lowrange,
                                                                            uprange = break_uprange))
  mutlogo.control <- modifyList(mutlogo.control.default, mutlogo.control)
  breaklogo.control <- modifyList(breaklogo.control.default, breaklogo.control)


  cols = RColorBrewer::brewer.pal.info[RColorBrewer::brewer.pal.info$category ==
                                         'qual',]
  col_vector = unlist(mapply(RColorBrewer::brewer.pal, cols$maxcolors, rownames(cols)))
  total_chars = c("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
                  "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "zero", "one", "two",
                  "three", "four", "five", "six", "seven", "eight", "nine", "dot", "comma",
                  "dash", "colon", "semicolon", "leftarrow", "rightarrow")

  set.seed(20)
  cols2 <- sample(col_vector, length(total_chars), replace=FALSE)
  cols2[match(c("A", "C", "G", "T"), total_chars)] <- c(RColorBrewer::brewer.pal(4,name ="Spectral"))
  color_profile_1 <- list("type" = "per_symbol",
                          "col" = cols2)

  if(!is.null(background)){
    base_probs_list <- background
    base_probs_mat <- matrix(NA, 10, 3)
    rownames(base_probs_mat) <- c("A", "C", "G", "T", "C->A", "C->G", "C->T", "T->A", "T->C", "T->G")
    for(l in 1:(2*flanking_bases+1)){
      base_probs_mat[match(names(base_probs_list[[l]]), rownames(base_probs_mat)),l] <- as.numeric(base_probs_list[[l]])
    }
    base_probs_mat <- base_probs_mat[match(rownames(pwm), rownames(base_probs_mat)),]
  }

  pwm1 <- pwm
  rownames(pwm1)[match(c("C->A", "C->G", "C->T",
                         "T->A", "T->C", "T->G"), rownames(pwm1))] <- c("C>A", "C>G", "C>T",
                                                                        "T>A", "T>C", "T>G")
  colnames(pwm1) <- c("left \n flank", "mismatch", "right \n flank")


  if(!is.null(background)){
    rownames(base_probs_mat)[match(c("C->A", "C->G", "C->T",
                                     "T->A", "T->C", "T->G"), rownames(base_probs_mat))] <- c("C>A", "C>G", "C>T",
                                                                                              "T>A", "T>C", "T>G")
    colnames(base_probs_mat) <- colnames(pwm1)
  }


  color_profile_2 = list("type" = "per_row",
                         "col" = RColorBrewer::brewer.pal(4,name ="Spectral"))



  Logolas::get_viewport_logo(1, 3)

  seekViewport(paste0("plotlogo", 1))
  vp1 <- viewport(x=logoport_x, y=logoport_y, width=logoport_width, height=logoport_height)
  pushViewport(vp1)
  if(!is.null(background)){
    do.call(Logolas::nlogomaker, append(list(table = pwm1,
                                    color_profile = color_profile_1,
                                    bg = base_probs_mat),
                               mutlogo.control))
  }else{
    do.call(Logolas::nlogomaker, append(list(table = pwm1,
                                    color_profile = color_profile_1,
                                    bg = NULL),
                               mutlogo.control))
  }
  upViewport(0)

  if(is.null(background)){

    pos_data <- data.frame(position = as.numeric(names(probs)),
                           val = as.numeric(probs))

    seekViewport(paste0("plotlogo", 2))
    vp2 = viewport(x = lineport_x, y = lineport_y, width=lineport_width, height=lineport_height)
    p <- ggplot(data=pos_data, aes(x=position,y=val)) +
      geom_point(size = 3, aes(colour = "red")) +
      geom_line(aes(colour = "red"))+
      ggtitle("Location of \n mismatch in read" ) +
      labs(x="position in read",y="probability of mismatch") +
      scale_x_continuous(limits = c(0, 20))  +
      scale_y_continuous(limits = prob_limits,
                         breaks = prob_breaks) +
      theme_bw() + theme(panel.border = element_blank(), panel.grid.major = element_blank(),
                         panel.grid.minor = element_blank(), axis.line = element_line(colour = "black")) +
      theme(axis.title.x = element_text(size = 20), axis.title.y = element_text(size = 20)) +
      theme(axis.text.x = element_text(colour="black", hjust=0.8, size = 18),
            axis.text.y = element_text(size = 18, hjust=0.8, colour = "black")) +
      theme(axis.title.y = element_text(margin = margin(t = 0, r = 20, b = 0, l = 0))) +
      theme(axis.title.x = element_text(margin = margin(t = 20, r = 0, b = 0, l = 0))) +
      theme(plot.title = element_text(size = 25)) +
      theme(plot.title = element_text(margin=margin(b = 30, unit = "pt"))) +
      theme(plot.title = element_text(hjust = 0.5))+
      theme(legend.position="none") +
      theme(axis.ticks.length=unit(0.3,"cm")) +
      geom_hline(yintercept=0, linetype="dashed")
    print(p, vp = vp2)

  }else{
    bg_pos_vec <- base_probs_list[[(2*flanking_bases+3)]]
    probs1 <- (probs+1e-10) - (bg_pos_vec[match(names(probs), names(bg_pos_vec))]+1e-10)
    # probs1 <- probs1 - median(probs1)
    num_pos <- length(as.numeric(probs1))
    pos_data <- data.frame(position = as.numeric(names(probs)[(clip+1):num_pos]),
                           val = as.numeric(probs1)[(clip+1):num_pos])
    seekViewport(paste0("plotlogo", 2))
    vp2 = viewport(x = lineport_x, y = lineport_y, width=lineport_width, height=lineport_height)
    p <- ggplot(data=pos_data, aes(x=position,y=val)) +
      geom_point(size = 3, aes(colour = "red")) +
      geom_line(aes(colour = "red"))+
      ggtitle("Location of \n mismatch in read" ) +
      labs(x="position in read",y="enrichment in probability") +
      scale_x_continuous(limits = c(0, 20))  +
      scale_y_continuous(limits = prob_limits,
                         breaks = prob_breaks) +
      theme_bw() + theme(panel.border = element_blank(), panel.grid.major = element_blank(),
                         panel.grid.minor = element_blank(), axis.line = element_line(colour = "black")) +
      theme(axis.title.x = element_text(size = 20), axis.title.y = element_text(size = 20)) +
      theme(axis.text.x = element_text(colour="black", hjust=0.8, size = 18),
            axis.text.y = element_text(size = 18, hjust=0.8, colour = "black")) +
      theme(axis.title.y = element_text(margin = margin(t = 0, r = 20, b = 0, l = 0))) +
      theme(axis.title.x = element_text(margin = margin(t = 20, r = 0, b = 0, l = 0))) +
      theme(plot.title = element_text(size = 25)) +
      theme(plot.title = element_text(margin=margin(b = 30, unit = "pt"))) +
      theme(plot.title = element_text(hjust = 0.5))+
      theme(legend.position="none") +
      theme(axis.ticks.length=unit(0.3,"cm")) +
      geom_hline(yintercept=0, linetype="dashed")
    print(p, vp = vp2)

  }


  seekViewport(paste0("plotlogo", 3))
  vp3 <- viewport(x=breaklogoport_x, y=breaklogoport_y, width=breaklogoport_width, height=breaklogoport_height)
  pushViewport(vp3)
  if(!is.null(background)){
    bg_breaks_theta_vec <- matrix(base_probs_list[[(2*flanking_bases+2)]], ncol=1)
    rownames(bg_breaks_theta_vec) <- names(base_probs_list[[(2*flanking_bases+2)]])
    colnames(bg_breaks_theta_vec) <- colnames(breaks_theta_vec)
    do.call(Logolas::nlogomaker, append(list(table = breaks_theta_vec,
                                    color_profile = color_profile_2,
                                    bg = bg_breaks_theta_vec),
                               breaklogo.control))
  }else{
    do.call(Logolas::nlogomaker, append(list(table = breaks_theta_vec,
                                    color_profile = color_profile_2,
                                    bg = NULL),
                               breaklogo.control))
  }

  upViewport(0)
}

