-- ============================================
-- SISTEMA 1: ADMINISTRACIÓN - BASE DE DATOS
-- ============================================
-- PostgreSQL 15+
-- Gestión de inventario, usuarios, productos, proveedores
-- con soporte para variantes y RBAC

-- ============================================
-- EXTENSIONES
-- ============================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- TIPOS ENUMERADOS
-- ============================================

CREATE TYPE user_type AS ENUM ('employee', 'customer');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'pending_verification');
CREATE TYPE employment_status AS ENUM ('active', 'on_leave', 'terminated', 'resigned');
CREATE TYPE customer_type AS ENUM ('retail', 'wholesale', 'corporate');
CREATE TYPE credit_status AS ENUM ('none', 'approved', 'suspended', 'revoked');
CREATE TYPE product_status AS ENUM ('active', 'inactive', 'discontinued', 'out_of_stock');
CREATE TYPE adjustment_type AS ENUM (
    'purchase', 'sale', 'return', 'damage', 'loss', 
    'manual_adjustment', 'initial_stock', 'recount'
);
CREATE TYPE supplier_status AS ENUM ('active', 'inactive', 'blacklisted');
CREATE TYPE purchase_order_status AS ENUM (
    'draft', 'sent', 'confirmed', 'partially_received', 
    'received', 'cancelled'
);
CREATE TYPE proforma_status AS ENUM (
    'draft', 'sent', 'viewed', 'approved', 
    'rejected', 'expired', 'converted'
);
CREATE TYPE outbox_status AS ENUM ('pending', 'published', 'failed');

-- Missing ENUM types referenced in the schema
CREATE TYPE shift_status AS ENUM ('open', 'closed', 'cancelled');
CREATE TYPE invoice_status AS ENUM ('draft', 'sent', 'paid', 'cancelled');
CREATE TYPE return_reason AS ENUM ('defective', 'wrong_item', 'customer_dissatisfied');
CREATE TYPE cart_status AS ENUM ('active', 'converted', 'abandoned');
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled');

-- ============================================
-- AUTENTICACIÓN Y AUTORIZACIÓN (RBAC)
-- ============================================

-- Tabla base de usuarios
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL, -- UNIQUE eliminado para usar el índice condicional
    password_hash VARCHAR(255) NOT NULL,
    user_type user_type NOT NULL,
    status user_status DEFAULT 'active',
    email_verified BOOLEAN DEFAULT FALSE,
    phone VARCHAR(20),
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Sugerencia C: Índice condicional para Soft Delete
CREATE UNIQUE INDEX idx_users_email_active ON users(email) WHERE deleted_at IS NULL;

-- Roles del sistema
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- Tabla para manejar sesiones activas y Refresh Tokens
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_id UUID NOT NULL, -- ID único del JWT (jti)
    refresh_token TEXT,      -- Opcional: para renovar sesiones sin pedir login
    user_agent TEXT,         -- Navegador/Dispositivo del usuario
    ip_address VARCHAR(45),
    is_revoked BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(token_id);
-- Permisos granulares
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(resource, action)
);

-- Relación roles-permisos
CREATE TABLE role_permissions (
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID REFERENCES permissions(id) ON DELETE CASCADE,
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (role_id, permission_id)
);

-- Relación usuarios-roles
CREATE TABLE user_roles (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    assigned_by UUID REFERENCES users(id),
    expires_at TIMESTAMPTZ,
    PRIMARY KEY (user_id, role_id)
);

CREATE INDEX idx_user_roles_user ON user_roles(user_id);

-- ============================================
-- EMPLEADOS
-- ============================================

CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    employee_number VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    position VARCHAR(100),
    department VARCHAR(100),
    hire_date DATE NOT NULL,
    employment_status employment_status DEFAULT 'active',
    salary DECIMAL(10,2),
    supervisor_id UUID REFERENCES employees(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_employees_user ON employees(user_id);
CREATE INDEX idx_employees_number ON employees(employee_number);

-- ============================================
-- CLIENTES
-- ============================================

CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    customer_number VARCHAR(20) UNIQUE NOT NULL,
    customer_type customer_type DEFAULT 'retail',
    last_purchase_at TIMESTAMPTZ,
    -- Datos personales/empresa
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    company_name VARCHAR(255),
    tax_id VARCHAR(50),
    
    -- Contacto
    billing_address TEXT,
    shipping_address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(2) DEFAULT 'BE',
    postal_code VARCHAR(20),
    
    -- Crédito
    credit_status credit_status DEFAULT 'none',
    credit_limit DECIMAL(10,2) DEFAULT 0,
    current_balance DECIMAL(10,2) DEFAULT 0,
    payment_terms_days INT DEFAULT 0,
    
    -- Programa de lealtad
    loyalty_points INT DEFAULT 0,
    loyalty_tier VARCHAR(20),
    
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT check_credit_balance CHECK (current_balance >= 0),
    CONSTRAINT check_credit_limit CHECK (credit_limit >= 0)
);
CREATE INDEX idx_customers_last_purchase ON customers(last_purchase_at DESC);
CREATE INDEX idx_customers_user ON customers(user_id);
CREATE INDEX idx_customers_number ON customers(customer_number);
CREATE INDEX idx_customers_type ON customers(customer_type);
CREATE INDEX idx_customers_credit_status ON customers(credit_status);

-- Historial de cambios de crédito
CREATE TABLE customer_credit_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
    old_limit DECIMAL(10,2),
    new_limit DECIMAL(10,2),
    old_status credit_status,
    new_status credit_status,
    reason TEXT,
    changed_by UUID REFERENCES users(id),
    changed_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_credit_history_customer ON customer_credit_history(customer_id);
CREATE INDEX idx_credit_history_date ON customer_credit_history(changed_at DESC);

-- ============================================
-- CATEGORÍAS DE PRODUCTOS
-- ============================================

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES categories(id),
    image_url VARCHAR(500),
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_slug ON categories(slug);

-- ============================================
-- PRODUCTOS
-- ============================================

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    base_sku VARCHAR(50) UNIQUE,
    base_price DECIMAL(10,2) NOT NULL,
    has_variants BOOLEAN DEFAULT FALSE,
    tags TEXT[] DEFAULT '{}',
    view_count INT DEFAULT 0,
    weight DECIMAL(10,2),
    length DECIMAL(10,2),
    width DECIMAL(10,2),
    height DECIMAL(10,2),
    is_featured BOOLEAN DEFAULT FALSE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    status product_status DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT check_sku_required_if_no_variants CHECK (
        (has_variants = FALSE AND base_sku IS NOT NULL) OR (has_variants = TRUE)
    )
);

CREATE UNIQUE INDEX idx_products_slug ON products(slug);
CREATE INDEX idx_products_featured ON products(is_featured) WHERE is_featured = TRUE;
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_brand ON products(brand);
CREATE INDEX idx_product_images_variant ON product_images(variant_id);
CREATE INDEX idx_product_images_is_main ON product_images(product_id, is_main) 
    WHERE is_main = TRUE;
-- 4. Búsqueda por Estado (Filtra solo productos activos para el cliente)
-- Usamos un índice parcial para que sea más pequeño y rápido
CREATE INDEX idx_products_status_active ON products(status) 
WHERE status = 'active' AND deleted_at IS NULL;

