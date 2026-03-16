-- ============================================----------------------------------------------------------------
-- DATOS INICIALES (SEEDS)
-- ============================================---------------------------------

-- Roles del sistema
INSERT INTO roles (name, display_name, description, is_system_role) VALUES
('super_admin', 'Super Administrador', 'Control total del sistema', TRUE),
('manager', 'Gerente', 'Gestión de inventario, productos y reportes', TRUE),
('warehouse', 'Almacén', 'Gestión de inventario y compras', TRUE),
('cashier', 'Cajero', 'Ventas en punto de venta', TRUE),
('sales', 'Vendedor', 'Ventas y atención al cliente', TRUE),
('customer', 'Cliente', 'Cliente del sistema', TRUE);

-- Permisos básicos
INSERT INTO permissions (resource, action, description) VALUES
-- Productos
('products', 'create', 'Crear productos'),
('products', 'read', 'Ver productos'),
('products', 'update', 'Editar productos'),
('products', 'delete', 'Eliminar productos'),
-- Inventario
('inventory', 'read', 'Ver inventario'),
('inventory', 'update', 'Ajustar inventario'),
('inventory', 'count', 'Realizar conteos físicos'),
-- Usuarios
('users', 'create', 'Crear usuarios'),
('users', 'read', 'Ver usuarios'),
('users', 'update', 'Editar usuarios'),
('users', 'delete', 'Eliminar usuarios'),
-- Ventas
('sales', 'create', 'Crear ventas'),
('sales', 'read', 'Ver ventas'),
('sales', 'cancel', 'Cancelar ventas'),
-- Reportes
('reports', 'read', 'Ver reportes'),
('reports', 'export', 'Exportar reportes'),
-- Configuración
('settings', 'read', 'Ver configuración'),
('settings', 'update', 'Modificar configuración'),
-- Compras
('purchases', 'create', 'Crear órdenes de compra'),
('purchases', 'read', 'Ver órdenes de compra'),
('purchases', 'approve', 'Aprobar órdenes de compra'),
-- Proveedores
('suppliers', 'create', 'Crear proveedores'),
('suppliers', 'read', 'Ver proveedores'),
('suppliers', 'update', 'Editar proveedores'),
-- Clientes
('customers', 'create', 'Crear clientes'),
('customers', 'read', 'Ver clientes'),
('customers', 'update', 'Editar clientes'),
('customers', 'manage_credit', 'Gestionar crédito de clientes'),
-- Proformas
('proformas', 'create', 'Crear proformas'),
('proformas', 'read', 'Ver proformas'),
('proformas', 'approve', 'Aprobar proformas');

-- Asignar permisos a super_admin
INSERT INTO role_permissions (role_id, permission_id)
SELECT 
    (SELECT id FROM roles WHERE name = 'super_admin'),
    id
FROM permissions;

-- Asignar permisos a manager
INSERT INTO role_permissions (role_id, permission_id)
SELECT 
    (SELECT id FROM roles WHERE name = 'manager'),
    id
FROM permissions
WHERE resource IN ('products', 'inventory', 'reports', 'suppliers', 'customers', 'purchases', 'proformas');

-- Asignar permisos a warehouse
INSERT INTO role_permissions (role_id, permission_id)
SELECT 
    (SELECT id FROM roles WHERE name = 'warehouse'),
    id
FROM permissions
WHERE resource IN ('products', 'inventory', 'purchases', 'suppliers') AND action IN ('read', 'update');

-- Usuario admin inicial (Password: Admin123!)
INSERT INTO users (email, password_hash, user_type, status, email_verified)
VALUES (
    'admin@miempresa.com',
    crypt('Admin123!', gen_salt('bf', 12)),
    'employee',
    'active',
    TRUE
);

INSERT INTO employees (user_id, employee_number, first_name, last_name, position, hire_date, department, employment_status)
VALUES (
    (SELECT id FROM users WHERE email = 'admin@miempresa.com'),
    'EMP-00001',
    'Admin',
    'Sistema',
    'Super Administrador',
    '2024-01-15',
    'IT',
    'active'
);

