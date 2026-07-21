# ============================================================
# Script:  Sales Analysis — E-commerce Business
# Input:   data/raw/online_retail_II.xlsx
#          525,461 transactions | 8 columns | 2009–2011
# Output:  outputs/ — 5 plots + revenue_summary.csv
# ============================================================

# Load packages ----
library(tidyverse)
library(readxl)
library(janitor)
library(here)
library(scales)

# Load helper functions ----
source(here::here("R/plot_theme.R"))

# Define parameters ----
min_price    <- 0.01   # exclude free or incorrectly priced items
min_quantity <- 1      # exclude returns (negative quantity)

# Import data ----
sales_raw <- readxl::read_excel(here::here("data/raw/online_retail_II.xlsx"))

# Discover data structure ----
# glimpse(sales_raw)   # 525,461 rows x 8 cols
# head(sales_raw)      # inspect first rows
# names(sales_raw)     # list column names
# dim(sales_raw)       # confirm dimensions

# Clean column names ----
# clean_names() converts to consistent snake_case
sales_raw <- janitor::clean_names(sales_raw)

# Validate name cleaning ----
# names(sales_raw)

# Convert types and engineer features ----
# is_return: invoices starting with "C" are credit notes (returns)
# revenue: price x quantity at the line level
sales_raw <- sales_raw |>
  mutate(
    invoice_date = as.Date(invoice_date),
    month        = floor_date(invoice_date, "month"),
    year         = year(invoice_date),
    is_return    = str_starts(invoice, "C"),
    revenue      = price * quantity
  )

# Validate date conversion ----
# class(sales_raw$invoice_date)   # should be "Date"
# min(sales_raw$invoice_date)     # 2009-12-01
# max(sales_raw$invoice_date)     # 2011-12-09

# Check missing values ---- 110,855
# sum(is.na(sales_raw))

# Filter to valid sales only ----
# Remove: returns, missing customer IDs, zero/negative price, zero/negative quantity
sales_clean <- sales_raw |>
  filter(
    !is_return,
    !is.na(customer_id),
    price    >= min_price,
    quantity >= min_quantity
  )

# Validate filtering ----
# nrow(sales_raw)     # 525,461 — raw row count
# nrow(sales_clean)   # row count after removing invalid records 407,650

# ── Analysis 1: Revenue and orders by month ─────────────────
revenue_by_month <- sales_clean |>
  group_by(month) |>
  summarise(
    total_revenue = sum(revenue),
    total_orders  = n_distinct(invoice),
    .groups       = "drop"
  ) |>
  arrange(month)

# ── Analysis 2: Top 10 products by revenue ──────────────────
top_products <- sales_clean |>
  filter(!is.na(description)) |>
  group_by(stock_code, description) |>
  summarise(
    total_revenue = sum(revenue),
    units_sold    = sum(quantity),
    .groups       = "drop"
  ) |>
  arrange(desc(total_revenue)) |>
  slice_head(n = 10)

# ── Analysis 3: Top 10 countries by revenue ─────────────────
revenue_by_country <- sales_clean |>
  group_by(country) |>
  summarise(
    total_revenue    = sum(revenue),
    unique_customers = n_distinct(customer_id),
    .groups          = "drop"
  ) |>
  arrange(desc(total_revenue)) |>
  slice_head(n = 10)

# ── Analysis 4: Monthly unique customers ────────────────────
customers_by_month <- sales_clean |>
  group_by(month) |>
  summarise(
    unique_customers = n_distinct(customer_id),
    .groups          = "drop"
  ) |>
  arrange(month)

# ── Analysis 5: Average order value by month ────────────────
avg_order_value <- sales_clean |>
  group_by(month, invoice) |>
  summarise(
    order_value = sum(revenue),
    .groups     = "drop"
  ) |>
  group_by(month) |>
  summarise(
    avg_order_value = mean(order_value),
    .groups         = "drop"
  ) |>
  arrange(month)

# ── Plot 1: Monthly revenue trend ───────────────────────────
p1 <- revenue_by_month |>
  ggplot(aes(month, total_revenue)) +
  geom_line(colour = "#2c7bb6", linewidth = 1) +
  geom_point(colour = "#2c7bb6", size = 2) +
  expand_limits(y = 0) +
  scale_y_continuous(labels = label_comma(prefix = "£")) +
  labs(
    title = "Monthly Revenue Trend",
    x     = "Month",
    y     = "Revenue (£)"
  ) +
  theme_sales()

# ── Plot 2: Top 10 products by revenue ──────────────────────
p2 <- top_products |>
  mutate(description = str_trunc(description, 35)) |>
  ggplot(aes(total_revenue, fct_reorder(description, total_revenue))) +
  geom_col(fill = "#2c7bb6") +
  scale_x_continuous(labels = label_comma(prefix = "£")) +
  labs(
    title = "Top 10 Products by Revenue",
    x     = "Total Revenue (£)",
    y     = NULL
  ) +
  theme_sales()

# ── Plot 3: Top 10 countries by revenue ─────────────────────
p3 <- revenue_by_country |>
  ggplot(aes(total_revenue, fct_reorder(country, total_revenue))) +
  geom_col(fill = "#d7191c") +
  scale_x_continuous(labels = label_comma(prefix = "£")) +
  labs(
    title = "Top 10 Countries by Revenue",
    x     = "Total Revenue (£)",
    y     = NULL
  ) +
  theme_sales()

# ── Plot 4: Monthly unique customers ────────────────────────
p4 <- customers_by_month |>
  ggplot(aes(month, unique_customers)) +
  geom_line(colour = "#1a9641", linewidth = 1) +
  geom_point(colour = "#1a9641", size = 2) +
  expand_limits(y = 0) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Monthly Unique Customers",
    x     = "Month",
    y     = "Unique Customers"
  ) +
  theme_sales()

# ── Plot 5: Average order value by month ────────────────────
p5 <- avg_order_value |>
  ggplot(aes(month, avg_order_value)) +
  geom_line(colour = "#fdae61", linewidth = 1) +
  geom_point(colour = "#fdae61", size = 2) +
  expand_limits(y = 0) +
  scale_y_continuous(labels = label_comma(prefix = "£")) +
  labs(
    title = "Average Order Value by Month",
    x     = "Month",
    y     = "Avg Order Value (£)"
  ) +
  theme_sales()

# Export plots ----
ggsave(here::here("outputs/01_revenue_trend.png"),      plot = p1, width = 10, height = 5)
ggsave(here::here("outputs/02_top_products.png"),       plot = p2, width = 10, height = 6)
ggsave(here::here("outputs/03_revenue_by_country.png"), plot = p3, width = 10, height = 6)
ggsave(here::here("outputs/04_monthly_customers.png"),  plot = p4, width = 10, height = 5)
ggsave(here::here("outputs/05_avg_order_value.png"),    plot = p5, width = 10, height = 5)

# Export summary table ----
revenue_by_month |>
  write_csv(here::here("outputs/revenue_summary.csv"))

message("All outputs saved to outputs/")

#source(here::here("R/plot_theme.R"))