rm(list=ls())

library(ComplexHeatmap)
library(scales) # for color scale
library(mgcv)
library(ggpmisc)
library(ggbeeswarm)
library(readxl)
library(RColorBrewer)
library(viridis)
library(ggsci)
library(rebus)
library(matrixStats)
library(limSolve)
library(xlsx)
library(cowplot)
library(rstatix)
library(ggpubr)
library(tidyverse)

load("/Users/boyuan/Desktop/Harvard/Manuscript/1. fluxomics/raw data/8_core_flux extrapolation.RData")
setwd("/Users/boyuan/Desktop/Harvard/Manuscript/1. fluxomics/")

library(ggiraph)


# Plot flux network
d.directFlux_interConversion.selected = d.directFlux_interConversion %>% 
  select(phenotype, targetCompound, sources, nmol.min.animal.mean) %>% 
  filter(phenotype %in% c("WT", "HFD", "ob/ob")) %>% 
  mutate(nmol.min.animal.mean = round(nmol.min.animal.mean, 2))

# compound in order in network, clockwisely
ordered.Compound.network =  
  c("Lactate","Glucose", 
    "Glycerol", "C16:0", "C18:1", "C18:2", "3-HB", "Glutamine", "Valine", "Alanine") 


# function to abbreviate the label name
func.abbreviate <-  function(x){
  x <- x %>% str_replace("Glucose", "Glc")
  x <- x %>% str_replace("Lactate", "Lac")
  x <- x %>% str_replace("Alanine", "Ala")
  x <- x %>% str_replace("3-HB", "3-HB")
  x <- x %>% str_replace("Valine", "Val")
  x <- x %>% str_replace("Glutamine", "Gln")
  x <- x %>% str_replace("Glycerol", "Gly")
  
}

d.directFlux_interConversion.selected = d.directFlux_interConversion.selected %>% 
  mutate(targetCompound = factor(targetCompound, levels = ordered.Compound.network, ordered = T))





# calculate metabolite coordinate in the network 
n.compound = ordered.Compound.network %>% length()
theta.delta = 2 * pi / n.compound
theta = 2/pi + theta.delta * c(1:n.compound)

coord.x = cos(theta)   
coord.y = sin(theta)  

# assign position to each metabolite in clockwise order 
names(coord.x) = ordered.Compound.network
names(coord.y) = ordered.Compound.network

d.directFlux_interConversion.selected.coordinated = 
  d.directFlux_interConversion.selected %>% 
  mutate(coord.x.target = coord.x[targetCompound],
         coord.y.target = coord.y[targetCompound])

# Anchor points of target compound circle
d.anchor_Metabolite = d.directFlux_interConversion.selected.coordinated %>% 
  select(targetCompound, coord.x.target, coord.y.target) %>% distinct()



# flux to CO2 and to non-Ox sink
d.destiny.CO2.sink = d.destiny %>% 
  select(phenotype, Compounds, destiny, nmol.min.animal.mean) %>% 
  mutate(nmol.min.animal.mean = round(nmol.min.animal.mean, 2)) %>% 
  filter(destiny %in% c("non-Ox sink", "CO2")) %>% 
  rename(targetCompound  = Compounds) %>% mutate(targetCompound = as.character(targetCompound)) %>% 
  
  filter(phenotype %in% c("WT", "ob/ob")) %>% 
  
  left_join(d.anchor_Metabolite %>% mutate(targetCompound = as.character(targetCompound))) %>% # add nutrient coord position
  mutate(coord.x.CO2 = 0, coord.y.CO2 = 0)



# Inter-conversion flux among circulating nutrients
d.layer.interConvert = 
  d.directFlux_interConversion.selected.coordinated %>%
  mutate(sources = as.character(sources)) %>% 
  filter(sources != "storage") %>% 
  
  left_join(d.anchor_Metabolite %>% rename(sources = targetCompound, 
                                           coord.x.source = coord.x.target, 
                                           coord.y.source = coord.y.target))  # add coord of source 