-- 5. Búsqueda por SKU base (Para escáneres o gestión interna)
CREATE UNIQUE INDEX idx_products_base_sku ON products(base_sku) 
WHERE base_sku IS NOT NULL;

CREATE TABLE brands (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    logo_url VARCHAR(500),
    website VARCHAR(255),
    country VARCHAR(2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- Agregar FK en products
ALTER TABLE products ADD COLUMN brand_id UUID REFERENCES brands(id) ON DELETE SET NULL;
CREATE INDEX idx_products_brand ON products(brand_id);
 

-- Tabla dedicada a imágenes para no sobrecargar la tabla de productos
CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES product_variants(id) ON DELETE CASCADE,
    url VARCHAR(500) NOT NULL,
    alt_text VARCHAR(255),
    is_main BOOLEAN DEFAULT FALSE,
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT check_image_exclusive CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    )
);

CREATE INDEX idx_product_images_product ON product_images(product_id);

-- Primero eliminamos el índice único tradicional si ya existe
-- DROP INDEX IF EXISTS idx_users_email; 

-- Creamos el índice condicional: solo valida email si el usuario no está borrado
CREATE UNIQUE INDEX idx_users_email_active 
ON users(email) 
WHERE deleted_at IS NULL;

-- Lo mismo para los números de empleado, que suelen dar problemas
CREATE UNIQUE INDEX idx_employees_number_active 
ON employees(employee_number) 
WHERE deleted_at IS NULL;

-- ============================================
-- VARIANTES DE PRODUCTOS
-- ============================================

CREATE TABLE product_variants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    sku VARCHAR(50) UNIQUE NOT NULL,
    attributes JSONB NOT NULL,
    barcode VARCHAR(50),
    position INT DEFAULT 0,
    price DECIMAL(10,2) NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
 
CREATE INDEX idx_variants_product ON product_variants(product_id);
CREATE INDEX idx_variants_sku ON product_variants(sku);
CREATE INDEX idx_variants_barcode ON product_variants(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX idx_variants_attributes ON product_variants USING GIN(attributes);
CREATE INDEX idx_variants_active ON product_variants(is_active);
CREATE INDEX idx_variants_position ON product_variants(product_id, position);

CREATE UNIQUE INDEX idx_variants_default ON product_variants(product_id) 
    WHERE is_default = TRUE;

CREATE UNIQUE INDEX idx_variants_barcode_unique ON product_variants(barcode) 
    WHERE barcode IS NOT NULL;
-- ============================================
-- INVENTARIO
-- ============================================

CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Producto simple O variante
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES product_variants(id) ON DELETE CASCADE,
    
    -- Cantidades
    quantity INT NOT NULL DEFAULT 0,
    reserved_ecommerce INT DEFAULT 0,
    reserved_pos INT DEFAULT 0,
    committed INT DEFAULT 0,
    available INT GENERATED ALWAYS AS (
        quantity - reserved_ecommerce - reserved_pos - committed
    ) STORED,
    average_cost DECIMAL(10,2),
    -- Umbrales de alerta
    low_stock_threshold INT DEFAULT 10,
    reorder_point INT DEFAULT 20,
    reorder_quantity INT DEFAULT 50,
    
    -- Ubicación física
    warehouse_location VARCHAR(50),
    bin_location VARCHAR(50),
    aisle VARCHAR(10),
    shelf VARCHAR(10),
    
    -- Control de lotes
    lot_number VARCHAR(50),
    expiration_date DATE,
    
    -- Concurrencia optimista
    version INT DEFAULT 1,-- ← Control de versión
    
    -- Auditoría
    last_counted_at TIMESTAMPTZ,
    last_count_quantity INT,
    last_sync_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT check_inventory_quantities CHECK (
        quantity >= 0 AND 
        reserved_ecommerce >= 0 AND 
        reserved_pos >= 0 AND
        committed >= 0
    ),
    CONSTRAINT check_inventory_exclusive CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    )
);

CREATE UNIQUE INDEX idx_inventory_product_unique 
    ON inventory(product_id) 
    WHERE variant_id IS NULL AND product_id IS NOT NULL;

CREATE UNIQUE INDEX idx_inventory_variant_unique 
    ON inventory(variant_id) 
    WHERE variant_id IS NOT NULL;

CREATE INDEX idx_inventory_product ON inventory(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX idx_inventory_variant ON inventory(variant_id) WHERE variant_id IS NOT NULL;
CREATE INDEX idx_inventory_low_stock ON inventory(available) 
    WHERE available <= low_stock_threshold;
CREATE INDEX idx_inventory_location ON inventory(warehouse_location, bin_location);

-- Historial de ajustes de inventario
CREATE TABLE inventory_adjustments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inventory_id UUID REFERENCES inventory(id) ON DELETE CASCADE,
    
    adjustment_type adjustment_type NOT NULL,
    quantity_change INT NOT NULL,
    quantity_before INT NOT NULL,
    quantity_after INT NOT NULL,
    
    reason TEXT,
    reference_id UUID,
    reference_type VARCHAR(50),
    
    adjusted_by UUID REFERENCES users(id),
    adjusted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_adjustments_inventory ON inventory_adjustments(inventory_id);
CREATE INDEX idx_adjustments_type ON inventory_adjustments(adjustment_type);
CREATE INDEX idx_adjustments_date ON inventory_adjustments(adjusted_at);

-- ============================================
-- PROVEEDORES (INDEPENDIENTES)
-- ============================================

CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Datos de la empresa
    name VARCHAR(255) NOT NULL,
    company_name VARCHAR(255),
    tax_id VARCHAR(50),
    
    -- Contacto principal
    contact_person VARCHAR(100),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    website VARCHAR(255),
    
    -- Dirección
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(2) DEFAULT 'BE',
    postal_code VARCHAR(20),
    
    -- Términos comerciales
    payment_terms_days INT DEFAULT 30,
    credit_limit DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'EUR',
    
    -- Datos bancarios
    bank_name VARCHAR(100),
    bank_account VARCHAR(100),
    swift_code VARCHAR(20),
    iban VARCHAR(34),
    
    -- Rating y performance
    rating DECIMAL(2,1) CHECK (rating >= 0 AND rating <= 5),
    on_time_delivery_rate DECIMAL(5,2),
    quality_score DECIMAL(5,2),
    
    status supplier_status DEFAULT 'active',
    notes TEXT,
    internal_notes TEXT,
    
    -- Metadata
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_suppliers_status ON suppliers(status);
CREATE INDEX idx_suppliers_name ON suppliers(name);

-- Relación productos/variantes con proveedores
CREATE TABLE product_suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES product_variants(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES suppliers(id) ON DELETE CASCADE,
    
    -- Identificación del proveedor
    supplier_sku VARCHAR(50),
    supplier_product_name VARCHAR(255),
    
    -- Precios
    cost_price DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',
    minimum_order_quantity INT DEFAULT 1,
    
    -- Logística
    lead_time_days INT DEFAULT 7,
    
    -- Preferencia
    is_preferred BOOLEAN DEFAULT FALSE,
    priority INT DEFAULT 0,
    
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT check_product_supplier_exclusive CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    )
);

