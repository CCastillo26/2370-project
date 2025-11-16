library(lidR)
library(tidyverse)
library(xgboost)

veg_pc <- readLAS("/Users/charlycastillo/Documents/veg_pc.las")
other_pc <- readLAS("/Users/charlycastillo/Documents/other_pc.las")

veg_df <- veg_pc@data # Convert point cloud to df
other_df <- other_pc@data

veg_df$label <- 1L
other_df$label <- 0L

df <- bind_rows(veg_df, other_df)
df <- as_tibble(df)

feature_cols <- c("X", "Y", "Z", "Intensity", "ReturnNumber", "NumberOfReturns",
                  "R", "G", "B")

X <- as.matrix(df[, feature_cols])
y <- df$label


# Create xgboost model
set.seed(123)

n   <- nrow(df)

max_n <- 500000   # adjust up/down depending on how slow things feel

if (n > max_n) {
  keep_idx <- sample(n, max_n)    
  X <- X[keep_idx, , drop = FALSE]
  y <- y[keep_idx]        
  n <- length(y)                
}

idx <- sample(n) 

train_end <- floor(0.8 * n)   # first 80% -> train, last 20% -> test

train_idx <- idx[1:train_end]
test_idx  <- idx[(train_end + 1):n]

dtrain <- xgb.DMatrix(X[train_idx, ], label = y[train_idx])
dtest  <- xgb.DMatrix(X[test_idx,  ], label = y[test_idx])

params <- list(
  objective        = "binary:logistic", 
  eval_metric      = "logloss", 
  max_depth        = 6,  
  eta              = 0.1,   
  subsample        = 0.8,     
  colsample_bytree = 0.8       
)

nrounds <- 200

bst <- xgb.train(
  params  = params,
  data    = dtrain,
  nrounds = nrounds,
  verbose = 1
)



# Evaluate on remaining points; metrics
p_test <- predict(bst, dtest)

y_test_true <- y[test_idx]
y_test_pred <- as.integer(p_test >= 0.5)

# Confusion matrix
table(True = y_test_true, Pred = y_test_pred)

tp <- sum(y_test_true == 1 & y_test_pred == 1)
fp <- sum(y_test_true == 0 & y_test_pred == 1)
fn <- sum(y_test_true == 1 & y_test_pred == 0)

precision <- tp / (tp + fp)          
recall    <- tp / (tp + fn)            
f1        <- 2 * precision * recall / (precision + recall)

precision
recall
f1
