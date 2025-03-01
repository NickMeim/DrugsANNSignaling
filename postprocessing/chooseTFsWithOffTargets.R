library(tidyverse)
library(xlsx)
library(ggplot2)
library(ggpubr)
library(ggsignif)
library(RColorBrewer)
library(patchwork)
library(ggforce)
library(ggsignif)
library(ggstatsplot)
library(ggrepel)
library(factoextra)


# Visualize Delta1 vs TF activity and with validation correlation------------------------------------------
performance <- data.table::fread('../results/A375_ensembles/meanCorrPerTFEnsembleVal_lamda6.csv',
                                 header=T)
performance <- performance %>% dplyr::select(-model) %>% unique()
performance <- performance %>% group_by(TF) %>% mutate(mean_r=mean(r)) %>%
  ungroup() %>% dplyr::select(-cell,-r) %>% unique()
base_cell_performance <- data.table::fread('../results/A375_ensembles/A375TrainEnsemblePerformance.csv')
colnames(base_cell_performance)[1] <- 'TF'
Delta <- data.table::fread('../results/A375_ensembles/DeltaTF1.csv',header=T)
# Load TF activities
TFoutput <- read.delim('../preprocessing/preprocessed_data/TF_activities/TrimmedFinal_l1000_allgenes_lvl3_tfs.tsv') %>% filter(X %in% Delta$V1) %>%
  column_to_rownames('X') %>% rownames_to_column('sample')
gc()
TFoutput <- TFoutput %>% gather('TF','activity',-sample) 
Delta <- Delta  %>% column_to_rownames('V1') %>%  rownames_to_column('sample') %>% gather('TF','delta',-sample)
# merge everything
df <- left_join(TFoutput,Delta,by=c('sample','TF'))
df <- left_join(df,performance)
df <- left_join(df,base_cell_performance)
df <- df %>% mutate(score=0.5*(mean_r+r))
# Load conditions to get rid of DMSO
conditions <- data.table::fread('../preprocessing/preprocessed_data/TrainingValidationData/L1000_lvl3_allcells-conditions_drugs.tsv',sep = "\t") %>% column_to_rownames('V1')
conditions <- conditions %>% rownames_to_column('sample') %>% gather('drug','value',-sample) %>% filter(value>0) %>%
  select(-value) %>% unique()
conditions <- conditions %>% filter(sample %in% df$sample) %>% filter(drug!='CS(C)=O')
annotation <- read.delim('../preprocessing/preprocessed_data/PKN/l1000_lvl3_withsignor-Annotation.tsv') %>% dplyr::select(c('TF'='code'),name)
annotation <- annotation %>% filter(TF %in% df$TF)
df <- left_join(df,annotation)
df <- left_join(df,conditions)
df <- df %>% filter(!is.na(drug))

interestingTFs = df %>% filter(!is.na(drug))  %>% 
  filter(mean_r>0.4 & score>=0.5) %>% 
  filter((delta>0.23 | delta<(-0.23)) & (activity>0.75 | activity<0.25))
interestingTFs <- interestingTFs %>% group_by(TF) %>% mutate(max_score=max(score)) %>%
  ungroup() %>% mutate(keep=ifelse(max_score==score,TRUE,FALSE))
interestingTFs <- interestingTFs %>% filter(keep==TRUE)
interestingTFs <- interestingTFs %>% group_by(TF) %>% mutate(max_score=max(abs(delta))) %>%
  ungroup() %>% mutate(keep=ifelse(max_score==abs(delta),TRUE,FALSE))
interestingTFs <- interestingTFs %>% filter(keep==TRUE)
drugs <- unique(interestingTFs$drug)
p <- ggplot(df %>% filter(!is.na(drug)),aes(x=-delta,y=activity,color=score)) +
  geom_point() + 
  scale_colour_gradient2(low = "blue",mid="white" ,high = "red",midpoint = 0.4,limits=c(0,0.72)) + xlab(expression(Delta*"TF")) + ylab('DoRothEA inferred TF activity') + 
  geom_vline(xintercept = -0.25,linetype = 'dashed') + geom_vline(xintercept = 0.25,linetype = 'dashed')+
  geom_hline(yintercept = 0.25,linetype = 'dashed') + geom_hline(yintercept = 0.75,linetype = 'dashed')+
  ylim(c(0,1)) +
  scale_x_continuous(breaks = c(-0.4,-0.2,0,0.2,0.4),limits = c(-0.4,0.45))+
  ggtitle('Off-target effects in A375 cell line')+
  theme_pubr() + 
  theme(text = element_text(size=24),legend.position = 'right',plot.title = element_text(hjust = 0.5))+
  geom_label_repel(data=interestingTFs,
            aes(label=name),
            box.padding   = 0.75, 
            point.padding = 0.5,
            max.overlaps = 50,
            segment.color = 'grey50',
            size = 7)
print(p)
ggsave('../figures/figure3B.eps',
       plot = p,
       device = cairo_ps,
       scale = 1,
       width = 12,
       height = 9,
       units = "in",
       dpi = 600)
# interestingTFs = df %>% filter(!is.na(drug))  %>% 
#   filter(mean_r>0.4 & score>=0.5) %>% 
#   filter((delta>0.23 | delta<(-0.23)) & (activity>0.75 | activity<0.25))
# interestingTFs <- interestingTFs %>% mutate(delta=-delta)
# interestingTFs <- interestingTFs %>% arrange(abs(delta),score,activity)
# colnames(interestingTFs)[c(2,8)] <- c('uniprot_id','TF')
# data_cmap <- readRDS("../preprocessing/preprocessed_data/all_cmap_sigs_with_pert_info.rds")
# interestingTFs <- left_join(interestingTFs,data_cmap %>% select(sig_id,pert_iname,pert_idose,pert_itime) %>% unique(),by=c('sample'='sig_id'))
data.table::fwrite(interestingTFs,
                   '../results/A375_ensembles/interestingSamples_A375.csv',
                   row.names = T)