CREATE INDEX idx_product_suppliers_product ON product_suppliers(product_id);
CREATE INDEX idx_product_suppliers_variant ON product_suppliers(variant_id);
CREATE INDEX idx_product_suppliers_supplier ON product_suppliers(supplier_id);
CREATE INDEX idx_product_suppliers_preferred ON product_suppliers(is_preferred) 
    WHERE is_preferred = TRUE;

CREATE UNIQUE INDEX idx_product_suppliers_preferred_product 
    ON product_suppliers(product_id) 
    WHERE is_preferred = TRUE AND variant_id IS NULL;

CREATE UNIQUE INDEX idx_product_suppliers_preferred_variant 
    ON product_suppliers(variant_id) 
    WHERE is_preferred = TRUE AND variant_id IS NOT NULL;

-- ============================================
-- ÓRDENES DE COMPRA
-- ============================================

CREATE TABLE purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    po_number VARCHAR(50) UNIQUE NOT NULL,
    supplier_id UUID REFERENCES suppliers(id),
    
    status purchase_order_status DEFAULT 'draft',
    
    -- Fechas
    order_date DATE NOT NULL,
    expected_delivery_date DATE,
    received_date DATE,
    
    -- Montos
    subtotal DECIMAL(10,2) NOT NULL,
    tax DECIMAL(10,2) DEFAULT 0,
    shipping_cost DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    
    notes TEXT,
    created_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_purchase_orders_supplier ON purchase_orders(supplier_id);
CREATE INDEX idx_purchase_orders_status ON purchase_orders(status);
CREATE INDEX idx_purchase_orders_number ON purchase_orders(po_number);

-- Items de la orden de compra
CREATE TABLE purchase_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_order_id UUID REFERENCES purchase_orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    variant_id UUID REFERENCES product_variants(id),
    
    quantity_ordered INT NOT NULL,
    quantity_received INT DEFAULT 0,
    
    unit_cost DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT check_po_item_quantities CHECK (
        quantity_ordered > 0 AND 
        quantity_received >= 0 AND
        quantity_received <= quantity_ordered
    ),
    CONSTRAINT check_po_item_exclusive CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    )
);

CREATE INDEX idx_po_items_order ON purchase_order_items(purchase_order_id);
CREATE INDEX idx_po_items_product ON purchase_order_items(product_id);
CREATE INDEX idx_po_items_variant ON purchase_order_items(variant_id);

-- ============================================
-- PROFORMAS (COTIZACIONES)
-- ============================================

CREATE TABLE proformas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    proforma_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id UUID REFERENCES customers(id),
    
    status proforma_status DEFAULT 'draft',
    
    -- Fechas
    issue_date DATE NOT NULL,
    valid_until DATE NOT NULL,
    sent_at TIMESTAMPTZ,
    viewed_at TIMESTAMPTZ,
    
    -- Montos
    subtotal DECIMAL(10,2) NOT NULL,
    tax DECIMAL(10,2) DEFAULT 0,
    discount DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    
    -- Términos
    payment_terms TEXT,
    delivery_terms TEXT,
    notes TEXT,
    
    -- Conversión a venta
    converted_to_sale_id UUID,
    converted_at TIMESTAMPTZ,
    
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_proformas_customer ON proformas(customer_id);
CREATE INDEX idx_proformas_status ON proformas(status);
CREATE INDEX idx_proformas_number ON proformas(proforma_number);
CREATE INDEX idx_proformas_valid_until ON proformas(valid_until);

-- Items de la proforma
CREATE TABLE proforma_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    proforma_id UUID REFERENCES proformas(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    variant_id UUID REFERENCES product_variants(id),
    
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    tax_rate DECIMAL(5,2) DEFAULT 21.00,
    subtotal DECIMAL(10,2) NOT NULL,
    
    custom_description TEXT,
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT check_proforma_item_exclusive CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    ),
    CONSTRAINT check_proforma_quantity CHECK (quantity > 0)
);

CREATE INDEX idx_proforma_items_proforma ON proforma_items(proforma_id);
CREATE INDEX idx_proforma_items_product ON proforma_items(product_id);
CREATE INDEX idx_proforma_items_variant ON proforma_items(variant_id);

-- ============================================
-- CONFIGURACIÓN DEL NEGOCIO
-- ============================================

CREATE TABLE business_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    category VARCHAR(50),
    is_sensitive BOOLEAN DEFAULT FALSE,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_settings_category ON business_settings(category);

-- ============================================
-- OUTBOX PATTERN (para eventos)
-- ============================================

CREATE TABLE outbox_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    aggregate_type VARCHAR(50) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    status outbox_status DEFAULT 'pending',
    retry_count INT DEFAULT 0,
    last_error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    published_at TIMESTAMPTZ
);

CREATE INDEX idx_outbox_status ON outbox_events(status, created_at);
CREATE INDEX idx_outbox_aggregate ON outbox_events(aggregate_type, aggregate_id);

-- ============================================
-- TRIGGERS Y FUNCIONES
-- ============================================

-- Función para actualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inventory_updated_at BEFORE UPDATE ON inventory
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ESCALABILIDAD: CONTROL DE CONCURRENCIA (OPTIMISTIC LOCKING)
-- ============================================

-- Función para control de versiones optimista en inventario
CREATE OR REPLACE FUNCTION inventory_version_control()
RETURNS TRIGGER AS $$
BEGIN
    -- Verificar que la versión coincida (optimistic locking)
    IF OLD.version != NEW.version THEN
        RAISE EXCEPTION 'Conflicto de concurrencia: el registro fue modificado por otro usuario. Versión esperada: %, versión actual: %',
            OLD.version, NEW.version
            USING HINT = 'Por favor, recargue los datos y intente nuevamente';
    END IF;
    
    -- Incrementar la versión para el próximo update
    NEW.version := OLD.version + 1;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para implementar optimistic locking en inventario
CREATE TRIGGER inventory_concurrency_control
    BEFORE UPDATE ON inventory
    FOR EACH ROW
    WHEN (OLD.version IS NOT NULL)
    EXECUTE FUNCTION inventory_version_control();

