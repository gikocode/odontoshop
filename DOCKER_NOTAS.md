🚀 Comandos de Construcción y Ejecución
# Cuando cambies código Go, go.mod o el Dockerfile:
docker-compose up -d --build

# Si Docker se pone "terco" y no ve tus cambios en el go.mod:
docker-compose build --no-cache admin-api && docker-compose up -d admin-api

# Levantar TODO el ecosistema (DB, RabbitMQ, Redis y APIs)
docker-compose up -d

📊 Monitoreo y Logs
# Ver qué está pasando en tiempo real (todos los servicios)
docker-compose logs -f

# Ver solo los errores o mensajes de tu Backend Go
docker-compose logs -f admin-api

# Ver si RabbitMQ está recibiendo mensajes (Interfaz Web)
# URL: http://localhost:15672  (User/Pass: guest/guest)

🐘 Gestión de Base de Datos (PostgreSQL)
# Entrar a la terminal de la base de datos
docker exec -it odontoshop_db psql -U myuser -d odontodb

# Comandos esenciales dentro de psql:
# \dt                 -> Listar tablas existentes
# \d users            -> Ver columnas de la tabla usuarios
# SELECT * FROM users; -> Ver todos los usuarios registrados
# \q                  -> Salir de Postgres

🧹 Limpieza y Mantenimiento
# Detener sin borrar datos
docker-compose stop

# Borrar contenedores pero MANTENER los datos de la DB
docker-compose down

# RESET TOTAL (Borra todo: tablas, datos y volúmenes)
# Úsalo solo si quieres empezar la base de datos desde cero.
docker-compose down -v

🐹 Comandos de Go (Dentro de la carpeta /admin-api)
# Limpiar dependencias y sincronizar con tu versión de PC
go mod tidy

# Forzar una versión específica en el archivo mod
go mod edit -go=1.26