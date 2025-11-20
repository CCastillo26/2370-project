library(lidR)
library(terra)
library(xgboost)
library(data.table)

bst <- readRDS("ollape_xgb_model.rds")

raw_pc <- readLAS("/Users/charlycastillo/Downloads/ollape_nomanual.las")

df_raw <- as.data.frame(raw_pc@data)
feature_use <- intersect(feature_cols, names(df_raw))
X_full <- as.matrix(df_raw[, feature_use])

d_full <- xgb.DMatrix(X_full)
p_full <- predict(bst, d_full)
pred_all <- as.integer(p_full >= 0.5) # 1 = veg, 0 = other

raw_pc@data$pred_xgb <- pred_all
raw_pc@data$prob_xgb <- p_full

writeLAS(raw_pc, "ollape_xgb_classified.las")

dtm_raw <- rasterize_terrain(raw_pc, res = 0.5, algorithm = knnidw())

writeRaster(dtm_raw, "dtm_raw_0p5m.tif", overwrite = TRUE)

# Create XGBoost-cleaned DTM
pc_clean <- filter_poi(raw_pc, pred_xgb == 0)

dtm_xgb <- rasterize_terrain(pc_clean, res = 0.5, algorithm = knnidw())

writeRaster(dtm_xgb, "dtm_xgb_0p5m.tif", overwrite = TRUE)