-- Función para reserva de inventario con bloqueo
CREATE OR REPLACE FUNCTION reserve_inventory(
    p_inventory_id UUID,
    p_quantity INT,
    p_channel VARCHAR(20), -- 'ecommerce' o 'pos'
    p_reference_id UUID,
    p_reference_type VARCHAR(50)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_quantity INT;
    v_reserved_column VARCHAR(20);
    v_success BOOLEAN := FALSE;
BEGIN
    -- Determinar qué columna reservar según el canal
    IF p_channel = 'ecommerce' THEN
        v_reserved_column := 'reserved_ecommerce';
    ELSIF p_channel = 'pos' THEN
        v_reserved_column := 'reserved_pos';
    ELSE
        RAISE EXCEPTION 'Canal de reserva inválido: %', p_channel;
    END IF;

    -- Intentar reservar con bloqueo
    UPDATE inventory
    SET
        reserved_ecommerce = CASE WHEN p_channel = 'ecommerce' THEN reserved_ecommerce + p_quantity ELSE reserved_ecommerce END,
        reserved_pos = CASE WHEN p_channel = 'pos' THEN reserved_pos + p_quantity ELSE reserved_pos END,
        version = version + 1,
        updated_at = NOW()
    WHERE id = p_inventory_id
      AND available >= p_quantity
      AND version = (
          SELECT version FROM inventory WHERE id = p_inventory_id
      );

    GET DIAGNOSTICS v_success = ROW_COUNT;

    IF v_success = 0 THEN
        RAISE EXCEPTION 'No se pudo reservar inventario. Stock insuficiente o conflicto de concurrencia para ID: %', p_inventory_id;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Función para liberar reserva de inventario
CREATE OR REPLACE FUNCTION release_inventory_reservation(
    p_inventory_id UUID,
    p_quantity INT,
    p_channel VARCHAR(20)
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_channel = 'ecommerce' THEN
        UPDATE inventory
        SET reserved_ecommerce = reserved_ecommerce - p_quantity,
            version = version + 1,
            updated_at = NOW()
        WHERE id = p_inventory_id AND reserved_ecommerce >= p_quantity;
    ELSIF p_channel = 'pos' THEN
        UPDATE inventory
        SET reserved_pos = reserved_pos - p_quantity,
            version = version + 1,
            updated_at = NOW()
        WHERE id = p_inventory_id AND reserved_pos >= p_quantity;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_suppliers_updated_at BEFORE UPDATE ON suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_product_variants_updated_at BEFORE UPDATE ON product_variants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_purchase_orders_updated_at BEFORE UPDATE ON purchase_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_proformas_updated_at BEFORE UPDATE ON proformas
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SEGURIDAD: AUDITORÍA Y LOGS
-- ============================================

-- Tabla de auditoría para cambios críticos
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    record_id UUID NOT NULL,
    user_id UUID REFERENCES users(id),
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_table ON audit_logs(table_name, created_at);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, created_at);

-- Función para auditoría automática
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (table_name, operation, record_id, user_id, new_values, old_values)
        VALUES (
            TG_TABLE_NAME,
            'INSERT',
            NEW.id,
            current_setting('app.user_id', TRUE)::UUID,
            to_jsonb(NEW),
            NULL
        );
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (table_name, operation, record_id, user_id, new_values, old_values)
        VALUES (
            TG_TABLE_NAME,
            'UPDATE',
            NEW.id,
            current_setting('app.user_id', TRUE)::UUID,
            to_jsonb(NEW),
            to_jsonb(OLD)
        );
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (table_name, operation, record_id, user_id, new_values, old_values)
        VALUES (
            TG_TABLE_NAME,
            'DELETE',
            OLD.id,
            current_setting('app.user_id', TRUE)::UUID,
            NULL,
            to_jsonb(OLD)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar triggers de auditoría a tablas sensibles
CREATE TRIGGER audit_users
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_employees
    AFTER INSERT OR UPDATE OR DELETE ON employees
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_customers
    AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_suppliers
    AFTER INSERT OR UPDATE OR DELETE ON suppliers
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_sales
    AFTER INSERT OR UPDATE OR DELETE ON sales
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Función para encriptar datos sensibles adicionales
CREATE OR REPLACE FUNCTION encrypt_sensitive_data(data TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_encrypt(data, current_setting('app.encryption_key', TRUE), 'compress-algo=1, cipher-algo=aes256');
END;
$$ LANGUAGE plpgsql;

-- Función para desencriptar datos sensibles
CREATE OR REPLACE FUNCTION decrypt_sensitive_data(encrypted_data TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(encrypted_data::bytea, current_setting('app.encryption_key', TRUE), 'compress-algo=1, cipher-algo=aes256');
END;
$$ LANGUAGE plpgsql;

-- Función para generar número de proforma
CREATE OR REPLACE FUNCTION generate_proforma_number()
RETURNS TRIGGER AS $$
DECLARE
    next_number INT;
    year_part VARCHAR(4);
BEGIN
    year_part := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(proforma_number FROM 10) AS INT)), 0) + 1
    INTO next_number
    FROM proformas
    WHERE proforma_number LIKE 'PRO-' || year_part || '-%';
    
    NEW.proforma_number := 'PRO-' || year_part || '-' || LPAD(next_number::TEXT, 5, '0');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_proforma_number BEFORE INSERT ON proformas
    FOR EACH ROW 
    WHEN (NEW.proforma_number IS NULL)
    EXECUTE FUNCTION generate_proforma_number();

-- Función para generar número de orden de compra
CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TRIGGER AS $$
DECLARE
    next_number INT;
    year_part VARCHAR(4);
BEGIN
    year_part := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(po_number FROM 9) AS INT)), 0) + 1
    INTO next_number
    FROM purchase_orders
    WHERE po_number LIKE 'PO-' || year_part || '-%';
    
    NEW.po_number := 'PO-' || year_part || '-' || LPAD(next_number::TEXT, 5, '0');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_po_number BEFORE INSERT ON purchase_orders
    FOR EACH ROW 
    WHEN (NEW.po_number IS NULL)
    EXECUTE FUNCTION generate_po_number();

-- ============================================
-- VISTA DE INVENTARIO
-- ============================================

CREATE OR REPLACE VIEW v_inventory_summary AS
SELECT 
    i.id,
    COALESCE(pv.product_id, p.id) as product_id,
    p.name as product_name,
    p.base_sku,
    pv.id as variant_id,
    pv.sku as variant_sku,
    pv.attributes as variant_attributes,
    i.quantity,
    i.reserved_ecommerce,
    i.reserved_pos,
    i.committed,
    i.available,
    i.low_stock_threshold,
    i.warehouse_location,
    i.bin_location,
    CASE 
        WHEN i.available <= 0 THEN 'out_of_stock'
        WHEN i.available <= i.low_stock_threshold THEN 'low_stock'
        ELSE 'in_stock'
    END as stock_status,
    i.last_counted_at,
    i.updated_at
FROM inventory i
LEFT JOIN products p ON i.product_id = p.id
LEFT JOIN product_variants pv ON i.variant_id = pv.id;

-- ============================================
-- RENDIMIENTO: VISTA MATERIALIZADA DE INVENTARIO
-- Para alto volumen, usar esta versión materializada
-- Se debe refrescar periódicamente o con trigger
-- ============================================

CREATE MATERIALIZED VIEW mv_inventory_summary AS
SELECT
    i.id,
    COALESCE(pv.product_id, p.id) as product_id,
    p.name as product_name,
    p.base_sku,
    pv.id as variant_id,
    pv.sku as variant_sku,
    pv.attributes as variant_attributes,
    i.quantity,
    i.reserved_ecommerce,
    i.reserved_pos,
    i.committed,
    i.available,
    i.low_stock_threshold,
    i.warehouse_location,
    i.bin_location,
    CASE
        WHEN i.available <= 0 THEN 'out_of_stock'
        WHEN i.available <= i.low_stock_threshold THEN 'low_stock'
        ELSE 'in_stock'
    END as stock_status,
    i.last_counted_at,
    i.updated_at,
    NOW() as materialized_at
FROM inventory i
LEFT JOIN products p ON i.product_id = p.id
LEFT JOIN product_variants pv ON i.variant_id = pv.id;

-- Índices para la vista materializada
CREATE UNIQUE INDEX idx_mv_inventory_id ON mv_inventory_summary(id);
CREATE INDEX idx_mv_inventory_product ON mv_inventory_summary(product_id);
CREATE INDEX idx_mv_inventory_status ON mv_inventory_summary(stock_status);
CREATE INDEX idx_mv_inventory_location ON mv_inventory_summary(warehouse_location, bin_location);

