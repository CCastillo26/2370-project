source("week2_analysis.R")

library(lidR)
library(terra)
library(raster)
library(xgboost)
library(data.table)

raw_path <- "/Users/charlycastillo/Documents/GitHub/2370-project/ollape_nomanual.las"
rf_path <- "/Users/charlycastillo/Downloads/ollape_3DMASC.las"
xgb_model <- "ollape_xgb_model.rds"
xgb_out_las <- "ollape_xgb_classified.las"

out_dir <- "Outputs"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

bst <- readRDS(xgb_model)
raw_pc <- readLAS(raw_path)

df_raw <- as.data.frame(raw_pc@data)
X_full <- as.matrix(df_raw[, feature_cols, drop = FALSE])

d_full <- xgb.DMatrix(X_full)
p_full <- predict(bst, d_full)
pred_all <- as.integer(p_full >= 0.5) # 1 = veg, 0 = other

raw_pc@data$pred_xgb <- pred_all
raw_pc@data$prob_xgb <- p_full

writeLAS(raw_pc, file.path(out_dir, xgb_out_las))

pc_xgb_clean <- filter_poi(raw_pc, pred_xgb == 0) # Cleaned, only non-veg
writeLAS(pc_xgb_clean, file.path(out_dir, "ollape_xgb_noveg.las"))

rf_pc <- readLAS(rf_path)

# DTMs (0.5 m)
dtm_raw_r <- rasterize_terrain(raw_pc, res = 0.5, algorithm = knnidw())
dtm_rf_r <- rasterize_terrain(rf_pc, res = 0.5, algorithm = knnidw())
dtm_xgb_r <- rasterize_terrain(pc_xgb_clean,res = 0.5, algorithm = knnidw()) 

dtm_raw_file <- file.path(out_dir, "dtm_raw_0p5m.tif")
dtm_rf_file <- file.path(out_dir, "dtm_rf_0p5m.tif")
dtm_xgb_file <- file.path(out_dir, "dtm_xgb_0p5m.tif")

raster::writeRaster(dtm_raw_r, dtm_raw_file, overwrite = TRUE)
raster::writeRaster(dtm_rf_r,  dtm_rf_file,  overwrite = TRUE)
raster::writeRaster(dtm_xgb_r, dtm_xgb_file, overwrite = TRUE)

# DSMs (0.5 m)
dsm_raw_r <- rasterize_canopy(raw_pc, res = 0.5, algorithm = p2r()) 
dsm_rf_r <- rasterize_canopy(rf_pc, res = 0.5, algorithm = p2r())
dsm_xgb_r <- rasterize_canopy(pc_xgb_clean, res = 0.5, algorithm = p2r())

dsm_raw_file <- file.path(out_dir, "dsm_raw_0p5m.tif")
dsm_rf_file <- file.path(out_dir, "dsm_rf_0p5m.tif") 
dsm_xgb_file <- file.path(out_dir, "dsm_xgb_0p5m.tif")

raster::writeRaster(dsm_raw_r, dsm_raw_file, overwrite = TRUE)
raster::writeRaster(dsm_rf_r, dsm_rf_file,  overwrite = TRUE) 
raster::writeRaster(dsm_xgb_r, dsm_xgb_file, overwrite = TRUE)

# CHMs (DSM - DTM)
chm_raw_r <- dsm_raw_r - dtm_raw_r
chm_rf_r  <- dsm_rf_r  - dtm_rf_r
chm_xgb_r <- dsm_xgb_r - dtm_xgb_r

chm_raw_file <- file.path(out_dir, "chm_raw_0p5m.tif")
chm_rf_file <- file.path(out_dir, "chm_rf_0p5m.tif") 
chm_xgb_file <- file.path(out_dir, "chm_xgb_0p5m.tif")

raster::writeRaster(chm_raw_r, chm_raw_file, overwrite = TRUE)
raster::writeRaster(chm_rf_r,  chm_rf_file,  overwrite = TRUE)
raster::writeRaster(chm_xgb_r, chm_xgb_file, overwrite = TRUE)

dtm_raw <- terra::rast(dtm_raw_file)  
dtm_rf  <- terra::rast(dtm_rf_file)  
dtm_xgb <- terra::rast(dtm_xgb_file)  


# Viewpoint visibility
vp_df <- data.frame(
  id = c("central_cluster", "south_house_road", "east_outskirts"),
  x  = c(187535.463765, 187588.523466, 187626.812165), # Sse Xg (global) from CloudCompare
  y  = c(9282237.912880, 9281995.043273, 9282264.158760) # Use Yg (global) from CloudCompare
)

observer_height <- 1.5  # Meters above ground

e <- terra::ext(dtm_raw)
inside <- with(vp_df, x >= e$xmin & x <= e$xmax & y >= e$ymin & y <= e$ymax)
if (!all(inside)) {
  print(vp_df[!inside, ])
  stop("One or more viewpoints fall outside the DTM extent.")
}

for (i in seq_len(nrow(vp_df))) {
  this_id <- vp_df$id[i]
  this_xy <- c(vp_df$x[i], vp_df$y[i]) # Numeric (x, y)
  
  # Raw
  vs_raw <- terra::viewshed(dtm_raw, this_xy, observer = observer_height)
  writeRaster(
    vs_raw,
    file.path(out_dir, paste0("vis_raw_", this_id, "_0p5m.tif")),
    overwrite = TRUE
  )
 
  vs_rf <- terra::viewshed(dtm_rf, this_xy, observer = observer_height)
  writeRaster(
    vs_rf,
    file.path(out_dir, paste0("vis_rf_", this_id, "_0p5m.tif")),
    overwrite = TRUE
  )
  
  # XGB
  vs_xgb <- terra::viewshed(dtm_xgb, this_xy, observer = observer_height)
  writeRaster(
    vs_xgb,
    file.path(out_dir, paste0("vis_xgb_", this_id, "_0p5m.tif")),
    overwrite = TRUE
  )
}

# Create confidence levels 
raw_pc@data$conf_xgb <- pmin(1, abs(raw_pc@data$prob_xgb - 0.5) * 2)

conf_grid_r <- grid_metrics(raw_pc, ~mean(conf_xgb, na.rm = TRUE), res = 0.5)
conf_file <- file.path(out_dir, "conf_xgb_0p5m.tif")
raster::writeRaster(conf_grid_r, conf_file, overwrite = TRUE)

conf_class <- terra::classify(
  terra::rast(conf_file),
  rcl = matrix(c(-Inf, 0.60, 1,
                 0.60, 0.80, 2,
                 0.80, Inf,  3),
               ncol = 3, byrow = TRUE)
)
writeRaster(conf_class, file.path(out_dir, "confclass_xgb_0p5m.tif"), overwrite = TRUE)
