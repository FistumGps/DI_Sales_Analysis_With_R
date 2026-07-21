# ============================================================
# Shiny App: Sales Analysis Dashboard — E-commerce Business
# Input:   data/raw/online_retail_II.xlsx
#          525,461 transactions | 8 columns | 2009-2011
# Filters: Country (searchable, select all/none), Date range
# Charts:  interactive (hover, zoom) via plotly
# ============================================================

library(shiny)
library(tidyverse)
library(here)
library(scales)
library(shinyWidgets)
library(plotly)

source(here::here("R/plot_theme.R"))

# Load pre-cleaned data ----
# Cached by src/preprocess_data.R from data/raw/online_retail_II.xlsx.
# Re-parsing the 45MB raw Excel file on every app startup is slow and
# memory-heavy on constrained hosts (e.g. Posit Cloud free tier); the
# cached .rds loads near-instantly instead. Re-run the preprocessing
# script if the raw data changes.
sales_clean <- readRDS(here::here("data/processed/sales_clean.rds"))

country_choices <- sales_clean |> distinct(country) |> arrange(country) |> pull(country)
date_min <- min(sales_clean$invoice_date)
date_max <- max(sales_clean$invoice_date)

# ── UI ───────────────────────────────────────────────────────
ui <- fluidPage(
  titlePanel("Sales Analysis Dashboard — E-commerce Business"),
  sidebarLayout(
    sidebarPanel(
      pickerInput(
        "countries", "Country",
        choices  = country_choices,
        selected = country_choices,
        multiple = TRUE,
        options  = pickerOptions(
          actionsBox     = TRUE,
          liveSearch     = TRUE,
          selectedTextFormat = "count > 3",
          countSelectedText  = "{0} of {1} countries"
        )
      ),
      dateRangeInput(
        "date_range", "Date range",
        start = date_min, end = date_max,
        min   = date_min, max = date_max
      )
    ),
    mainPanel(
      fluidRow(
        column(3, wellPanel(h5("Total Revenue"),    h3(textOutput("kpi_revenue")))),
        column(3, wellPanel(h5("Total Orders"),     h3(textOutput("kpi_orders")))),
        column(3, wellPanel(h5("Unique Customers"), h3(textOutput("kpi_customers")))),
        column(3, wellPanel(h5("Avg Order Value"),  h3(textOutput("kpi_aov"))))
      ),
      tabsetPanel(
        tabPanel("Revenue Trend",      plotlyOutput("p1")),
        tabPanel("Top Products",       plotlyOutput("p2")),
        tabPanel("Revenue by Country", plotlyOutput("p3")),
        tabPanel("Monthly Customers",  plotlyOutput("p4")),
        tabPanel("Avg Order Value",    plotlyOutput("p5")),
        tabPanel("Revenue by Year",    plotlyOutput("p6")),
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

  # ── KPI summary row ──────────────────────────────────────
  output$kpi_revenue <- renderText({
    label_comma(prefix = "£")(sum(filtered()$revenue))
  })

  output$kpi_orders <- renderText({
    label_comma()(n_distinct(filtered()$invoice))
  })

  output$kpi_customers <- renderText({
    label_comma()(n_distinct(filtered()$customer_id))
  })

  output$kpi_aov <- renderText({
    d <- filtered()
    orders <- n_distinct(d$invoice)
    aov <- if (orders == 0) 0 else sum(d$revenue) / orders
    label_comma(prefix = "£")(aov)
  })

  # ── Interactive charts ───────────────────────────────────
  output$p1 <- renderPlotly({
    p <- revenue_by_month() |>
      ggplot(aes(month, total_revenue, text = paste0("Month: ", format(month, "%b %Y"), "<br>Revenue: £", label_comma()(total_revenue)))) +
      geom_line(colour = "#2c7bb6", linewidth = 1) +
      geom_point(colour = "#2c7bb6", size = 2) +
      expand_limits(y = 0) +
      scale_y_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Monthly Revenue Trend", x = "Month", y = "Revenue (£)") +
      theme_sales()
    ggplotly(p, tooltip = "text")
  })

  output$p2 <- renderPlotly({
    p <- top_products() |>
      mutate(description = str_trunc(description, 35)) |>
      ggplot(aes(total_revenue, fct_reorder(description, total_revenue), text = paste0(description, "<br>Revenue: £", label_comma()(total_revenue)))) +
      geom_col(fill = "#2c7bb6") +
      scale_x_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Top 10 Products by Revenue", x = "Total Revenue (£)", y = NULL) +
      theme_sales()
    ggplotly(p, tooltip = "text")
  })

  output$p3 <- renderPlotly({
    p <- revenue_by_country() |>
      ggplot(aes(total_revenue, fct_reorder(country, total_revenue), text = paste0(country, "<br>Revenue: £", label_comma()(total_revenue)))) +
      geom_col(fill = "#d7191c") +
      scale_x_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Top 10 Countries by Revenue", x = "Total Revenue (£)", y = NULL) +
      theme_sales()
    ggplotly(p, tooltip = "text")
  })

  output$p4 <- renderPlotly({
    p <- customers_by_month() |>
      ggplot(aes(month, unique_customers, text = paste0("Month: ", format(month, "%b %Y"), "<br>Customers: ", unique_customers))) +
      geom_line(colour = "#1a9641", linewidth = 1) +
      geom_point(colour = "#1a9641", size = 2) +
      expand_limits(y = 0) +
      scale_y_continuous(labels = label_comma()) +
      labs(title = "Monthly Unique Customers", x = "Month", y = "Unique Customers") +
      theme_sales()
    ggplotly(p, tooltip = "text")
  })

  output$p5 <- renderPlotly({
    p <- avg_order_value() |>
      ggplot(aes(month, avg_order_value, text = paste0("Month: ", format(month, "%b %Y"), "<br>Avg Order: £", label_comma()(avg_order_value)))) +
      geom_line(colour = "#fdae61", linewidth = 1) +
      geom_point(colour = "#fdae61", size = 2) +
      expand_limits(y = 0) +
      scale_y_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Average Order Value by Month", x = "Month", y = "Avg Order Value (£)") +
      theme_sales()
    ggplotly(p, tooltip = "text")
  })

  output$p6 <- renderPlotly({
    p <- revenue_by_year() |>
      ggplot(aes(factor(year), total_revenue, text = paste0("Year: ", year, "<br>Revenue: £", label_comma()(total_revenue)))) +
      geom_col(fill = "#2c7bb6") +
      scale_y_continuous(labels = label_comma(prefix = "£")) +
      labs(title = "Revenue by Year", x = "Year", y = "Revenue (£)") +
      theme_sales()
    ggplotly(p, tooltip = "text")
  })

  output$summary_table <- renderTable({
    revenue_by_month() |>
      mutate(total_revenue = label_comma(prefix = "£")(total_revenue))
  })
}

shinyApp(ui, server)