-- Función para refrescar la vista materializada
CREATE OR REPLACE FUNCTION refresh_inventory_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_summary;
END;
$$ LANGUAGE plpgsql;

-- Función para monitorear consultas lentas en JSONB/GIN
CREATE OR REPLACE FUNCTION log_slow_queries()
RETURNS TRIGGER AS $$
BEGIN
    -- Habilitar en producción para monitorear consultas lentas
    -- Esta función registra timestamps para análisis de rendimiento
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- VENTAS (núcleo del negocio)
CREATE TYPE sale_source AS ENUM ('ecommerce', 'pos', 'phone', 'wholesale', 'proforma_conversion');
CREATE TYPE sale_status AS ENUM ('pending', 'processing', 'completed', 'cancelled', 'refunded', 'partially_refunded');
CREATE TYPE payment_method_type AS ENUM ('cash', 'credit_card', 'debit_card', 'bank_transfer', 'credit', 'paypal', 'stripe');
CREATE TYPE payment_status AS ENUM ('pending', 'authorized', 'captured', 'failed', 'refunded');
-- ============================================
-- TABLA MAESTRA: VENTAS
-- ============================================
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_number VARCHAR(50) UNIQUE NOT NULL, -- VTA-2024-00001
    
    -- Origen
    source sale_source NOT NULL, -- 'ecommerce', 'pos'
    
    -- Cliente
    customer_id UUID REFERENCES customers(id),
    payment_methods_used JSONB DEFAULT '[]', -- [{"method": "credit_card", "amount": 100.00}]
    -- Referencias específicas
    shift_id UUID REFERENCES shifts(id), -- Solo POS
    cashier_id UUID REFERENCES employees(id), -- Solo POS
    order_id UUID REFERENCES orders(id), -- Solo E-commerce
    proforma_id UUID REFERENCES proformas(id),-- Si viene de proforma
    
    -- TOTALES (calculados desde sale_items)
    subtotal DECIMAL(10,2) NOT NULL,
    tax DECIMAL(10,2) DEFAULT 0,
    discount DECIMAL(10,2) DEFAULT 0,
    shipping_cost DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    --Estado
    status sale_status DEFAULT 'pending',
    -- Notas
    notes TEXT,
    internal_notes TEXT,
    
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
    -- Timestamps
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,

    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- ============================================
-- TABLA DETALLE: ITEMS DE VENTA
-- ============================================
CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE, -- ← Clave foránea
    
    -- Producto vendido
    product_id UUID REFERENCES products(id),
    variant_id UUID REFERENCES product_variants(id),
    
    -- Cantidades y precios
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    tax_rate DECIMAL(5,2) DEFAULT 21.00,
    tax_amount DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL, -- (unit_price * quantity) - discount
    
    -- SNAPSHOT del producto (importante para historial)
    product_name VARCHAR(255) NOT NULL,
    product_sku VARCHAR(50) NOT NULL,
    variant_attributes JSONB, -- {"size": "M", "color": "Rojo"}
    
    -- Notas específicas del item
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);
CREATE INDEX idx_sale_items_variant ON sale_items(variant_id);

-- Pagos
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
    
    payment_method payment_method_type NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status payment_status DEFAULT 'pending',
    
    -- Para pagos electrónicos
    transaction_id VARCHAR(100), -- ID de Stripe, PayPal, etc.
    gateway VARCHAR(50), -- 'stripe', 'paypal', 'square'
    
    -- Para crédito
    credit_transaction_id UUID,
    
    -- Metadata
    metadata JSONB,
    
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_payments_sale ON payments(sale_id);
CREATE INDEX idx_payments_created ON payments(created_at DESC);
-- Cajas registradoras
CREATE TABLE cash_registers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Turnos de caja (POS)
CREATE TABLE shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_number VARCHAR(50) UNIQUE NOT NULL,
    
    cashier_id UUID REFERENCES employees(id),
    cash_register_id UUID REFERENCES cash_registers(id),
    
    -- Montos
    opening_cash DECIMAL(10,2) NOT NULL,
    closing_cash DECIMAL(10,2),
    expected_cash DECIMAL(10,2),
    difference DECIMAL(10,2), -- closing - expected
    
    -- Estados
    status shift_status DEFAULT 'open',
    
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    
    notes TEXT
);
CREATE INDEX idx_shifts_cashier ON shifts(cashier_id);
CREATE INDEX idx_shifts_register ON shifts(cash_register_id);
CREATE INDEX idx_shifts_status ON shifts(status);
CREATE INDEX idx_shifts_opened ON shifts(opened_at DESC);

-- Métodos de pago
CREATE TABLE payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLA MAESTRA: FACTURAS
-- ============================================
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_number VARCHAR(50) UNIQUE NOT NULL, -- FAC-2024-00001

    -- Relación con venta
    sale_id UUID REFERENCES sales(id) ON DELETE RESTRICT, -- Relación con la venta original

    -- Datos del Emisor/Receptor (Snapshots para validez legal)
    customer_id UUID REFERENCES customers(id),
    customer_name VARCHAR(255) NOT NULL,
    customer_tax_id VARCHAR(50) NOT NULL, -- NIT/RUT/DNI
    customer_address TEXT,
    
    

    -- Totales Fiscales
    currency_code VARCHAR(3) DEFAULT 'USD',
    exchange_rate DECIMAL(10,4) DEFAULT 1.0000,
    net_amount DECIMAL(10,2) NOT NULL, -- Base imponible
    tax_amount DECIMAL(10,2) NOT NULL, -- IVA/IGV total
    total_amount DECIMAL(10,2) NOT NULL,
    
    -- Estado
    status invoice_status DEFAULT 'draft', -- 'draft', 'sent', 'paid', 'cancelled'
    payment_method_id UUID REFERENCES payment_methods(id),
    
    -- Legal
    legal_signature TEXT, -- Firma digital
    xml_file TEXT, -- Factura electrónica (XML)
    pdf_url VARCHAR(500),

    -- Fechas 
    due_date DATE NOT NULL,
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_invoices_sale ON invoices(sale_id);
CREATE INDEX idx_invoices_customer ON invoices(customer_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_issued ON invoices(issued_at DESC);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
-- ============================================
-- TABLA DETALLE: ITEMS DE FACTURA
-- ============================================
CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    
    -- Referencia al item de venta original (opcional pero útil)
    sale_item_id UUID REFERENCES sale_items(id),
     
    
    description TEXT NOT NULL, -- Nombre del producto + variante
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    tax_rate DECIMAL(5,2) NOT NULL,
    tax_amount DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    subtotal DECIMAL(10,2) NOT NULL,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);
-- ============================================
-- TABLA MAESTRA: DEVOLUCIONES
-- ============================================
CREATE TYPE return_status AS ENUM ('pending', 'received', 'refunded', 'rejected', 'cancelled');

