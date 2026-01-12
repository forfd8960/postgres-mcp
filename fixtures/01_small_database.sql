-- =============================================================================
-- pg-mcp Small Test Database
-- Purpose: Basic testing of schema discovery and query functionality
-- Tables: 5 | Views: 2 | Types: 1 | Indexes: 5
-- =============================================================================

-- This file should be loaded into an existing database.
-- Use Makefile to create and populate the database:
--   make setup-small

-- =============================================================================
-- TYPE DEFINITIONS
-- =============================================================================

-- User status enum type
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended');

-- =============================================================================
-- SCHEMA
-- =============================================================================

-- Create a custom schema for organization
CREATE SCHEMA testbed;

-- =============================================================================
-- TABLES
-- =============================================================================

-- Users table
CREATE TABLE testbed.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    status user_status DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Products table
CREATE TABLE testbed.products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0),
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE testbed.orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES testbed.users(id),
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    shipped_at TIMESTAMP
);

-- Order items table (order-product relationship)
CREATE TABLE testbed.order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES testbed.orders(id),
    product_id INTEGER REFERENCES testbed.products(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price DECIMAL(10, 2) NOT NULL
);

-- Categories table (self-referencing)
CREATE TABLE testbed.categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    parent_id INTEGER REFERENCES testbed.categories(id),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX idx_users_email ON testbed.users(email);
CREATE INDEX idx_users_status ON testbed.users(status);
CREATE INDEX idx_products_category ON testbed.products(category);
CREATE INDEX idx_products_price ON testbed.products(price);
CREATE INDEX idx_orders_user_id ON testbed.orders(user_id);
CREATE INDEX idx_orders_status ON testbed.orders(status);
CREATE INDEX idx_orders_created_at ON testbed.orders(created_at);

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Active users view
CREATE VIEW testbed.active_users AS
SELECT id, username, email, created_at
FROM testbed.users
WHERE status = 'active';

-- Order summary view
CREATE VIEW testbed.order_summary AS
SELECT
    o.id AS order_id,
    o.user_id,
    u.username,
    o.total_amount,
    o.status,
    o.created_at,
    COUNT(oi.id) AS item_count
FROM testbed.orders o
JOIN testbed.users u ON o.user_id = u.id
LEFT JOIN testbed.order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.user_id, u.username, o.total_amount, o.status, o.created_at;

-- =============================================================================
-- SAMPLE DATA - USERS (10 rows)
-- =============================================================================

INSERT INTO testbed.users (username, email, status) VALUES
    ('alice', 'alice@example.com', 'active'),
    ('bob', 'bob@example.com', 'active'),
    ('charlie', 'charlie@example.com', 'inactive'),
    ('diana', 'diana@example.com', 'active'),
    ('eve', 'eve@example.com', 'active'),
    ('frank', 'frank@example.com', 'suspended'),
    ('grace', 'grace@example.com', 'active'),
    ('henry', 'henry@example.com', 'inactive'),
    ('iris', 'iris@example.com', 'active'),
    ('jack', 'jack@example.com', 'active');

-- Update last_login for some users
UPDATE testbed.users SET last_login = '2025-01-10 10:00:00' WHERE id <= 5;

-- =============================================================================
-- SAMPLE DATA - CATEGORIES (5 rows)
-- =============================================================================

INSERT INTO testbed.categories (name, parent_id, description) VALUES
    ('Electronics', NULL, 'Electronic devices and accessories'),
    ('Books', NULL, 'Books and publications'),
    ('Clothing', NULL, 'Apparel and accessories'),
    ('Smartphones', 1, 'Mobile phones and tablets'),
    ('Laptops', 1, 'Portable computers');

-- =============================================================================
-- SAMPLE DATA - PRODUCTS (15 rows)
-- =============================================================================

INSERT INTO testbed.products (name, description, price, stock_quantity, category) VALUES
    ('Laptop Pro 15', 'High-performance laptop', 1299.99, 50, 'Laptops'),
    ('Smartphone X', 'Latest smartphone', 999.99, 100, 'Smartphones'),
    ('Wireless Earbuds', 'Bluetooth earbuds', 79.99, 200, 'Electronics'),
    ('Python Programming', 'Learn Python programming', 49.99, 150, 'Books'),
    ('SQL Mastery', 'Advanced SQL techniques', 59.99, 80, 'Books'),
    ('Cotton T-Shirt', 'Comfortable cotton shirt', 24.99, 300, 'Clothing'),
    ('Denim Jeans', 'Classic denim jeans', 59.99, 120, 'Clothing'),
    ('Tablet Pro', '12-inch tablet', 799.99, 40, 'Smartphones'),
    ('Gaming Laptop', 'Gaming laptop with GPU', 1899.99, 25, 'Laptops'),
    ('USB-C Hub', 'Multi-port USB-C hub', 39.99, 500, 'Electronics'),
    ('Mechanical Keyboard', 'RGB mechanical keyboard', 129.99, 75, 'Electronics'),
    ('Programming Guide', 'JavaScript guide', 34.99, 200, 'Books'),
    ('Hoodie', 'Warm hoodie', 44.99, 100, 'Clothing'),
    ('Smart Watch', 'Fitness tracking watch', 249.99, 60, 'Electronics'),
    ('Desk Lamp', 'LED desk lamp', 29.99, 180, 'Electronics');