# Define edge size 
nmol.min.animal = c(d.destiny.CO2.sink$nmol.min.animal.mean, # flux to CO2 and non-Ox sink
                    d.directFlux_interConversion.selected$nmol.min.animal.mean) %>% unique() # interconversion flux and flux from storage to nutrients

cutoff.flx = 5000 # nmol/min/animal
fold.maxFlx.cutOff = (max(nmol.min.animal) / cutoff.flx) %>% ceiling()

# ----- Big flx: 20,000 ~ 4,000  nmol/min/animal
nmol.min.animal.BigFlx = nmol.min.animal[nmol.min.animal >= cutoff.flx] %>% sort()
size.range_Big = seq(10/fold.maxFlx.cutOff, 12, length.out = length(nmol.min.animal.BigFlx)) %>% round(2)

# plot(size.range_Big, nmol.min.animal.BigFlx)

mdl.size_big = lm(size.range_Big ~  nmol.min.animal.BigFlx )
nmol.min.animal.BigFlx.fitted = predict(mdl.size_big)

names(nmol.min.animal.BigFlx.fitted) = nmol.min.animal.BigFlx
nmol.min.animal.BigFlx.fitted


# ----- Mid flx: 4,000 ~ 800 nmol/min/animal (five fold lower)
nmol.min.animal.mid_Flx = nmol.min.animal[nmol.min.animal < cutoff.flx & nmol.min.animal >= cutoff.flx/5 ] %>% sort()
size.range_Mid = seq(1, nmol.min.animal.BigFlx.fitted %>% min() - .5, # max of mid-flx size using the min of fitted value of large flux size
                     length.out = length(nmol.min.animal.mid_Flx)) %>% round(2) 

# plot(size.range_Mid, nmol.min.animal.mid_Flx)

mdl.size_Mid = lm(size.range_Mid ~  nmol.min.animal.mid_Flx )
nmol.min.animal.Mid.Flx.fitted = predict(mdl.size_Mid)

names(nmol.min.animal.Mid.Flx.fitted) = nmol.min.animal.mid_Flx
nmol.min.animal.Mid.Flx.fitted



# ----- small flx: 800 ~ 160 nmol/min/animal (another five fold lower)
nmol.min.animal.small_Flx = nmol.min.animal[nmol.min.animal < cutoff.flx/5 & nmol.min.animal >= cutoff.flx/5/5] %>% sort()
size.range_small = seq(0, min(nmol.min.animal.Mid.Flx.fitted) - .5,
                       length.out = length(nmol.min.animal.small_Flx)) %>% round(2) 

# plot(size.range_small, nmol.min.animal.small_Flx)

mdl.size_small = lm(size.range_small ~  nmol.min.animal.small_Flx )
nmol.min.animal.Small_Flx.fitted = predict(mdl.size_small)

names(nmol.min.animal.Small_Flx.fitted) = nmol.min.animal.small_Flx
nmol.min.animal.Small_Flx.fitted


nmol.min.animal.Flxes.fitted = c(nmol.min.animal.Small_Flx.fitted,
                                 nmol.min.animal.Mid.Flx.fitted,
                                 nmol.min.animal.BigFlx.fitted)

# Size testing
# k = tibble(flx = names(nmol.min.animal.Flxes.fitted) %>% as.double() , 
#            mysize = nmol.min.animal.Flxes.fitted %>% as.double() ) %>% as_tibble()
# k %>% 
#   ggplot(aes(x = flx, y = mysize, size = as.character(flx))) + 
#   geom_point(show.legend = F, position = position_jitter(1, 1))  +
#   scale_size_manual(values = nmol.min.animal.Flxes.fitted)

# PLOT

curveColor.store = "steelblue4"
curveColor.interconvert = "turquoise4"
curveAlpha = .7
curvature.S.S = .7