CREATE TABLE returns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    return_number VARCHAR(50) UNIQUE NOT NULL, -- DEV-0001
    sale_id UUID REFERENCES sales(id) NOT NULL,
    
    reason return_reason NOT NULL, -- 'defective', 'wrong_item', 'customer_dissatisfied'
    status return_status DEFAULT 'pending', -- 'pending', 'received', 'refunded', 'rejected'
    
    total_refund_amount DECIMAL(10,2) NOT NULL,
    inventory_restock BOOLEAN DEFAULT TRUE, -- ¿Vuelven los productos al stock?
    
    received_by UUID REFERENCES employees(id),
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_returns_sale ON returns(sale_id);
CREATE INDEX idx_returns_status ON returns(status);
CREATE INDEX idx_returns_created ON returns(created_at DESC);
-- ============================================
-- TABLA DETALLE: ITEMS DE DEVOLUCIÓN
-- ============================================
CREATE TYPE item_condition AS ENUM ('good', 'damaged', 'opened', 'defective');

CREATE TABLE return_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    return_id UUID REFERENCES returns(id) ON DELETE CASCADE,
    sale_item_id UUID REFERENCES sale_items(id) NOT NULL,
    
    quantity INT NOT NULL CHECK (quantity > 0),
    refund_unit_price DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    
    condition item_condition DEFAULT 'good', -- 'good', 'damaged', 'opened'
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_return_items_return ON return_items(return_id);
-- ============================================
-- TABLA MAESTRA: CARRITOS
-- ============================================
CREATE TABLE carts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES customers(id), -- NULL si es invitado
    session_id VARCHAR(255), -- Para usuarios no logueados
    
    status cart_status DEFAULT 'active', -- 'active', 'converted', 'abandoned'
    
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_carts_customer ON carts(customer_id);
CREATE INDEX idx_carts_session ON carts(session_id);
CREATE INDEX idx_carts_status ON carts(status);
CREATE INDEX idx_carts_expires ON carts(expires_at);
-- ============================================
-- TABLA DETALLE: ITEMS DEL CARRITO
-- ============================================
CREATE TABLE cart_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cart_id UUID REFERENCES carts(id) ON DELETE CASCADE,
    
    product_id UUID REFERENCES products(id) NOT NULL,
    variant_id UUID REFERENCES product_variants(id),
    
    quantity INT NOT NULL CHECK (quantity > 0),
    
    added_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cart_items_cart ON cart_items(cart_id);
CREATE INDEX idx_cart_items_product ON cart_items(product_id);
CREATE INDEX idx_cart_items_variant ON cart_items(variant_id);

-- Direcciones de clientes
CREATE TABLE customer_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
    address_type VARCHAR(20) NOT NULL, -- 'billing', 'shipping'
    address_line_1 VARCHAR(255) NOT NULL,
    address_line_2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(2) DEFAULT 'BE',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_customer_addresses_customer ON customer_addresses(customer_id);
CREATE INDEX idx_customer_addresses_type ON customer_addresses(customer_id, address_type);
CREATE INDEX idx_customer_addresses_default ON customer_addresses(customer_id) 
    WHERE is_default = TRUE;
