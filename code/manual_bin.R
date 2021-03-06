manual_bin <- function(df, yname, xname, cuts) {
  cuts <- sort(c(-Inf, cuts, Inf))
  df1 <- df[which(df[[yname]] %in% c(0, 1)), c(yname, xname)]
  all_cnt <- nrow(df1)
  all_bcnt <- sum(df1[[yname]])
  ### IDENTIFY DIFFERENT CASES WITH MISSING VALUES ###
  if (all(!is.na(df1[[xname]])) == TRUE) {
    miss_flg <- 0
    df2 <- df1
  }
  else {
    miss_flg <- 1
    df2 <- df1[!is.na(df1[, xname]), ]
    mis <- df1[is.na(df1[, xname]), ]
    mis_cnt <- nrow(mis)
    mis_bcnt <- sum(mis[[yname]])
    if (sum(mis[[yname]]) %in% c(nrow(mis), 0)) {
      miss_flg <- 2
    }
  }
  ### SLICE DATAFRAME BY CUT POINTS ###
  for (i in seq(length(cuts) - 1)) {
    bin <- sprintf("%02d", i)
    bin_cnt <- nrow(df2[which(df2[[xname]] > cuts[i] & df2[[xname]] <= cuts[i + 1]), ])
    bin_bcnt <- nrow(df2[which(df2[[xname]] > cuts[i] & df2[[xname]] <= cuts[i + 1] & df2[[yname]] == 1), ])
    if (i == 1) {
      bin_summ <- data.frame(bin = bin, xmin = cuts[i], xmax = cuts[i + 1], cnt = bin_cnt, bcnt = bin_bcnt)
    }
    else {
      bin_summ <- rbind(bin_summ,
                        data.frame(bin = bin, xmin = cuts[i], xmax = cuts[i + 1], cnt = bin_cnt, bcnt = bin_bcnt))
    }
  }
  bin_summ$mis_cnt <- 0
  ### FIRST CASE FOR MISSING VALUES: BOTH GOODS AND BADS ###
  if (miss_flg == 1) {
    bin_summ <- rbind(data.frame(bin = sprintf("%02d", 0), xmin = NA, xmax = NA, cnt = mis_cnt, bcnt = mis_bcnt, mis_cnt = mis_cnt),
                      bin_summ)
  }
  ### SECOND CASE FOR MISSING VALUES: ONLY GOODS OR BADS ###
  if (miss_flg == 2) {
    rate <- bin_summ$bcnt / bin_summ$cnt
    if (mis_bcnt == 0) {
      bin_summ[rate == min(rate), "cnt"] <- bin_summ[rate == min(rate), "cnt"] + mis_cnt
      bin_summ[rate == min(rate), "mis_cnt"] <- mis_cnt
    }
    else {
      bin_summ[rate == max(rate), "cnt"] <- bin_summ[rate == max(rate), "cnt"] + mis_cnt
      bin_summ[rate == max(rate), "bcnt"] <- bin_summ[rate == max(rate), "bcnt"] + mis_bcnt
      bin_summ[rate == max(rate), "mis_cnt"] <- mis_cnt
    }
  }
  bin_summ$dist <- bin_summ$cnt / all_cnt
  bin_summ$brate <- bin_summ$bcnt / bin_summ$cnt
  bin_summ$woe <- log((bin_summ$bcnt / all_bcnt) / ((bin_summ$cnt - bin_summ$bcnt) / (all_cnt - all_bcnt)))
  bin_summ$iv <- (bin_summ$bcnt / all_bcnt - (bin_summ$cnt - bin_summ$bcnt) / (all_cnt - all_bcnt)) * bin_summ$woe
  bin_summ$ks <- abs(cumsum(bin_summ$bcnt) / all_bcnt - cumsum(bin_summ$cnt - bin_summ$bcnt) / (all_cnt - all_bcnt)) * 100
  bin_summ$rule <- NA
  for (i in seq(nrow(bin_summ))) {
    if (bin_summ[i, ]$bin == '00') {
      bin_summ[i, ]$rule <- paste("is.na($X)", sep = '')
    }
    else if (bin_summ[i, ]$bin == '01') {
      if (bin_summ[i, ]$mis_cnt > 0) {
        bin_summ[i, ]$rule <- paste("$X <= ", bin_summ[i, ]$xmax, " | is.na($X)", sep = '')
      }
      else {
        bin_summ[i, ]$rule <- paste("$X <= ", bin_summ[i, ]$xmax, sep = '')
      }
    }
    else if (i == nrow(bin_summ)) {
      if (bin_summ[i, ]$mis_cnt > 0) {
        bin_summ[i, ]$rule <- paste("$X > ", bin_summ[i, ]$xmin, " | is.na($X)", sep = '')
      }
      else {
        bin_summ[i, ]$rule <- paste("$X > ", bin_summ[i, ]$xmin, sep = '')
      }
    }
    else {
        bin_summ[i, ]$rule <- paste("$X > ", bin_summ[i, ]$xmin, " & ", "$X <= ", bin_summ[i, ]$xmax, sep = '')
    }
  }
  
  return(result <- data.frame(Bin = bin_summ$bin, Rule = format(bin_summ$rule, width = 30, justify = "right"),
                              Frequency = bin_summ$cnt, Percent = round(bin_summ$dist, 2),
                              MV_Cnt = bin_summ$mis_cnt, Bad_Freq = bin_summ$bcnt, Bad_Rate = round(bin_summ$brate, 4),
                              WoE = round(bin_summ$woe, 4), InfoValue = round(bin_summ$iv, 4), KS_Stat = round(bin_summ$ks, 2)))
}

# SAMPLE OUTPUT:
#  Bin                           Rule Frequency Percent MV_Cnt Bad_Freq Bad_Rate     WoE InfoValue KS_Stat
#1  01                       $X <= 82       814    0.14      0       81     0.10 -0.8467    0.0764    9.02
#2  02             $X > 82 & $X <= 91       837    0.14      0      120     0.14 -0.4316    0.0234   14.44
#3  03             $X > 91 & $X <= 97       811    0.14      0      148     0.18 -0.1436    0.0027   16.35
#4  04            $X > 97 & $X <= 101       829    0.14      0      181     0.22  0.0806    0.0009   15.18
#5  05           $X > 101 & $X <= 107       870    0.15      0      206     0.24  0.1855    0.0054   12.26
#6  06           $X > 107 & $X <= 115       808    0.14      0      197     0.24  0.2241    0.0074    8.95
#7  07           $X > 115 | is.na($X)       868    0.15      1      263     0.30  0.5229    0.0468    0.00
