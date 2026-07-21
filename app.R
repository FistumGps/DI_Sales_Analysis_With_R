# ============================================================
# Shiny App: Sales Analysis Dashboard — E-commerce Business
# Input:   data/raw/online_retail_II.xlsx
#          525,461 transactions | 8 columns | 2009-2011
# Filters: Country, Date range — all 6 charts update live
# ============================================================

library(shiny)
library(tidyverse)
library(readxl)
library(janitor)
library(here)
library(scales)

source(here::here("R/plot_theme.R"))

# Define parameters ----
min_price    <- 0.01   # exclude free or incorrectly priced items
min_quantity <- 1      # exclude returns (negative quantity)

# Load and clean data once at app startup ----
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

country_choices <- sales_clean |> distinct(country) |> arrange(country) |> pull(country)
date_min <- min(sales_clean$invoice_date)
date_max <- max(sales_clean$invoice_date)

# ── UI ───────────────────────────────────────────────────────
ui <- fluidPage(
  titlePanel("Sales Analysis Dashboard — E-commerce Business"),
  sidebarLayout(
    sidebarPanel(
      selectInput(
        "countries", "Country",
        choices  = country_choices,
        selected = country_choices,
        multiple = TRUE
      ),
      dateRangeInput(
        "date_range", "Date range",
        start = date_min, end = date_max,
        min   = date_min, max = date_max
      )
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Revenue Trend",      plotOutput("p1")),
        tabPanel("Top Products",       plotOutput("p2")),
        tabPanel("Revenue by Country", plotOutput("p3")),
        tabPanel("Monthly Customers",  plotOutput("p4")),
        tabPanel("Avg Order Value",    plotOutput("p5")),
        tabPanel("Revenue by Year",    plotOutput("p6")),
        tabPanel("Summary Table",      tableOutput("summary_table"))
      )
    )
  )
)

# ── Server ───────────────────────────────────────────────────
server <- function(input, output, session) {

  filtered <- reactive({
    req(input$countries)
    sales_clean |>
      filter(
        country %in% input$countries,
        invoice_date >= input$date_range[1],
        invoice_date <= input$date_range[2]
      )
  })

  revenue_by_month <- reactive({
    filtered() |>
      group_by(month) |>
      summarise(total_revenue = sum(revenue), total_orders = n_distinct(invoice), .groups = "drop") |>
      arrange(month)
  })

  top_products <- reactive({
    filtered() |>
      filter(!is.na(description)) |>
      group_by(stock_code, description) |>
      summarise(total_revenue = sum(revenue), units_sold = sum(quantity), .groups = "drop") |>
      arrange(desc(total_revenue)) |>
      slice_head(n = 10)
  })

  revenue_by_country <- reactive({
    filtered() |>
      group_by(country) |>
      summarise(total_revenue = sum(revenue), unique_customers = n_distinct(customer_id), .groups = "drop") |>
      arrange(desc(total_revenue)) |>
      slice_head(n = 10)
  })

  customers_by_month <- reactive({
    filtered() |>
      group_by(month) |>
      summarise(unique_customers = n_distinct(customer_id), .groups = "drop") |>
      arrange(month)
  })

  avg_order_value <- reactive({
    filtered() |>
      group_by(month, invoice) |>
      summarise(order_value = sum(revenue), .groups = "drop") |>
      group_by(month) |>
      summarise(avg_order_value = mean(order_value), .groups = "drop") |>
      arrange(month)
  })

  revenue_by_year <- reactive({
    filtered() |>
      group_by(year) |>
      summarise(total_revenue = sum(revenue), .groups = "drop") |>
      arrange(year)
  })

  output$p1 <- renderPlot({
    revenue_by_month() |>
      ggplot(aes(month, total_revenue)) +
      geom_line(colour = "#2c7bb6", linewidth = 1) +
      geom_point(colour = "#2c7bb6", size = 2) +
      expand_limits(y = 0) +
      scale_y_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Monthly Revenue Trend", x = "Month", y = "Revenue (£)") +
      theme_sales()
  })

  output$p2 <- renderPlot({
    top_products() |>
      mutate(description = str_trunc(description, 35)) |>
      ggplot(aes(total_revenue, fct_reorder(description, total_revenue))) +
      geom_col(fill = "#2c7bb6") +
      scale_x_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Top 10 Products by Revenue", x = "Total Revenue (£)", y = NULL) +
      theme_sales()
  })

  output$p3 <- renderPlot({
    revenue_by_country() |>
      ggplot(aes(total_revenue, fct_reorder(country, total_revenue))) +
      geom_col(fill = "#d7191c") +
      scale_x_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Top 10 Countries by Revenue", x = "Total Revenue (£)", y = NULL) +
      theme_sales()
  })

  output$p4 <- renderPlot({
    customers_by_month() |>
      ggplot(aes(month, unique_customers)) +
      geom_line(colour = "#1a9641", linewidth = 1) +
      geom_point(colour = "#1a9641", size = 2) +
      expand_limits(y = 0) +
      scale_y_continuous(labels = label_comma()) +
      labs(title = "Monthly Unique Customers", x = "Month", y = "Unique Customers") +
      theme_sales()
  })

  output$p5 <- renderPlot({
    avg_order_value() |>
      ggplot(aes(month, avg_order_value)) +
      geom_line(colour = "#fdae61", linewidth = 1) +
      geom_point(colour = "#fdae61", size = 2) +
      expand_limits(y = 0) +
      scale_y_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Average Order Value by Month", x = "Month", y = "Avg Order Value (£)") +
      theme_sales()
  })

  output$p6 <- renderPlot({
    revenue_by_year() |>
      ggplot(aes(factor(year), total_revenue)) +
      geom_col(fill = "#2c7bb6") +
      scale_y_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Revenue by Year", x = "Year", y = "Revenue (£)") +
      theme_sales()
  })

  output$summary_table <- renderTable({
    revenue_by_month() |>
      mutate(total_revenue = label_comma(prefix = "£")(total_revenue))
  })
}

shinyApp(ui, server)