-- Métodos de envío
CREATE TABLE shipping_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    cost DECIMAL(10,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TABLA MAESTRA: ÓRDENES
-- ============================================
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number VARCHAR(50) UNIQUE NOT NULL, -- ORD-100234
    customer_id UUID REFERENCES customers(id) NOT NULL,
    cart_id UUID REFERENCES carts(id), -- Origen del pedido
    
    -- Estado de la Orden
    status order_status DEFAULT 'pending', -- 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled'
    payment_status payment_status DEFAULT 'unpaid',
    
    -- Datos de Envío
    shipping_address_id UUID REFERENCES customer_addresses(id),
    shipping_method_id UUID REFERENCES shipping_methods(id),
    tracking_number VARCHAR(100),
    
    -- Totales
    subtotal DECIMAL(10,2) NOT NULL,
    shipping_cost DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    
    placed_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_orders_placed ON orders(placed_at DESC);
-- ============================================
-- TABLA DETALLE: ITEMS DE LA ÓRDEN
-- ============================================
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    
    product_id UUID REFERENCES products(id) NOT NULL,
    variant_id UUID REFERENCES product_variants(id),
    
    quantity INT NOT NULL CHECK (quantity > 0),
    price_at_purchase DECIMAL(10,2) NOT NULL, -- Precio en el momento del pedido
    subtotal DECIMAL(10,2) NOT NULL,
    
    -- Snapshot básico
    product_name VARCHAR(255) NOT NULL,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_order_items_variant ON order_items(variant_id);


-- Función que notifica cuando el stock es bajo
CREATE OR REPLACE FUNCTION notify_low_stock()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo notificar cuando available cruza el umbral
    IF NEW.available <= NEW.low_stock_threshold 
       AND OLD.available > OLD.low_stock_threshold THEN
        
        -- Insertar en tabla de alertas
        INSERT INTO stock_alerts (
            inventory_id,
            product_id,
            variant_id,
            current_stock,
            threshold,
            alert_type,
            created_at
        ) VALUES (
            NEW.id,
            NEW.product_id,
            NEW.variant_id,
            NEW.available,
            NEW.low_stock_threshold,
            'low_stock',
            NOW()
        );
        
        -- Notificación PostgreSQL (LISTEN/NOTIFY)
        PERFORM pg_notify(
            'low_stock_channel',
            json_build_object(
                'inventory_id', NEW.id,
                'variant_id', NEW.variant_id,
                'available', NEW.available,
                'threshold', NEW.low_stock_threshold
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER low_stock_alert
    AFTER UPDATE OF available ON inventory
    FOR EACH ROW
    EXECUTE FUNCTION notify_low_stock();
    
CREATE TYPE alert_type AS ENUM ('low_stock', 'out_of_stock', 'reorder_point');
CREATE TYPE alert_status AS ENUM ('pending', 'acknowledged', 'resolved');

CREATE TABLE stock_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inventory_id UUID REFERENCES inventory(id),
    product_id UUID REFERENCES products(id),
    variant_id UUID REFERENCES product_variants(id),
    
    alert_type alert_type NOT NULL,
    current_stock INT NOT NULL,
    threshold INT NOT NULL,
    
    status alert_status DEFAULT 'pending',
    
    -- Quién la reconoció/resolvió
    acknowledged_by UUID REFERENCES users(id),
    acknowledged_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stock_alerts_status ON stock_alerts(status);
CREATE INDEX idx_stock_alerts_created ON stock_alerts(created_at DESC);
CREATE INDEX idx_stock_alerts_inventory ON stock_alerts(inventory_id);
CREATE INDEX idx_stock_alerts_product ON stock_alerts(product_id);
CREATE INDEX idx_stock_alerts_variant ON stock_alerts(variant_id);

-- Lista de precios mayorista
INSERT INTO price_lists (name, list_type, default_discount_percentage, minimum_order_amount)
VALUES ('Mayorista', 'wholesale', 15.00, 500.00);

-- Lista VIP
INSERT INTO price_lists (name, list_type, default_discount_percentage)
VALUES ('VIP Gold', 'vip', 20.00, 0);

-- Precio especial para un producto específico
INSERT INTO price_list_items (
    price_list_id, 
    variant_id, 
    special_price,
    minimum_quantity
) VALUES (
    (SELECT id FROM price_lists WHERE name = 'Mayorista'),
    (SELECT id FROM product_variants WHERE sku = 'CAM-BAS-M-WHI'),
    14.99,  -- Precio normal: 19.99, especial: 14.99
    10      -- Mínimo 10 unidades
);

-- Asignar lista a cliente
INSERT INTO customer_price_lists (customer_id, price_list_id)
VALUES (
    (SELECT id FROM customers WHERE customer_number = 'CLI-00002'),
    (SELECT id FROM price_lists WHERE name = 'Mayorista')
);
CREATE TABLE discount_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Condiciones
    customer_type customer_type[], -- ['wholesale', 'corporate']
    customer_tier VARCHAR(20)[],   -- ['gold', 'platinum']
    min_quantity INT,
    min_order_amount DECIMAL(10,2),
    
    -- Descuento
    discount_type VARCHAR(20) NOT NULL, -- 'percentage', 'fixed_amount'
    discount_value DECIMAL(10,2) NOT NULL,
    
    -- Alcance
    applies_to VARCHAR(20) NOT NULL, -- 'all', 'category', 'product'
    category_ids UUID[],
    product_ids UUID[],
    
    -- Validez
    is_active BOOLEAN DEFAULT TRUE,
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    
    -- Prioridad
    priority INT DEFAULT 0,
    stackable BOOLEAN DEFAULT FALSE, -- ¿Se puede combinar con otros?
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ERROR HANDLING: MEJORAS EN MANEJO DE ERRORES
-- ============================================

-- Función para manejo de errores en triggers
CREATE OR REPLACE FUNCTION handle_trigger_error()
RETURNS TRIGGER AS $$
BEGIN
    -- Loggear el error antes de propagarlo
    RAISE LOG 'Error en trigger % en tabla %: %', TG_NAME, TG_TABLE_NAME, SQLERRM;
    -- Re-lanzar la excepción para que el usuario la vea
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- NEGOCIO: LÓGICA DE CÁLCULOS Y VALIDACIONES
-- ============================================

-- Función para calcular total de venta
CREATE OR REPLACE FUNCTION calculate_sale_total(p_sale_id UUID)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    v_subtotal DECIMAL(10,2);
    v_tax DECIMAL(10,2);
    v_discount DECIMAL(10,2);
BEGIN
    SELECT
        COALESCE(SUM(subtotal), 0),
        COALESCE(SUM(tax_amount), 0),
        COALESCE(SUM(discount_amount), 0)
    INTO v_subtotal, v_tax, v_discount
    FROM sale_items
    WHERE sale_id = p_sale_id;

    RETURN v_subtotal + v_tax - v_discount;
END;
$$ LANGUAGE plpgsql;

-- Función para calcular total de orden
CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id UUID)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    v_subtotal DECIMAL(10,2);
    v_shipping DECIMAL(10,2);
BEGIN
    SELECT
        COALESCE(SUM(subtotal), 0),
        COALESCE(MAX(shipping_cost), 0)
    INTO v_subtotal, v_shipping
    FROM order_items
    WHERE order_id = p_order_id;

    RETURN v_subtotal + v_shipping;
END;
$$ LANGUAGE plpgsql;

-- Validación de precio de venta no negativo
CREATE OR REPLACE FUNCTION validate_sale_price()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.unit_price < 0 THEN
        RAISE EXCEPTION 'El precio unitario no puede ser negativo: %', NEW.unit_price;
    END IF;
    
    IF NEW.quantity <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a 0: %', NEW.quantity;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para validar precio de venta
CREATE TRIGGER validate_sale_price_trigger
    BEFORE INSERT OR UPDATE ON sale_items
    FOR EACH ROW EXECUTE FUNCTION validate_sale_price();

-- Función para validar crédito del cliente
CREATE OR REPLACE FUNCTION validate_customer_credit()
RETURNS TRIGGER AS $$
DECLARE
    v_credit_limit DECIMAL(10,2);
    v_current_balance DECIMAL(10,2);
BEGIN
    IF NEW.customer_id IS NOT NULL THEN
        SELECT credit_limit, current_balance
        INTO v_credit_limit, v_current_balance
        FROM customers
        WHERE id = NEW.customer_id;

        IF v_credit_limit > 0 AND (v_current_balance + NEW.total) > v_credit_limit THEN
            RAISE EXCEPTION 'El cliente excede su límite de crédito. Límite: %, Actual: %, Nuevo total: %',
                v_credit_limit, v_current_balance, NEW.total;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para validar crédito en ventas
CREATE TRIGGER validate_credit_trigger
    BEFORE INSERT ON sales
    FOR EACH ROW EXECUTE FUNCTION validate_customer_credit();

-- ============================================
-- VERSIONADO DEL ESQUEMA (MIGRACIONES)
-- ============================================

-- Tabla para control de versiones del esquema
CREATE TABLE schema_version (
    version VARCHAR(20) NOT NULL PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    description TEXT,
    script_name VARCHAR(255)
);

-- Insertar versión inicial
INSERT INTO schema_version (version, description, script_name)
VALUES ('1.0.0', 'Esquema inicial con todas las tablas base', 'bdd.sql');

-- Función para obtener la versión actual
CREATE OR REPLACE FUNCTION get_schema_version()
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN (SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1);
END;
$$ LANGUAGE plpgsql;

-- Función para registrar migraciones
CREATE OR REPLACE FUNCTION register_migration(
    p_version VARCHAR(20),
    p_description TEXT,
    p_script_name VARCHAR(255)
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO schema_version (version, description, script_name)
    VALUES (p_version, p_description, p_script_name);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- RENDIMIENTO: PARTICIONAMIENTO DE TABLAS GRANDES
-- ============================================

-- Tabla de ventas particionada por año (para alto volumen)
CREATE TABLE sales_partitioned (
    id UUID NOT NULL,
    sale_number VARCHAR(50) NOT NULL,
    source sale_source NOT NULL,
    customer_id UUID REFERENCES customers(id),
    shift_id UUID REFERENCES shifts(id),
    cashier_id UUID REFERENCES employees(id),
    order_id UUID REFERENCES orders(id),
    proforma_id UUID REFERENCES proformas(id),
    subtotal DECIMAL(10,2) NOT NULL,
    tax DECIMAL(10,2) DEFAULT 0,
    discount DECIMAL(10,2) DEFAULT 0,
    shipping_cost DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    status sale_status DEFAULT 'pending',
    notes TEXT,
    internal_notes TEXT,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Particiones por año para sales_partitioned
CREATE TABLE sales_2024 PARTITION OF sales_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE sales_2025 PARTITION OF sales_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE sales_2026 PARTITION OF sales_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- Tabla de ajustes de inventario particionada por mes
CREATE TABLE inventory_adjustments_partitioned (
    id UUID NOT NULL,
    inventory_id UUID REFERENCES inventory(id),
    adjustment_type adjustment_type NOT NULL,
    quantity_change INT NOT NULL,
    quantity_before INT NOT NULL,
    quantity_after INT NOT NULL,
    reason TEXT,
    reference_id UUID,
    reference_type VARCHAR(50),
    adjusted_by UUID REFERENCES users(id),
    adjusted_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id, adjusted_at)
) PARTITION BY RANGE (adjusted_at);

-- Particiones por mes para inventory_adjustments_partitioned
CREATE TABLE inventory_adj_2024_01 PARTITION OF inventory_adjustments_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE inventory_adj_2024_02 PARTITION OF inventory_adjustments_partitioned
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Función para crear nuevas particiones automáticamente
CREATE OR REPLACE FUNCTION create_sales_partition(p_year INT)
RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    start_date TEXT;
    end_date TEXT;
BEGIN
    partition_name := 'sales_' || p_year;
    start_date := p_year || '-01-01';
    end_date := (p_year + 1) || '-01-01';
    
    EXECUTE format(
        'CREATE TABLE %I PARTITION OF sales_partitioned
         FOR VALUES FROM (%L) TO (%L)',
        partition_name, start_date, end_date
    );
END;
$$ LANGUAGE plpgsql;

-- Función para crear particiones de ajustes de inventario
CREATE OR REPLACE FUNCTION create_inventory_adj_partition(p_year INT, p_month INT)
RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    start_date TEXT;
    end_date TEXT;
BEGIN
    partition_name := 'inventory_adj_' || p_year || '_' || LPAD(p_month::TEXT, 2, '0');
    start_date := p_year || '-' || LPAD(p_month::TEXT, 2, '0') || '-01';
    end_date := p_year || '-' || LPAD((p_month + 1)::TEXT, 2, '0') || '-01';
    IF p_month = 12 THEN
        end_date := (p_year + 1) || '-01-01';
    END IF;
    
    EXECUTE format(
        'CREATE TABLE %I PARTITION OF inventory_adjustments_partitioned
         FOR VALUES FROM (%L) TO (%L)',
        partition_name, start_date, end_date
    );
END;
$$ LANGUAGE plpgsql;

-- Añadir a schema.sql

-- 2. Listas de precios
CREATE TABLE price_lists ( ... );
CREATE TABLE price_list_items ( ... );
CREATE TABLE customer_price_lists ( ... );

-- 3. Reglas de descuento (opcional)
CREATE TABLE discount_rules ( ... );

CREATE INDEX idx_products_tags ON products USING GIN(tags);

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
CREATE INDEX idx_products_description_trgm ON products USING gin (description gin_trgm_ops);
-- Para búsqueda en customers
CREATE INDEX idx_customers_name_trgm ON customers USING gin (
    (COALESCE(first_name, '') || ' ' || COALESCE(last_name, '') || ' ' || COALESCE(company_name, '')) gin_trgm_ops
);
-- Para búsqueda en suppliers
CREATE INDEX idx_suppliers_name_trgm ON suppliers USING gin (name gin_trgm_ops);

-- Búsqueda por SKU de variante
CREATE UNIQUE INDEX idx_variants_sku ON product_variants(sku);

-- Búsqueda por Código de Barras (EAN/UPC)
CREATE INDEX idx_variants_barcode ON product_variants(barcode) WHERE barcode IS NOT NULL;

-- Búsqueda por atributos (Color, Talla, etc. en el JSONB)
CREATE INDEX idx_variants_attributes ON product_variants USING GIN(attributes);

---------------- Índices Compuestos para Queries Comunes
-- Búsqueda de ventas por cliente y fecha
CREATE INDEX idx_sales_customer_date ON sales(customer_id, created_at DESC);

-- Búsqueda de ventas por cajero y turno (POS)
CREATE INDEX idx_sales_cashier_shift ON sales(cashier_id, shift_id, created_at DESC);

-- Búsqueda de productos activos por categoría
CREATE INDEX idx_products_category_status ON products(category_id, status) 
    WHERE status = 'active' AND deleted_at IS NULL;

-- Inventario disponible por ubicación
CREATE INDEX idx_inventory_location_available ON inventory(warehouse_location, bin_location, available);

-- Órdenes de compra pendientes por proveedor
CREATE INDEX idx_po_supplier_status ON purchase_orders(supplier_id, status) 
    WHERE status IN ('draft', 'sent', 'confirmed');

-- Proformas vigentes por cliente
CREATE INDEX idx_proformas_customer_valid ON proformas(customer_id, valid_until) 
    WHERE status NOT IN ('expired', 'converted', 'rejected');

-- Pagos por método y fecha
CREATE INDEX idx_payments_method_date ON payments(payment_method, processed_at DESC);

-- Carritos abandonados
CREATE INDEX idx_carts_abandoned ON carts(updated_at DESC) 
    WHERE status = 'active' AND customer_id IS NOT NULL;

----- Índices Parciales Adicionales Recomendados
-- Empleados activos
CREATE INDEX idx_employees_active ON employees(employment_status) 
    WHERE employment_status = 'active';

-- Proveedores activos
CREATE INDEX idx_suppliers_active ON suppliers(status) 
    WHERE status = 'active' AND deleted_at IS NULL;

-- Productos con variantes
CREATE INDEX idx_products_with_variants ON products(has_variants) 
    WHERE has_variants = TRUE;

-- Facturas pendientes de pago
CREATE INDEX idx_invoices_unpaid ON invoices(status, due_date) 
    WHERE status IN ('draft', 'sent');

-- Alertas de stock pendientes
CREATE INDEX idx_stock_alerts_pending ON stock_alerts(alert_type, created_at DESC) 
    WHERE status = 'pending';

-------- -- Faltan triggers para estas tablas:
CREATE TRIGGER update_sales_updated_at BEFORE UPDATE ON sales
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_carts_updated_at BEFORE UPDATE ON carts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customer_addresses_updated_at BEFORE UPDATE ON customer_addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shifts_updated_at BEFORE UPDATE ON shifts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cash_registers_updated_at BEFORE UPDATE ON cash_registers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shipping_methods_updated_at BEFORE UPDATE ON shipping_methods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_methods_updated_at BEFORE UPDATE ON payment_methods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


------ Validaciones y Constraints Adicionales
-- En sales: validar que source coincida con referencias
ALTER TABLE sales ADD CONSTRAINT check_sale_source_refs CHECK (
    (source = 'pos' AND shift_id IS NOT NULL AND cashier_id IS NOT NULL) OR
    (source = 'ecommerce' AND order_id IS NOT NULL) OR
    (source NOT IN ('pos', 'ecommerce'))
);

-- En inventory: validar que quantity sea suficiente para reservas
ALTER TABLE inventory ADD CONSTRAINT check_inventory_sufficient CHECK (
    quantity >= (reserved_ecommerce + reserved_pos + committed)
);

-- En customers: validar que current_balance no exceda credit_limit
-- (Esto ya se valida en trigger, pero agregar constraint para seguridad)

-- En sale_items: validar que subtotal sea correcto
ALTER TABLE sale_items ADD CONSTRAINT check_sale_item_subtotal CHECK (
    subtotal = (unit_price * quantity) - discount_amount
);

-- En payments: validar que amount sea positivo
ALTER TABLE payments ADD CONSTRAINT check_payment_amount CHECK (amount > 0);

-- En shifts: validar que difference sea correcto cuando está cerrado
ALTER TABLE shifts ADD CONSTRAINT check_shift_difference CHECK (
    (status != 'closed') OR 
    (status = 'closed' AND difference IS NOT NULL AND difference = closing_cash - expected_cash)
);

-- Para tablas de alta escritura
ALTER TABLE inventory SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);

ALTER TABLE sales SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

ALTER TABLE sale_items SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
); 