INSERT INTO user_roles (user_id, role_id)
VALUES (
    (SELECT id FROM users WHERE email = 'admin@miempresa.com'),
    (SELECT id FROM roles WHERE name = 'super_admin')
);

-- Usuario gerente (Password: Manager123!)
INSERT INTO users (email, password_hash, user_type, status, email_verified)
VALUES (
    'gerente@miempresa.com',
    crypt('Manager123!', gen_salt('bf', 12)),
    'employee',
    'active',
    TRUE
);

INSERT INTO employees (user_id, employee_number, first_name, last_name, position, hire_date, department, employment_status)
VALUES (
    (SELECT id FROM users WHERE email = 'gerente@miempresa.com'),
    'EMP-00002',
    'María',
    'García',
    'Gerente General',
    '2024-02-01',
    'Administración',
    'active'
);

INSERT INTO user_roles (user_id, role_id)
VALUES (
    (SELECT id FROM users WHERE email = 'gerente@miempresa.com'),
    (SELECT id FROM roles WHERE name = 'manager')
);

-- Clientes de ejemplo (Password: Customer123!)
INSERT INTO users (email, password_hash, user_type, status, email_verified, phone)
VALUES 
('cliente1@email.com', crypt('Customer123!', gen_salt('bf', 12)), 'customer', 'active', TRUE, '+32 2 123 4567'),
('cliente2@empresa.com', crypt('Customer123!', gen_salt('bf', 12)), 'customer', 'active', TRUE, '+32 2 234 5678');

INSERT INTO customers (user_id, customer_number, customer_type, first_name, last_name, billing_address, city, country, postal_code, credit_status, credit_limit, loyalty_tier)
VALUES 
(
    (SELECT id FROM users WHERE email = 'cliente1@email.com'),
    'CLI-00001',
    'retail',
    'Juan',
    'Pérez',
    'Rue de la Loi 123',
    'Brussels',
    'BE',
    '1000',
    'none',
    0,
    'bronze'
),
(
    (SELECT id FROM users WHERE email = 'cliente2@empresa.com'),
    'CLI-00002',
    'wholesale',
    'Ana',
    'Martínez',
    'Avenue Louise 456',
    'Brussels',
    'BE',
    '1050',
    'approved',
    5000.00,
    'gold'
);

-- Categorías de ejemplo
INSERT INTO categories (name, slug, description, display_order) VALUES
('Electrónicos', 'electronicos', 'Dispositivos y accesorios electrónicos', 1),
('Ropa', 'ropa', 'Indumentaria y accesorios de moda', 2),
('Hogar', 'hogar', 'Artículos para el hogar y decoración', 3),
('Deportes', 'deportes', 'Equipamiento deportivo y fitness', 4);

-- Subcategorías
INSERT INTO categories (name, slug, parent_id, display_order) VALUES
('Smartphones', 'smartphones', (SELECT id FROM categories WHERE slug = 'electronicos'), 1),
('Laptops', 'laptops', (SELECT id FROM categories WHERE slug = 'electronicos'), 2),
('Camisetas', 'camisetas', (SELECT id FROM categories WHERE slug = 'ropa'), 1),
('Pantalones', 'pantalones', (SELECT id FROM categories WHERE slug = 'ropa'), 2);

-- Proveedores
INSERT INTO suppliers (name, company_name, tax_id, contact_person, contact_email, contact_phone, address, city, country, payment_terms_days, rating, status)
VALUES 
(
    'Tech Distributors Europe',
    'Tech Distributors Europe BVBA',
    'BE0987654321',
    'Pierre Dubois',
    'contact@techdist.be',
    '+32 2 555 1234',
    'Industrielaan 100',
    'Antwerp',
    'BE',
    30,
    4.5,
    'active'
),
(
    'Textiles del Norte',
    'Textiles del Norte S.A.',
    'BE0123456789',
    'Carmen López',
    'ventas@textilesnorte.com',
    '+34 91 555 6789',
    'Calle Mayor 50',
    'Madrid',
    'ES',
    45,
    4.2,
    'active'
);

