library(lidR)
library(tidyverse)
library(xgboost)

pc <- readLAS("/Users/charlycastillo/Downloads/pc.las")




# Convert point cloud to df
# df <- pc@data

# Create binary label (1 = veg, 0 = other)
# df$label <- ifelse(df$vegetation_label > 0, 1, 0)

# Select needed variables
# ollape_df <- df[, c("Z", "R", "G", "B". "label")]

# Create train-test split
# set.seed(123)
# n <- nrow(ollape_df)
# train_idx <- sample(seq_len(n), size = 0.7 * n)