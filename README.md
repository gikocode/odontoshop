# OdontoShop - Sistema de GestiÃ³n Dental
docker-compose up --build -d api
\web\admin> npm run dev

Monolito modular en Go con:
- Admin Panel
- Sistema POS
- E-commerce
- Inventario unificado

odontoshop/
├── cmd/
│   └── api/
│       └── main.go                    # 🚀 ENTRYPOINT - Solo bootstrapping
│
├── internal/
│   ├── config/
│   │   ├── config.go                  # ⚙️ Configuración general
│   │   ├── database.go                # 🔌 CONEXIÓN A BD (no esquema)
│   │   ├── redis.go                   # 🔌 CONEXIÓN a Redis
│   │   └── rabbitmq.go                # 🔌 CONEXIÓN a RabbitMQ
│   │
│   ├── core/                          # ⭐ NÚCLEO DEL NEGOCIO
│   │   ├── domain/                    # 📦 DOMINIO (Entidades + Lógica)
│   │   │   ├── product/
│   │   │   │   ├── entity.go          # 🏛️ DEFINICIÓN de tabla Product
│   │   │   │   ├── repository.go      # 💾 ACCESO a datos (SQL)
│   │   │   │   └── service.go         # 🧠 LÓGICA DE NEGOCIO
│   │   │   │
│   │   │   ├── inventory/
│   │   │   │   ├── entity.go          # 🏛️ Tabla Inventory
│   │   │   │   ├── repository.go      # 💾 Queries SQL
│   │   │   │   ├── service.go         # 🧠 Lógica: reservar stock, etc.
│   │   │   │   └── inventory_sync.go  # 🔄 Sincronización POS/Ecommerce
│   │   │   │
│   │   │   ├── customer/
│   │   │   │   ├── entity.go
│   │   │   │   ├── repository.go
│   │   │   │   └── service.go
│   │   │   │
│   │   │   └── sale/
│   │   │       ├── entity.go          # 🏛️ Tabla Sales
│   │   │       ├── repository.go      # 💾 SQL queries
│   │   │       └── service.go         # 🧠 Lógica: crear venta, calcular total
│   │   │
│   │   ├── database/
│   │   │   ├── migrations/            # 📝 MIGRACIONES (esquema de BD)
│   │   │   │   ├── 001_create_tables.sql
│   │   │   │   ├── 002_add_indexes.sql
│   │   │   │   └── migration.go       # Runner de migraciones
│   │   │   │
│   │   │   ├── seeds/                 # 🌱 DATOS DE PRUEBA
│   │   │   │   ├── products.go
│   │   │   │   └── users.go
│   │   │   │
│   │   │   └── connection.go          # 🔌 Conexión GORM/sqlx
│   │   │
│   │   └── events/                    # 📡 EVENTOS (RabbitMQ)
│   │       ├── event_bus.go           # Bus de eventos
│   │       ├── handlers/
│   │       │   ├── inventory_reserved.go
│   │       │   └── sale_completed.go
│   │       └── publishers/
│   │           └── inventory.go
│   │
│   ├── modules/                       # 🎯 MÓDULOS DE APLICACIÓN
│   │   ├── admin/
│   │   │   ├── controllers/
│   │   │   │   └── dashboard.go       # 🎮 HTTP handlers (REST API)
│   │   │   ├── services/
│   │   │   │   └── dashboard.go       # 🔀 ORQUESTACIÓN (usa core/domain)
│   │   │   └── routes/
│   │   │       └── routes.go          # 🛣️ Rutas HTTP
│   │   │
│   │   ├── pos/
│   │   │   ├── controllers/
│   │   │   │   ├── sale.go            # 🎮 Endpoint: POST /pos/sales
│   │   │   │   ├── cash_register.go   # 🎮 Gestión de cajas
│   │   │   │   └── shift.go           # 🎮 Turnos
│   │   │   ├── services/
│   │   │   │   ├── pos_sale.go        # 🔀 Orquesta: inventory + sale + events
│   │   │   │   └── cash_register.go
│   │   │   └── routes/
│   │   │       └── routes.go
│   │   │
│   │   ├── ecommerce/
│   │   │   ├── controllers/
│   │   │   │   ├── product.go         # 🎮 Endpoint: GET /ecommerce/products
│   │   │   │   ├── cart.go            # 🎮 Carrito
│   │   │   │   └── order.go           # 🎮 Órdenes
│   │   │   ├── services/
│   │   │   │   ├── ecommerce_order.go # 🔀 Orquesta orden + inventory
│   │   │   │   └── cart.go
│   │   │   └── routes/
│   │   │       └── routes.go
│   │   │
│   │   └── auth/
│   │       ├── controllers/
│   │       │   └── auth.go
│   │       ├── services/
│   │       │   └── auth.go
│   │       ├── middleware/
│   │       │   └── jwt.go
│   │       └── routes/
│   │           └── routes.go
│   │
│   ├── infrastructure/                # 🏗️ INFRAESTRUCTURA TÉCNICA
│   │   ├── cache/
│   │   │   └── redis.go               # Implementación Redis
│   │   ├── messaging/
│   │   │   └── rabbitmq.go            # Implementación RabbitMQ
│   │   └── storage/
│   │       └── file_upload.go         # Subir archivos
│   │
│   └── shared/                        # 🔧 UTILIDADES COMPARTIDAS
│       ├── guards/
│       │   └── auth.go
│       ├── middleware/
│       │   ├── cors.go
│       │   └── logger.go
│       └── utils/
│           ├── response.go
│           └── pagination.go
│
├── pkg/                               # 📦 CÓDIGO PÚBLICO (reusable)
│   └── common/
│       ├── types/
│       │   ├── product.go             # DTOs compartidos
│       │   └── sale.go
│       ├── constants/
│       │   └── status.go
│       └── validators/
│           └── product.go
│
├── scripts/
│   └── init-db.sql                    # 🗄️ ESQUEMA INICIAL (tu bdd.sql)
│
├── docker-compose.yml
├── Dockerfile
└── go.mod