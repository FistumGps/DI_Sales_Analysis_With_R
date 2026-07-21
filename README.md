# Sales Analysis for an E-commerce Business

## About the Project

This project analyses 525,461 transactional records from an online retail business
(2009–2011) to uncover revenue patterns, product performance, customer trends, and
geographic distribution of sales.

The raw data (`online_retail_II.xlsx`) contains 8 columns: invoice number, stock code,
product description, quantity, invoice date, unit price, customer ID, and country.

The analysis follows a structured end-to-end workflow:

1. Import raw Excel data
2. Clean and standardise column names
3. Engineer features (revenue, month, year, return flag)
4. Filter out returns, missing customer IDs, and invalid prices/quantities
5. Summarise across 5 analysis dimensions
6. Export plots and a summary CSV to `outputs/`

---

## Project Structure

```
Sales Analysis for an E-commerce Business/
├── data/
│   └── raw/
│       └── online_retail_II.xlsx        ← raw source file (read-only)
├── outputs/
│   ├── 01_revenue_trend.png             ← monthly revenue line chart
│   ├── 02_top_products.png              ← top 10 products by revenue
│   ├── 03_revenue_by_country.png        ← top 10 countries by revenue
│   ├── 04_monthly_customers.png         ← monthly unique customers
│   ├── 05_avg_order_value.png           ← average order value by month
│   └── revenue_summary.csv             ← monthly revenue summary table
├── R/
│   └── plot_theme.R                     ← reusable ggplot2 theme (theme_sales)
├── src/                                 ← reserved for future helper scripts
├── app.R                                ← main analysis script
└── README.md
```

> Raw data is read-only — never modify files inside `data/raw/`

---

## Key Design Decisions

| Decision | Reason |
|---|---|
| Returns excluded (`invoice` starts with `"C"`) | Credit notes inflate quantity/revenue if kept |
| `min_price = 0.01` | Zero-price rows are service/admin entries, not real sales |
| `min_quantity = 1` | Negative quantities are return lines |
| Parameters defined at the top of `app.R` | Easy to adjust without hunting through the code |
| `clean_names()` applied immediately after import | Ensures consistent snake_case throughout |
| `theme_sales()` in `R/plot_theme.R` | Shared styling so all 5 plots look consistent |

---

## Setup & How to Run

### Step 1 — Find your R installation

R is not added to PATH by default on Windows. Check where it is installed:

```powershell
Get-ChildItem "C:\Program Files\R"
```

This project was built with **R 4.5.3**:
```
C:\Program Files\R\R-4.5.3\bin\Rscript.exe
```

---

### Step 2 — Install required packages (one-time)

Open the PowerShell terminal in VS Code (`Ctrl+`` ` ``) and run:

```powershell
& "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" -e "install.packages(c('tidyverse', 'readxl', 'janitor', 'here', 'scales'), repos='https://cloud.r-project.org')"
```

If you get a missing dependency error (e.g. `RColorBrewer`, `scales`):

```powershell
& "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" -e "install.packages(c('RColorBrewer', 'scales'), repos='https://cloud.r-project.org')"
```

---

### Step 3 — Create required folders (one-time)

```powershell
New-Item -ItemType Directory -Force "outputs"
New-Item -ItemType Directory -Force "R"
```

---

### Step 4 — Run the script

```powershell
& "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" "c:\Users\Fistum.Haile\Downloads\Desta I\R\Sales Analysis for an E-commerce Business\app.R"
```

All 5 plots and the summary CSV will be saved to `outputs/`.

> **Important:** Always run the full script from the top — never run individual chunks
> in isolation, as earlier sections define parameters and helper functions that later
> sections depend on.

---

### Optional — Add R to PATH permanently

To avoid typing the full Rscript path every time, run this once:

```powershell
[System.Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\Program Files\R\R-4.5.3\bin", "User")
```

Close and reopen the terminal. After that you can run the script with:

```powershell
Rscript app.R
```

---

## Analyses Produced

| # | Analysis | Object | Output file |
|---|---|---|---|
| 1 | Revenue and order count by month | `revenue_by_month` | `01_revenue_trend.png` |
| 2 | Top 10 products by revenue | `top_products` | `02_top_products.png` |
| 3 | Top 10 countries by revenue | `revenue_by_country` | `03_revenue_by_country.png` |
| 4 | Monthly unique customer count | `customers_by_month` | `04_monthly_customers.png` |
| 5 | Average order value by month | `avg_order_value` | `05_avg_order_value.png` |
| 6 | Monthly revenue summary table | `revenue_by_month` | `revenue_summary.csv` |

---

## Packages Used

| Package | Purpose |
|---|---|
| `tidyverse` | Data manipulation and visualisation (dplyr, ggplot2, lubridate, stringr) |
| `readxl` | Reading Excel `.xlsx` files |
| `janitor` | Converting column names to snake_case with `clean_names()` |
| `here` | Portable file paths relative to the project root |
| `scales` | Formatted axis labels (comma separators, currency prefix) |

---

## Key Findings

> Based on Sheet 1 of the dataset: **2009-12-01 to 2010-12-09**

### Overall Performance

| Metric | Value |
|---|---|
| Total Revenue | £8,832,003 |
| Total Orders | 19,213 |
| Unique Customers | 4,312 |
| Average Order Value | £460 |
| Highest Single Order | £44,052 |

### Peak Month
**November 2010** was the highest-revenue month at **£1,172,336** — likely driven
by pre-Christmas bulk buying from wholesale customers.

### Top 5 Products by Revenue

| Product | Revenue |
|---|---|
| WHITE HANGING HEART T-LIGHT HOLDER | £151,624 |
| REGENCY CAKESTAND 3 TIER | £143,893 |
| Manual | £98,561 |
| ASSORTED COLOUR BIRD ORNAMENT | £70,494 |
| JUMBO BAG RED RETROSPOT | £51,759 |

### Top 5 Countries by Revenue

| Country | Revenue |
|---|---|
| United Kingdom | £7,414,756 |
| EIRE (Ireland) | £356,085 |
| Netherlands | £268,786 |
| Germany | £202,395 |
| France | £146,215 |

> The United Kingdom accounts for **~84% of total revenue**, confirming this is
> primarily a domestic UK business with a secondary international wholesale channel.

### Notable Observations

- The wide gap between average order value (£460) and the minimum (£0.84) suggests
  a mix of retail and wholesale customers purchasing at very different scales
- "Manual" appearing as the 3rd highest revenue product likely reflects a miscoded
  entry and may warrant data quality investigation
- International revenue is concentrated in Western Europe (Ireland, Netherlands,
  Germany, France), pointing to a natural expansion opportunity in those markets
