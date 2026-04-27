library(jsonlite)
library(mongolite)

# 1. Configurar la conexión a MongoDB local
db <- mongo(collection = "provenance_logs", db = "genomic_lab")

# 2. Limpiar la colección antes de importar por si lo ejecutas varias veces
if(db$count() > 0) {
  db$drop()
  message("Colección anterior borrada para evitar duplicados.")
}

# 3. Localizar los archivos JSON generados
folder_path <- "project_files"
archivos_json <- list.files(path = folder_path, pattern = "*.json", full.names = TRUE)

# 4. Leer e importar cada archivo a MongoDB
for (archivo in archivos_json) {
  doc <- fromJSON(archivo, simplifyVector = FALSE)
  db$insert(doc)
}

print(paste("Success! Imported", db$count(), "records into MongoDB."))