-- =============================================================================
-- SAMPLE DATA - ORDERS (20 rows)
-- =============================================================================

INSERT INTO testbed.orders (user_id, total_amount, status, created_at) VALUES
    (1, 1399.98, 'completed', '2025-01-01 10:00:00'),
    (1, 79.99, 'completed', '2025-01-02 14:30:00'),
    (1, 49.99, 'completed', '2025-01-05 09:15:00'),
    (2, 1299.99, 'completed', '2025-01-03 11:00:00'),
    (2, 24.99, 'pending', '2025-01-06 16:45:00'),
    (3, 59.99, 'shipped', '2025-01-04 13:20:00'),
    (4, 799.99, 'completed', '2025-01-07 10:30:00'),
    (4, 129.99, 'completed', '2025-01-08 15:00:00'),
    (5, 249.99, 'shipped', '2025-01-09 12:00:00'),
    (5, 39.99, 'pending', '2025-01-10 09:30:00'),
    (5, 34.99, 'completed', '2025-01-10 11:00:00'),
    (7, 1899.99, 'completed', '2025-01-08 14:00:00'),
    (7, 29.99, 'completed', '2025-01-09 16:30:00'),
    (8, 99.99, 'refunded', '2025-01-07 10:00:00'),
    (9, 499.99, 'completed', '2025-01-06 11:30:00'),
    (9, 149.99, 'shipped', '2025-01-09 13:45:00'),
    (10, 79.99, 'completed', '2025-01-05 15:15:00'),
    (10, 59.99, 'completed', '2025-01-08 17:00:00'),
    (10, 199.99, 'pending', '2025-01-10 08:30:00'),
    (10, 44.99, 'completed', '2025-01-10 12:00:00');

-- =============================================================================
-- SAMPLE DATA - ORDER ITEMS (35 rows)
-- =============================================================================

INSERT INTO testbed.order_items (order_id, product_id, quantity, price) VALUES
    (1, 1, 1, 1299.99), (1, 3, 1, 79.99),
    (2, 3, 1, 79.99),
    (3, 4, 1, 49.99),
    (4, 2, 1, 999.99), (4, 11, 1, 129.99), (4, 14, 1, 249.99),
    (5, 6, 1, 24.99),
    (6, 5, 1, 59.99),
    (7, 8, 1, 799.99),
    (8, 11, 1, 129.99),
    (9, 14, 1, 249.99),
    (10, 10, 1, 39.99),
    (11, 12, 1, 34.99),
    (12, 9, 1, 1899.99),
    (13, 15, 1, 29.99),
    (14, 3, 1, 79.99), (14, 10, 1, 39.99),
    (15, 2, 1, 999.99),
    (16, 11, 1, 129.99), (16, 14, 1, 249.99),
    (17, 3, 1, 79.99),
    (18, 4, 1, 49.99), (18, 5, 1, 59.99),
    (19, 14, 1, 249.99),
    (20, 13, 1, 44.99),
    (2, 10, 2, 39.99),  -- Additional items
    (3, 15, 1, 29.99),
    (5, 7, 2, 59.99),
    (6, 6, 1, 24.99),
    (9, 8, 1, 799.99),
    (10, 3, 1, 79.99),
    (11, 11, 1, 129.99),
    (15, 1, 1, 1299.99),
    (16, 4, 1, 49.99),
    (17, 12, 1, 34.99);

-- Update shipped_at for shipped orders
UPDATE testbed.orders SET shipped_at = created_at + INTERVAL '1 day' WHERE status = 'shipped';

-- =============================================================================
-- VERIFICATION
-- =============================================================================

-- SELECT 'Database db_pg_mcp_small created successfully!' AS status;
-- SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema = 'testbed';
-- SELECT COUNT(*) AS view_count FROM information_schema.views WHERE table_schema = 'testbed';
