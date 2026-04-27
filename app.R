# Instalar paquetes si no los tienes: install.packages(c("shiny", "mongolite", "DT", "dplyr", "jsonlite", "lubridate"))
library(shiny)
library(mongolite)
library(DT)
library(dplyr)
library(jsonlite)
library(lubridate)

# --- CONEXIÓN A LA BASE DE DATOS ---
db <- mongo(collection = "provenance_logs", db = "genomic_lab")

# --- INTERFAZ DE USUARIO (UI) ---
ui <- fluidPage(
  
  titlePanel("Genomic Provenance Monitor"),
  
  sidebarLayout(
    sidebarPanel(
      h4("Interactive Filters"),
      selectInput("node_filter", "Execution Node:", 
                  choices = c("All", "cresselia", "darkrai", "mewtwo", "lugia")),
      selectInput("health_filter", "Health Status (Seqfu/SHA256):",
                  choices = c("All", "Only Fails", "All OK")),
      hr(),
      helpText("Instruction: Select a row in the table to view the full PROV-O schema in original JSON-LD format.")
    ),
    
    mainPanel(
      fluidRow(
        column(4, 
               wellPanel(
                 h4("System Health"), 
                 h3(textOutput("health_kpi"))
               )
        ),
        column(4, 
               wellPanel(
                 h4("Efficiency (Slowest Node)"), 
                 h3(textOutput("efficiency_kpi"))
               )
        ),
        column(4, 
               wellPanel(
                 h4("Throughput (GB)"), 
                 h3(textOutput("throughput_kpi"))
               )
        )
      ),
      br(),
      h3("Activity Log"),
      DTOutput("logs_table"),
      hr(),
      h3("Full Provenance Schema (JSON-LD)"),
      verbatimTextOutput("raw_json_view")
    )
  )
)

# --- LÓGICA DEL SERVIDOR ---
server <- function(input, output, session) {
  
  # 1. Cargar y procesar los datos reactivamente
  processed_data <- reactive({
    raw_data <- db$find('{}')
    req(nrow(raw_data) > 0)
    
    df <- data.frame(
      id = if ("@id" %in% names(raw_data)) as.character(raw_data$`@id`) else NA,
      label = if ("label" %in% names(raw_data)) as.character(raw_data$label) else "Unknown",
      nodo = if ("executionNode" %in% names(raw_data)) as.character(raw_data$executionNode) else "Unknown",
      inicio = if ("startTime" %in% names(raw_data)) ymd_hms(raw_data$startTime) else NA,
      fin = if ("endTime" %in% names(raw_data)) ymd_hms(raw_data$endTime) else NA,
      stringsAsFactors = FALSE
    )
    
    df$duracion_minutos <- round(as.numeric(difftime(df$fin, df$inicio, units = "mins")), 2)
    
    metrics <- lapply(raw_data$generated, function(gen_list) {
      bytes <- 0; seqfu_status <- "OK"; sha_status <- "OK"
      
      if (is.data.frame(gen_list) && nrow(gen_list) > 0) {
        for (i in 1:nrow(gen_list)) {
          lbl <- gen_list$label[i]
          val <- gen_list$value[i]
          size <- gen_list$totalSizeBytes[i]
          
          if (!is.null(lbl) && !is.na(lbl)) {
            if (lbl == "FASTQ Files" && !is.null(size) && !is.na(size)) {
              bytes <- as.numeric(size)
            }

            if (lbl == "Verificació Seqfu" && !is.null(val) && grepl("FAIL", val, ignore.case = TRUE)) {
              seqfu_status <- "FAIL"
            }
            if (lbl == "Verificació SHA256" && !is.null(val) && (grepl("FAIL", val, ignore.case=TRUE) || grepl("ERROR", val, ignore.case=TRUE))) {
              sha_status <- "FAIL"
            }
          }
        }
      }
      data.frame(bytes = bytes, seqfu = seqfu_status, sha256 = sha_status, stringsAsFactors = FALSE)
    })
    
    df <- cbind(df, do.call(rbind, metrics))
    df$gb_movidos <- round(df$bytes / (1024^3), 3)
    
    # --- APLICAR FILTROS ---
    if (!is.null(input$date_filter)) {
      df <- df %>% filter(as.Date(inicio) >= input$date_filter[1] & as.Date(inicio) <= input$date_filter[2])
    }
    
    if (input$node_filter != "All") {
      df <- df %>% filter(nodo == input$node_filter)
    }
    
    if (input$health_filter == "Only Fails") {
      df <- df %>% filter(seqfu == "FAIL" | sha256 == "FAIL")
    } else if (input$health_filter == "All OK") {
      df <- df %>% filter(seqfu == "OK" & sha256 == "OK")
    }
    
    return(df)
  })
  
  # 2. Renderizar KPIs
  output$health_kpi <- renderText({
    df <- processed_data()
    if(nrow(df) == 0) return("0 Failed Checks")
    fallos <- sum(df$seqfu == "FAIL" | df$sha256 == "FAIL", na.rm = TRUE)
    paste(fallos, "Failed Checks")
  })
  
  output$efficiency_kpi <- renderText({
    df <- processed_data()
    if(nrow(df) == 0) return("N/A")
    
    nodos_lentos <- df %>% 
      filter(!is.na(nodo) & !is.na(duracion_minutos)) %>%
      group_by(nodo) %>% 
      summarise(media_minutos = mean(duracion_minutos, na.rm = TRUE)) %>% 
      arrange(desc(media_minutos))
    
    if(nrow(nodos_lentos) == 0) return("N/A")
    paste(nodos_lentos$nodo[1], "(", round(nodos_lentos$media_minutos[1], 1), "m)")
  })
  
  output$throughput_kpi <- renderText({
    df <- processed_data()
    if(nrow(df) == 0) return("0 GB")
    total_gb <- sum(df$gb_movidos, na.rm = TRUE)
    paste(round(total_gb, 2), "GB")
  })
  
  
  # 3. Renderizar Tabla
  output$logs_table <- renderDT({
    df_display <- processed_data()
    req(nrow(df_display) > 0) 
    
    # Traducimos los nombres de las columnas para la tabla visual
    df_display <- df_display %>% 
      select(label, nodo, inicio, duracion_minutos, seqfu, sha256, gb_movidos) %>%
      rename(Process = label, Node = nodo, Start = inicio, `Duration (min)` = duracion_minutos, 
             Seqfu = seqfu, SHA256 = sha256, `Size (GB)` = gb_movidos)
    
    datatable(df_display, 
              selection = 'single', 
              options = list(pageLength = 5, scrollX = TRUE),
              rownames = FALSE) 
  })
  
  # 4. Vista interactiva del JSON original
  output$raw_json_view <- renderPrint({
    req(input$logs_table_rows_selected)
    
    # Obtenemos la fila seleccionada
    fila_filtrada <- input$logs_table_rows_selected
    
    # Extraemos el ID real del documento seleccionado
    doc_id <- processed_data()$id[fila_filtrada]
    req(doc_id) # Nos aseguramos de que haya un ID
    
    # Hacemos una consulta a MongoDB solo para ese documento específico
    query <- sprintf('{"@id": "%s"}', doc_id)
    documento_original <- db$find(query)
    
    # Eliminamos el id interno de MongoDB (_id) si lo añade, para dejar el PROV-O puro
    documento_original$`_id` <- NULL
    
    # Imprimimos el JSON bonito
    cat(toJSON(documento_original, pretty = TRUE, auto_unbox = TRUE))
  })
}

# Ejecutar la app
shinyApp(ui = ui, server = server)