-- Producto simple SIN variantes
INSERT INTO products (
    name, slug, base_sku, base_price, cost_price, compare_at_price,
    has_variants, category_id, brand, description, short_description,
    status, weight, is_taxable, tax_rate, track_inventory,
    created_by
) VALUES (
    'Mouse Inalámbrico Logitech M185',
    'mouse-logitech-m185',
    'MOUSE-LOG-M185',
    24.99,
    12.50,
    29.99,
    FALSE,
    (SELECT id FROM categories WHERE slug = 'electronicos'),
    'Logitech',
    'Mouse inalámbrico con sensor óptico avanzado y batería de larga duración',
    'Mouse inalámbrico ergonómico',
    'active',
    0.085,
    TRUE,
    21.00,
    TRUE,
    (SELECT id FROM users WHERE email = 'admin@miempresa.com')
);

-- Inventario del mouse
INSERT INTO inventory (product_id, quantity, low_stock_threshold, reorder_point, warehouse_location, bin_location)
VALUES (
    (SELECT id FROM products WHERE base_sku = 'MOUSE-LOG-M185'),
    150,
    20,
    40,
    'ALMACEN-A',
    'A-12-03'
);

-- Producto CON variantes (Camiseta)
INSERT INTO products (
    name, slug, base_price, cost_price, has_variants, variant_options,
    category_id, brand, description, short_description,
    status, is_taxable, tax_rate, track_inventory,
    created_by
) VALUES (
    'Camiseta Básica Premium',
    'camiseta-basica-premium',
    19.99,
    7.50,
    TRUE,
    '{
        "size": ["XS", "S", "M", "L", "XL", "XXL"],
        "color": ["Blanco", "Negro", "Azul Marino", "Gris"]
    }'::jsonb,
    (SELECT id FROM categories WHERE slug = 'camisetas'),
    'Basic Wear',
    'Camiseta 100% algodón de alta calidad, corte clásico',
    'Camiseta básica de algodón premium',
    'active',
    TRUE,
    21.00,
    TRUE,
    (SELECT id FROM users WHERE email = 'admin@miempresa.com')
);

-- Variantes de la camiseta
INSERT INTO product_variants (product_id, sku, attributes, price, cost_price, barcode, is_default, position)
VALUES 
-- Talla M
(
    (SELECT id FROM products WHERE slug = 'camiseta-basica-premium'),
    'CAM-BAS-M-WHI',
    '{"size": "M", "color": "Blanco"}'::jsonb,
    19.99,
    7.50,
    '7501234567890',
    TRUE,
    1
),
(
    (SELECT id FROM products WHERE slug = 'camiseta-basica-premium'),
    'CAM-BAS-M-BLK',
    '{"size": "M", "color": "Negro"}'::jsonb,
    19.99,
    7.50,
    '7501234567891',
    FALSE,
    2
),
(
    (SELECT id FROM products WHERE slug = 'camiseta-basica-premium'),
    'CAM-BAS-M-NAV',
    '{"size": "M", "color": "Azul Marino"}'::jsonb,
    19.99,
    7.50,
    '7501234567892',
    FALSE,
    3
),
-- Talla L
(
    (SELECT id FROM products WHERE slug = 'camiseta-basica-premium'),
    'CAM-BAS-L-WHI',
    '{"size": "L", "color": "Blanco"}'::jsonb,
    19.99,
    7.50,
    '7501234567893',
    FALSE,
    4
),
(
    (SELECT id FROM products WHERE slug = 'camiseta-basica-premium'),
    'CAM-BAS-L-BLK',
    '{"size": "L", "color": "Negro"}'::jsonb,
    19.99,
    7.50,
    '7501234567894',
    FALSE,
    5
);

-- Inventario de variantes
INSERT INTO inventory (variant_id, quantity, low_stock_threshold, reorder_point, warehouse_location, bin_location)
SELECT 
    id,
    CASE 
        WHEN sku LIKE '%WHI' THEN 80
        WHEN sku LIKE '%BLK' THEN 100
        ELSE 60
    END as quantity,
    15,
    30,
    'ALMACEN-B',
    'B-05-' || LPAD((ROW_NUMBER() OVER())::TEXT, 2, '0')
FROM product_variants
WHERE product_id = (SELECT id FROM products WHERE slug = 'camiseta-basica-premium');