func.plt.network = function(whichPhenotype = "WT"){
  
  d.directFlux_interConversion.selected.coordinated.i = 
    d.directFlux_interConversion.selected.coordinated %>% 
    filter(phenotype == whichPhenotype) %>% 
    mutate(pair = str_c(sources, "→", targetCompound))
  
  d.destiny.CO2.sink.i = d.destiny.CO2.sink %>% 
    filter(phenotype == whichPhenotype) %>% 
    mutate(pair = str_c(targetCompound, "→", destiny ))
  
  d.layer.interConvert.i = d.layer.interConvert %>% 
    filter(phenotype == whichPhenotype) %>% 
    mutate(pair = str_c(sources, "→", targetCompound))
  
  d.anchor_Metabolite.i = d.anchor_Metabolite %>% 
    filter(phenotype == whichPhenotype)
  
  
  # layer 1
  # flux from storage to metabolites, defining the boundary of the plot
  p1 = ggplot() + 
    geom_curve_interactive(
      
      data = d.directFlux_interConversion.selected.coordinated.i %>%
        mutate(sources = as.character(sources)) %>% 
        filter(sources == "storage"),
      
      aes(x = coord.x.target * 1.8, 
          y = coord.y.target * 1.8, 
          xend = coord.x.target , 
          yend = coord.y.target,
          size = nmol.min.animal.mean %>% as.character(),
          
          data_id = pair, 
          tooltip = paste(whichPhenotype, "\n", sources, "→", targetCompound,":\n", 
                           round(nmol.min.animal.mean, 0), "nmol C/min")),
      curvature = curvature.S.S, color = curveColor.store, alpha = curveAlpha) 
  
  
  p2 = p1 +
    # add flux back to non-Ox sink
    geom_curve_interactive(
      
      data = d.destiny.CO2.sink.i %>% filter(destiny == "non-Ox sink"),
      
      aes( x = coord.x.target, 
           y = coord.y.target, 
           xend = coord.x.target * 1.8,
           yend = coord.y.target * 1.8,  
           size = nmol.min.animal.mean %>% as.character(),
           
           data_id = pair, 
           tooltip = paste(whichPhenotype, "\n", targetCompound, "→", destiny, ":\n",
                            round(nmol.min.animal.mean, 0), "nmol C/min")
      ),
      curvature = curvature.S.S, color = curveColor.store, alpha = curveAlpha) +
    
    
    # add flux to CO2
    geom_curve_interactive(data = d.destiny.CO2.sink.i %>% filter(destiny == "CO2"),
               aes(x = coord.x.target, y = coord.y.target, 
                   xend = 0, yend = 0, 
                   size = nmol.min.animal.mean %>% as.character(),
                   data_id = pair, 
                   tooltip = paste(whichPhenotype, "\n", targetCompound, "→", destiny, ":\n",
                                    round(nmol.min.animal.mean, 0), "nmol C/min")),
               curvature = 0.4, color = "firebrick", alpha = curveAlpha) 
  
  
  p3 = p2 +  
    # large flux 
    geom_curve_interactive(data = d.layer.interConvert.i %>% filter(nmol.min.animal.mean >  cutoff.flx ),
               aes(x = coord.x.source,    y = coord.y.source,
                   xend = coord.x.target, yend = coord.y.target,
                   size = nmol.min.animal.mean %>% as.character(),
                   data_id = pair, 
                   tooltip = paste(whichPhenotype, "\n", sources, "→", targetCompound, ":\n",
                                    round(nmol.min.animal.mean, 0), "nmol C/min")),
               curvature = .25, color = curveColor.interconvert, alpha = curveAlpha) +
    
    # Mid flux
    geom_curve_interactive(data = d.layer.interConvert.i %>% filter( nmol.min.animal.mean <= cutoff.flx & nmol.min.animal.mean > cutoff.flx / 4),
               aes(x = coord.x.source,    y = coord.y.source,
                   xend = coord.x.target, yend = coord.y.target,
                   size = nmol.min.animal.mean %>% as.character(),
                   data_id = pair, 
                   tooltip = paste(whichPhenotype, "\n", sources, "→", targetCompound, ":\n",
                                    round(nmol.min.animal.mean, 0), "nmol C/min")
                   ),
               curvature = .25, color = curveColor.interconvert, alpha = curveAlpha ) +
    # # small flux
    geom_curve_interactive(data = d.layer.interConvert.i %>% filter( nmol.min.animal.mean <= cutoff.flx/4 & nmol.min.animal.mean > cutoff.flx/4/4),
               aes(x = coord.x.source,    y = coord.y.source,
                   xend = coord.x.target, yend = coord.y.target,
                   size = nmol.min.animal.mean %>% as.character(),
                   data_id = pair, 
                   tooltip = paste(whichPhenotype, "\n", sources, "→", targetCompound, ":\n",
                                    round(nmol.min.animal.mean, 0), "nmol C/min")
                   ),
               curvature = .25, color = curveColor.interconvert, alpha = curveAlpha) +
    # minimal flux
    geom_curve_interactive(data = d.layer.interConvert.i %>% filter( nmol.min.animal.mean <= cutoff.flx/4/4 & nmol.min.animal.mean > 100),
               aes(x = coord.x.source,    y = coord.y.source,
                   xend = coord.x.target, yend = coord.y.target,
                   data_id = pair,
                   tooltip = paste( sources, "→", targetCompound,
                                    round(nmol.min.animal.mean, 0), "nmol C/min")
                   ),
               size = .15,
               curvature = .2, color = curveColor.interconvert, alpha = curveAlpha) +
    # minimal trace flux
    geom_curve(data = d.layer.interConvert.i %>% filter( nmol.min.animal.mean <= 100 & nmol.min.animal.mean > 10),
               aes(x = coord.x.source,    y = coord.y.source,
                   xend = coord.x.target, yend = coord.y.target,
                   data_id = pair,
                   tooltip = paste( sources, "→", targetCompound,
                                    round(nmol.min.animal.mean, 0), "nmol C/min")),
               size = 0.1, 
               curvature = .2, color = curveColor.interconvert, alpha = curveAlpha/1.2) 
  
  # layer 4: nutrient names
  p4 = p3 + 
    # storage / non-Ox sink
    geom_label( data = d.anchor_Metabolite.i, 
                aes(label = "S", x = coord.x.target* 1.8, y = coord.y.target*1.8), 
                size = 7, fontface = "bold", fill = "snow2", 
                label.padding = unit(2, "mm")) +
    
    # nutrients
    geom_label( data = d.anchor_Metabolite.i, 
                aes(label = targetCompound %>% func.abbreviate(),
                    x = coord.x.target, y = coord.y.target),
                size = 6.4, fontface = "bold", fill = "yellow", 
                label.padding = unit(2, "mm"),
                # rounded corner
                label.r = unit(10, "pt"),
                label.size = NA) +
    
    # CO2 background
    annotate(geom = "point", x = 0, y = 0, stroke = 1,
             alpha = .8, fill = "seashell", color = "firebrick", size = 25, shape = 21)  +
    
    # CO2 logo
    annotate("text", x = -.05, y = .01, label = 'bold("CO")',
             colour = "firebrick4", size= 8, parse = T) +
    
    annotate("text", x = .23, y = -.06 , label = 'bold("2")',
             colour = "firebrick4",  size = 6, parse = T) 
  
  p5 = p4 + 
    scale_size_manual(values = nmol.min.animal.Flxes.fitted)  +
    coord_fixed() +
    theme_void() +
    theme(legend.title = element_blank(),
          legend.position = "NA")  
  
  p5 + ggtitle(paste(whichPhenotype, "\n")) +
    theme(plot.title = element_text(size = 22, face = "bold", hjust = .5)) 
  
}

plt.network.WT = func.plt.network(whichPhenotype = "WT")
girafe(ggobj = plt.network.WT)

plt.network.ob = func.plt.network(whichPhenotype = "ob/ob")
library(patchwork)
library(cowplot)

plt.WT.ob <- plot_grid(plt.network.WT, 
          ggplot() + theme_void(),
          plt.network.ob, 
          rel_widths = c(1, .1, 1), nrow = 1)

girafe(ggobj = plt.WT.ob,
       width_svg = 10*1.2, height_svg = 5*1.2,
       options = list(
         opts_tooltip(# use_cursor_pos = F, offx = 100, offy = 30,
                      use_cursor_pos = T, offx = 30, offy = 30,
                      css = "padding:10px;background-color:#006666;color:white;font-weight: bold;font-size:140%")
       ))

