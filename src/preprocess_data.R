# One-time: parse the raw Excel file and cache a cleaned, lightweight .rds
# so app.R doesn't need to re-parse a 45MB xlsx on every startup.
library(readxl)
library(janitor)
library(dplyr)
library(stringr)
library(lubridate)
library(here)

min_price    <- 0.01
min_quantity <- 1

sales_clean <- readxl::read_excel(here::here("data/raw/online_retail_II.xlsx")) |>
  janitor::clean_names() |>
  mutate(
    invoice_date = as.Date(invoice_date),
    month        = floor_date(invoice_date, "month"),
    year         = year(invoice_date),
    is_return    = str_starts(invoice, "C"),
    revenue      = price * quantity
  ) |>
  filter(
    !is_return,
    !is.na(customer_id),
    price    >= min_price,
    quantity >= min_quantity
  )

dir.create(here::here("data/processed"), showWarnings = FALSE)
saveRDS(sales_clean, here::here("data/processed/sales_clean.rds"))
message("Saved ", nrow(sales_clean), " rows to data/processed/sales_clean.rds")