-- Relacionar proveedores con productos
INSERT INTO product_suppliers (product_id, supplier_id, supplier_sku, cost_price, lead_time_days, is_preferred)
VALUES (
    (SELECT id FROM products WHERE base_sku = 'MOUSE-LOG-M185'),
    (SELECT id FROM suppliers WHERE name = 'Tech Distributors Europe'),
    'TDE-MOUSE-LOG-M185',
    12.50,
    7,
    TRUE
);

INSERT INTO product_suppliers (variant_id, supplier_id, supplier_sku, cost_price, lead_time_days, is_preferred)
SELECT 
    pv.id,
    (SELECT id FROM suppliers WHERE name = 'Textiles del Norte'),
    'TDN-' || pv.sku,
    7.50,
    14,
    TRUE
FROM product_variants pv
WHERE pv.product_id = (SELECT id FROM products WHERE slug = 'camiseta-basica-premium');

-- Orden de compra de ejemplo
INSERT INTO purchase_orders (
    supplier_id, order_date, expected_delivery_date, 
    subtotal, tax, total, status, created_by
) VALUES (
    (SELECT id FROM suppliers WHERE name = 'Tech Distributors Europe'),
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '7 days',
    625.00,
    131.25,
    756.25,
    'sent',
    (SELECT id FROM users WHERE email = 'admin@miempresa.com')
);

-- Items de la orden de compra
INSERT INTO purchase_order_items (purchase_order_id, product_id, quantity_ordered, unit_cost, subtotal)
VALUES (
    (SELECT id FROM purchase_orders ORDER BY created_at DESC LIMIT 1),
    (SELECT id FROM products WHERE base_sku = 'MOUSE-LOG-M185'),
    50,
    12.50,
    625.00
);

-- Proforma de ejemplo
INSERT INTO proformas (
    customer_id, issue_date, valid_until, 
    subtotal, tax, discount, total, 
    payment_terms, status, created_by
) VALUES (
    (SELECT id FROM customers WHERE customer_number = 'CLI-00002'),
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '30 days',
    499.75,
    104.95,
    0,
    604.70,
    'Pago a 30 días desde la fecha de factura',
    'sent',
    (SELECT id FROM users WHERE email = 'gerente@miempresa.com')
);

-- Items de la proforma
INSERT INTO proforma_items (proforma_id, product_id, quantity, unit_price, subtotal)
VALUES (
    (SELECT id FROM proformas ORDER BY created_at DESC LIMIT 1),
    (SELECT id FROM products WHERE base_sku = 'MOUSE-LOG-M185'),
    20,
    24.99,
    499.80
);

-- Configuración del negocio
INSERT INTO business_settings (key, value, description, category) VALUES
('business_name', '"Mi Empresa S.A."', 'Nombre legal del negocio', 'general'),
('tax_id', '"BE0987654321"', 'NIT/Número de IVA', 'general'),
('default_currency', '"EUR"', 'Moneda por defecto', 'general'),
('default_tax_rate', '21', 'IVA por defecto (%)', 'tax'),
('low_stock_alert', 'true', 'Activar alertas de stock bajo', 'inventory'),
('allow_negative_inventory', 'false', 'Permitir inventario negativo', 'inventory'),
('default_payment_terms_days', '30', 'Días de crédito por defecto', 'sales'),
('business_email', '"info@miempresa.com"', 'Email de contacto', 'general'),
('business_phone', '"+32 2 555 9999"', 'Teléfono principal', 'general'),
('business_address', '"Avenue de la Toison d''Or 1, 1050 Brussels, Belgium"', 'Dirección fiscal', 'general');

-- Ajustes de inventario de ejemplo
INSERT INTO inventory_adjustments (
    inventory_id, adjustment_type, quantity_change, 
    quantity_before, quantity_after, reason, adjusted_by
) VALUES (
    (SELECT id FROM inventory WHERE product_id = (SELECT id FROM products WHERE base_sku = 'MOUSE-LOG-M185')),
    'initial_stock',
    150,
    0,
    150,
    'Stock inicial en sistema',
    (SELECT id FROM users WHERE email = 'admin@miempresa.com')

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
);