# Reusable ggplot2 theme for all project charts
theme_sales <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title       = element_text(face = "bold", margin = margin(b = 8)),
      axis.title       = element_text(size = 10),
      panel.grid.minor = element_blank()
    )
}
