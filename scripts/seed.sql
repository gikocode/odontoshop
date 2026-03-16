-- Primero los Roles (Asegúrate de que la tabla roles exista)
INSERT INTO roles (id, name, description) 
VALUES (1, 'admin', 'Administrador con acceso total')
ON CONFLICT (id) DO NOTHING;

-- Luego el Usuario Semilla (Ajustado a una estructura común de Go)
-- Insertar Usuario Semilla con tu estructura real
-- Nota: Password es 'admin123'
INSERT INTO users (
    id, 
    email, 
    password_hash, 
    user_type, 
    status, 
    created_at, 
    updated_at
) 
VALUES (
    gen_random_uuid(), 
    'admin@odontoshop.com', 
    '$2a$10$ByI6pxNTr0.ZfN31.nFm0eB9YF9lU6Nf/vXvU1O6.yO6yO6yO6yO6', 
    'admin', 
    'active', 
    NOW(), 
    NOW()
)
ON CONFLICT (email) DO NOTHING;