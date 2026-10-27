source("backend/R/data.R")
raw <- read.csv(text = paste(
  "name,year,selling_price,km_driven,fuel,seller_type,transmission,owner,engine,max_power,seats",
  "Maruti Swift,2018,450000,45000,Petrol,Individual,Manual,First Owner,1197 CC,81.8 bhp,5",
  "Maruti Swift,2018,450000,45000,Petrol,Individual,Manual,First Owner,1197 CC,81.8 bhp,5",
  "Land Rover Discovery,2017,2500000,70000,Diesel,Dealer,Automatic,Second Owner,2993 CC,,7",
  "Honda City,2015,-100,80000,Petrol,Individual,Manual,First Owner,1497 CC,118 bhp,5",
  sep = "\n"), stringsAsFactors = FALSE, check.names = FALSE)
prepared <- prepare_vehicles(raw)
stopifnot(prepared$report$raw_rows == 4,
          prepared$report$exact_duplicates_removed == 1,
          prepared$report$invalid_rows_removed == 1,
          nrow(prepared$vehicles) == 2,
          prepared$vehicles$brand[[2]] == "Land Rover",
          prepared$vehicles$engine_cc[[1]] == 1197,
          is.na(prepared$vehicles$max_power_bhp[[2]]))
bad <- raw
bad$engine <- NULL
stopifnot(inherits(try(prepare_vehicles(bad), silent = TRUE), "try-error"))
message("Dataset audit checks passed.")
