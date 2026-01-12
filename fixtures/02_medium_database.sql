-- =============================================================================
-- pg-mcp Medium Test Database
-- Purpose: Testing complex queries, joins, aggregations, and schema discovery
-- Tables: 20 | Views: 5 | Types: 3 | Indexes: 30+
-- =============================================================================

-- This file should be loaded into an existing database.
-- Use Makefile to create and populate the database:
--   make setup-medium

-- =============================================================================
-- TYPE DEFINITIONS
-- =============================================================================

-- Enum types for status fields
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
CREATE TYPE user_role AS ENUM ('customer', 'admin', 'moderator', 'vendor');

-- Composite type for address
CREATE TYPE address_type AS (
    street VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(100)
);

-- =============================================================================
-- SCHEMAS
-- =============================================================================

CREATE SCHEMA sales;
CREATE SCHEMA inventory;
CREATE SCHEMA hr;

-- =============================================================================
-- TABLES - SALES SCHEMA (8 tables)
-- =============================================================================

-- Customers table
CREATE TABLE sales.customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    role user_role DEFAULT 'customer',
    loyalty_points INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customer addresses
CREATE TABLE sales.customer_addresses (
    address_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES sales.customers(customer_id) ON DELETE CASCADE,
    address_type VARCHAR(20) DEFAULT 'shipping',
    address address_type,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table (shared across schemas)
CREATE TABLE sales.products (
    product_id SERIAL PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    base_price DECIMAL(10, 2) NOT NULL CHECK (base_price >= 0),
    tax_rate DECIMAL(4, 4) DEFAULT 0.08,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product pricing tiers (volume discounts)
CREATE TABLE sales.pricing_tiers (
    tier_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES sales.products(product_id) ON DELETE CASCADE,
    min_quantity INTEGER NOT NULL,
    max_quantity INTEGER,
    price_multiplier DECIMAL(4, 2) DEFAULT 1.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE sales.orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES sales.customers(customer_id),
    order_number VARCHAR(20) NOT NULL UNIQUE,
    status order_status DEFAULT 'pending',
    subtotal DECIMAL(10, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    notes TEXT,
    ordered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP
);

-- Order items
CREATE TABLE sales.order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES sales.products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    total_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payments
CREATE TABLE sales.payments (
    payment_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES sales.orders(order_id),
    payment_method VARCHAR(50) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_status payment_status DEFAULT 'pending',
    transaction_id VARCHAR(100),
    paid_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Discounts/Promotions
CREATE TABLE sales.discounts (
    discount_id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    description VARCHAR(200),
    discount_type VARCHAR(20) NOT NULL,
    discount_value DECIMAL(10, 2) NOT NULL,
    min_order_amount DECIMAL(10, 2) DEFAULT 0,
    max_discount_amount DECIMAL(10, 2),
    usage_limit INTEGER,
    usage_count INTEGER DEFAULT 0,
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLES - INVENTORY SCHEMA (8 tables)
-- =============================================================================

-- Warehouses
CREATE TABLE inventory.warehouses (
    warehouse_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location address_type,
    capacity_cubic_feet INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory locations within warehouse
CREATE TABLE inventory.locations (
    location_id SERIAL PRIMARY KEY,
    warehouse_id INTEGER NOT NULL REFERENCES inventory.warehouses(warehouse_id),
    zone CHAR(1) NOT NULL,
    aisle INTEGER NOT NULL,
    rack INTEGER NOT NULL,
    shelf INTEGER NOT NULL,
    bin VARCHAR(10),
    location_code VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory stock
CREATE TABLE inventory.stock (
    stock_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES sales.products(product_id),
    warehouse_id INTEGER NOT NULL REFERENCES inventory.warehouses(warehouse_id),
    location_id INTEGER REFERENCES inventory.locations(location_id),
    quantity_on_hand INTEGER DEFAULT 0,
    quantity_reserved INTEGER DEFAULT 0,
    quantity_available INTEGER GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved) STORED,
    reorder_point INTEGER DEFAULT 10,
    last_restocked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stock movements
CREATE TABLE inventory.stock_movements (
    movement_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES sales.products(product_id),
    from_warehouse_id INTEGER REFERENCES inventory.warehouses(warehouse_id),
    to_warehouse_id INTEGER REFERENCES inventory.warehouses(warehouse_id),
    movement_type VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL,
    reference_type VARCHAR(50),
    reference_id VARCHAR(100),
    notes TEXT,
    movement_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100)
);

-- Suppliers
CREATE TABLE inventory.suppliers (
    supplier_id SERIAL PRIMARY KEY,
    company_name VARCHAR(200) NOT NULL,
    contact_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address address_type,
    lead_time_days INTEGER DEFAULT 7,
    rating DECIMAL(2, 1) DEFAULT 3.0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Purchase orders
CREATE TABLE inventory.purchase_orders (
    po_id SERIAL PRIMARY KEY,
    supplier_id INTEGER NOT NULL REFERENCES inventory.suppliers(supplier_id),
    warehouse_id INTEGER NOT NULL REFERENCES inventory.warehouses(warehouse_id),
    po_number VARCHAR(20) NOT NULL UNIQUE,
    status VARCHAR(20) DEFAULT 'draft',
    expected_delivery DATE,
    actual_delivery DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Purchase order items
CREATE TABLE inventory.po_items (
    po_item_id SERIAL PRIMARY KEY,
    po_id INTEGER NOT NULL REFERENCES inventory.purchase_orders(po_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES sales.products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_cost DECIMAL(10, 2) NOT NULL,
    received_quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product-supplier relationships
CREATE TABLE inventory.product_suppliers (
    product_id INTEGER NOT NULL REFERENCES sales.products(product_id),
    supplier_id INTEGER NOT NULL REFERENCES inventory.suppliers(supplier_id),
    is_primary BOOLEAN DEFAULT FALSE,
    lead_time_days INTEGER DEFAULT 7,
    unit_cost DECIMAL(10, 2) NOT NULL,
    min_order_quantity INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id, supplier_id)
);

-- =============================================================================
-- TABLES - HR SCHEMA (4 tables)
-- =============================================================================

-- Departments
CREATE TABLE hr.departments (
    department_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    parent_department_id INTEGER REFERENCES hr.departments(department_id),
    budget DECIMAL(12, 2) DEFAULT 0,
    manager_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Employees
CREATE TABLE hr.employees (
    employee_id SERIAL PRIMARY KEY,
    employee_code VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    department_id INTEGER REFERENCES hr.departments(department_id),
    job_title VARCHAR(100),
    hire_date DATE NOT NULL,
    salary DECIMAL(10, 2) CHECK (salary >= 0),
    commission_rate DECIMAL(5, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    termination_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Update departments with manager references
ALTER TABLE hr.departments
ADD CONSTRAINT fk_dept_manager
FOREIGN KEY (manager_id) REFERENCES hr.employees(employee_id);

-- Employee attendance
CREATE TABLE hr.attendance (
    attendance_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES hr.employees(employee_id),
    date DATE NOT NULL,
    check_in TIME,
    check_out TIME,
    hours_worked DECIMAL(4, 2),
    overtime_hours DECIMAL(4, 2) DEFAULT 0,
    notes TEXT,
    UNIQUE(employee_id, date)
);

-- Salary history
CREATE TABLE hr.salary_history (
    history_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES hr.employees(employee_id),
    salary DECIMAL(10, 2) NOT NULL,
    effective_date DATE NOT NULL,
    end_date DATE,
    reason VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- INDEXES
-- =============================================================================

-- Sales indexes
CREATE INDEX idx_customers_email ON sales.customers(email);
CREATE INDEX idx_customers_name ON sales.customers(last_name, first_name);
CREATE INDEX idx_customers_role ON sales.customers(role);
CREATE INDEX idx_products_sku ON sales.products(sku);
CREATE INDEX idx_products_active ON sales.products(is_active);
CREATE INDEX idx_products_price ON sales.products(base_price);
CREATE INDEX idx_orders_customer ON sales.orders(customer_id);
CREATE INDEX idx_orders_status ON sales.orders(status);
CREATE INDEX idx_orders_number ON sales.orders(order_number);
CREATE INDEX idx_orders_date ON sales.orders(ordered_at);
CREATE INDEX idx_order_items_order ON sales.order_items(order_id);
CREATE INDEX idx_order_items_product ON sales.order_items(product_id);
CREATE INDEX idx_payments_order ON sales.payments(order_id);
CREATE INDEX idx_payments_status ON sales.payments(payment_status);
CREATE INDEX idx_discounts_code ON sales.discounts(code);
CREATE INDEX idx_discounts_dates ON sales.discounts(valid_from, valid_until);

-- Inventory indexes
CREATE INDEX idx_stock_product ON inventory.stock(product_id);
CREATE INDEX idx_stock_warehouse ON inventory.stock(warehouse_id);
CREATE INDEX idx_stock_location ON inventory.stock(location_id);
CREATE INDEX idx_stock_available ON inventory.stock(quantity_available);
CREATE INDEX idx_movements_product ON inventory.stock_movements(product_id);
CREATE INDEX idx_movements_date ON inventory.stock_movements(movement_date);
CREATE INDEX idx_suppliers_active ON inventory.suppliers(is_active);
CREATE INDEX idx_po_supplier ON inventory.purchase_orders(supplier_id);
CREATE INDEX idx_po_status ON inventory.purchase_orders(status);

-- HR indexes
CREATE INDEX idx_employees_dept ON hr.employees(department_id);
CREATE INDEX idx_employees_code ON hr.employees(employee_code);
CREATE INDEX idx_employees_name ON hr.employees(last_name, first_name);
CREATE INDEX idx_employees_active ON hr.employees(is_active);
CREATE INDEX idx_attendance_employee ON hr.attendance(employee_id);
CREATE INDEX idx_attendance_date ON hr.attendance(date);
CREATE INDEX idx_salary_history_emp ON hr.salary_history(employee_id);

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Customer orders view
CREATE VIEW sales.customer_orders AS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.loyalty_points,
    COUNT(o.order_id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS total_spent,
    MAX(o.ordered_at) AS last_order_date
FROM sales.customers c
LEFT JOIN sales.orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.loyalty_points;

-- Order details view
CREATE VIEW sales.order_details AS
SELECT
    o.order_id,
    o.order_number,
    o.status,
    o.total_amount,
    o.tax_amount,
    o.shipping_cost,
    o.ordered_at,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email AS customer_email,
    COUNT(oi.item_id) AS item_count,
    STRING_AGG(p.name, ', ' ORDER BY oi.item_id) AS products
FROM sales.orders o
JOIN sales.customers c ON o.customer_id = c.customer_id
LEFT JOIN sales.order_items oi ON o.order_id = oi.order_id
LEFT JOIN sales.products p ON oi.product_id = p.product_id
GROUP BY o.order_id, o.order_number, o.status, o.total_amount, o.tax_amount,
         o.shipping_cost, o.ordered_at, c.first_name, c.last_name, c.email;

-- Inventory status view
CREATE VIEW inventory.inventory_status AS
SELECT
    p.product_id,
    p.sku,
    p.name,
    p.base_price,
    w.warehouse_id,
    w.name AS warehouse_name,
    SUM(s.quantity_on_hand) AS total_stock,
    SUM(s.quantity_reserved) AS total_reserved,
    SUM(s.quantity_available) AS total_available,
    CASE
        WHEN SUM(s.quantity_available) <= 0 THEN 'Out of Stock'
        WHEN SUM(s.quantity_available) <= 10 THEN 'Low Stock'
        ELSE 'In Stock'
    END AS stock_status
FROM sales.products p
LEFT JOIN inventory.stock s ON p.product_id = s.product_id
LEFT JOIN inventory.warehouses w ON s.warehouse_id = w.warehouse_id
GROUP BY p.product_id, p.sku, p.name, p.base_price, w.warehouse_id, w.name;

-- Supplier performance view
CREATE VIEW inventory.supplier_performance AS
SELECT
    s.supplier_id,
    s.company_name,
    s.rating,
    s.lead_time_days,
    COUNT(ps.product_id) AS product_count,
    COALESCE(AVG(ps.unit_cost), 0) AS avg_unit_cost
FROM inventory.suppliers s
LEFT JOIN inventory.product_suppliers ps ON s.supplier_id = ps.supplier_id
WHERE s.is_active = TRUE
GROUP BY s.supplier_id, s.company_name, s.rating, s.lead_time_days;

-- Employee summary view
CREATE VIEW hr.employee_summary AS
SELECT
    e.employee_id,
    e.employee_code,
    e.first_name || ' ' || e.last_name AS full_name,
    e.email,
    e.job_title,
    d.name AS department_name,
    e.hire_date,
    e.salary,
    COUNT(a.attendance_id) AS days_worked
FROM hr.employees e
LEFT JOIN hr.departments d ON e.department_id = d.department_id
LEFT JOIN hr.attendance a ON e.employee_id = a.employee_id
WHERE e.is_active = TRUE
GROUP BY e.employee_id, e.employee_code, e.first_name, e.last_name,
         e.email, e.job_title, d.name, e.hire_date, e.salary;

-- =============================================================================
-- SAMPLE DATA - SALES (Customers: 30, Products: 25)
-- =============================================================================

-- Insert customers
INSERT INTO sales.customers (first_name, last_name, email, phone, role, loyalty_points) VALUES
('John', 'Smith', 'john.smith@email.com', '555-0101', 'customer', 150),
('Jane', 'Doe', 'jane.doe@email.com', '555-0102', 'customer', 320),
('Robert', 'Johnson', 'r.johnson@email.com', '555-0103', 'customer', 80),
('Emily', 'Williams', 'e.williams@email.com', '555-0104', 'admin', 0),
('Michael', 'Brown', 'm.brown@email.com', '555-0105', 'customer', 450),
('Sarah', 'Davis', 's.davis@email.com', '555-0106', 'customer', 200),
('David', 'Miller', 'd.miller@email.com', '555-0107', 'vendor', 0),
('Lisa', 'Wilson', 'l.wilson@email.com', '555-0108', 'customer', 600),
('James', 'Taylor', 'j.taylor@email.com', '555-0109', 'customer', 95),
('Jennifer', 'Anderson', 'j.anderson@email.com', '555-0110', 'customer', 280),
('Christopher', 'Thomas', 'c.thomas@email.com', '555-0111', 'customer', 175),
('Amanda', 'Jackson', 'a.jackson@email.com', '555-0112', 'customer', 520),
('Daniel', 'White', 'd.white@email.com', '555-0113', 'customer', 130),
('Michelle', 'Harris', 'm.harris@email.com', '555-0114', 'moderator', 0),
('Matthew', 'Martin', 'm.martin@email.com', '555-0115', 'customer', 390),
('Stephanie', 'Garcia', 's.garcia@email.com', '555-0116', 'customer', 85),
('Andrew', 'Martinez', 'a.martinez@email.com', '555-0117', 'customer', 220),
('Nicole', 'Robinson', 'n.robinson@email.com', '555-0118', 'customer', 410),
('Joshua', 'Clark', 'j.clark@email.com', '555-0119', 'customer', 160),
('Elizabeth', 'Rodriguez', 'e.rodriguez@email.com', '555-0120', 'customer', 350),
('Ryan', 'Lewis', 'r.lewis@email.com', '555-0121', 'customer', 90),
('Heather', 'Lee', 'h.lee@email.com', '555-0122', 'customer', 480),
('Timothy', 'Walker', 't.walker@email.com', '555-0123', 'customer', 250),
('Tara', 'Hall', 't.hall@email.com', '555-0124', 'customer', 180),
('Brandon', 'Allen', 'b.allen@email.com', '555-0125', 'customer', 420),
('Samantha', 'Young', 's.young@email.com', '555-0126', 'customer', 115),
('Jason', 'King', 'j.king@email.com', '555-0127', 'customer', 560),
('Lauren', 'Wright', 'l.wright@email.com', '555-0128', 'customer', 195),
('Justin', 'Scott', 'j.scott@email.com', '555-0129', 'customer', 330),
('Megan', 'Green', 'm.green@email.com', '555-0130', 'customer', 270);

-- Insert products
INSERT INTO sales.products (sku, name, description, base_price, tax_rate, is_active) VALUES
('SKU-001', 'Wireless Mouse', 'Ergonomic wireless mouse', 29.99, 0.08, true),
('SKU-002', 'Mechanical Keyboard', 'RGB mechanical keyboard', 149.99, 0.08, true),
('SKU-003', 'USB-C Hub', '7-port USB-C hub', 59.99, 0.08, true),
('SKU-004', 'Monitor 27"', '27" 4K monitor', 399.99, 0.08, true),
('SKU-005', 'Webcam HD', '1080p webcam', 79.99, 0.08, true),
('SKU-006', 'Headphones', 'Noise-cancelling headphones', 199.99, 0.08, true),
('SKU-007', 'Desk Lamp', 'LED desk lamp', 34.99, 0.08, true),
('SKU-008', 'Laptop Stand', 'Adjustable laptop stand', 49.99, 0.08, true),
('SKU-009', 'Cable Management Kit', 'Cable organization kit', 24.99, 0.08, true),
('SKU-010', 'Mouse Pad XL', 'Extended mouse pad', 19.99, 0.08, true),
('SKU-011', 'Portable SSD 1TB', '1TB portable SSD', 109.99, 0.08, true),
('SKU-012', 'USB Flash Drive 64GB', '64GB USB flash drive', 14.99, 0.08, true),
('SKU-013', 'Power Strip', '6-outlet power strip', 29.99, 0.08, true),
('SKU-014', 'Wireless Charger', '15W wireless charger', 39.99, 0.08, true),
('SKU-015', 'Phone Stand', 'Adjustable phone stand', 19.99, 0.08, true),
('SKU-016', 'Ethernet Cable 10ft', 'Cat6 ethernet cable', 9.99, 0.08, true),
('SKU-017', 'Screen Cleaner Kit', 'Screen cleaning kit', 12.99, 0.08, true),
('SKU-018', 'Laptop Bag', '15" laptop messenger bag', 69.99, 0.08, true),
('SKU-019', 'Wrist Rest', 'Ergonomic wrist rest', 24.99, 0.08, true),
('SKU-020', 'Keyboard Cover', 'Silicone keyboard cover', 9.99, 0.08, true),
('SKU-021', 'Monitor Arm', 'Single monitor arm', 89.99, 0.08, true),
('SKU-022', 'Webcam Cover', 'Webcam privacy cover', 7.99, 0.08, true),
('SKU-023', 'Desk Organizer', 'Desktop organizer', 44.99, 0.08, true),
('SKU-024', 'Footrest', 'Ergonomic footrest', 34.99, 0.08, true),
('SKU-025', 'Blue Light Glasses', 'Anti-blue light glasses', 29.99, 0.08, true);

-- Insert pricing tiers
INSERT INTO sales.pricing_tiers (product_id, min_quantity, max_quantity, price_multiplier) VALUES
(1, 10, 49, 0.95),
(1, 50, NULL, 0.90),
(2, 5, 9, 0.95),
(2, 10, NULL, 0.88),
(4, 3, 5, 0.97),
(4, 6, NULL, 0.93),
(6, 2, 4, 0.98),
(6, 5, NULL, 0.95);

-- Insert orders (50 orders)
INSERT INTO sales.orders (customer_id, order_number, status, subtotal, tax_amount, shipping_cost, total_amount, ordered_at) VALUES
(1, 'ORD-2025-001', 'delivered', 179.98, 14.40, 9.99, 204.37, '2025-01-01 10:00:00'),
(1, 'ORD-2025-002', 'delivered', 49.99, 4.00, 0, 53.99, '2025-01-05 14:30:00'),
(2, 'ORD-2025-003', 'shipped', 399.99, 32.00, 15.00, 446.99, '2025-01-02 09:15:00'),
(2, 'ORD-2025-004', 'processing', 109.99, 8.80, 7.99, 126.78, '2025-01-08 16:00:00'),
(3, 'ORD-2025-005', 'delivered', 229.97, 18.40, 12.00, 260.37, '2025-01-03 11:45:00'),
(4, 'ORD-2025-006', 'cancelled', 59.99, 4.80, 0, 64.79, '2025-01-04 13:20:00'),
(5, 'ORD-2025-007', 'delivered', 899.97, 72.00, 0, 971.97, '2025-01-06 10:30:00'),
(5, 'ORD-2025-008', 'shipped', 149.99, 12.00, 9.99, 171.98, '2025-01-09 15:00:00'),
(6, 'ORD-2025-009', 'delivered', 79.99, 6.40, 5.99, 92.38, '2025-01-07 12:00:00'),
(7, 'ORD-2025-010', 'pending', 249.99, 20.00, 10.00, 279.99, '2025-01-10 09:00:00'),
(8, 'ORD-2025-011', 'delivered', 599.97, 48.00, 0, 647.97, '2025-01-08 14:00:00'),
(8, 'ORD-2025-012', 'refunded', 89.99, 7.20, 0, 97.19, '2025-01-09 10:30:00'),
(9, 'ORD-2025-013', 'delivered', 129.99, 10.40, 7.99, 148.38, '2025-01-05 16:30:00'),
(10, 'ORD-2025-014', 'shipped', 349.98, 28.00, 12.00, 389.98, '2025-01-10 11:00:00'),
(11, 'ORD-2025-015', 'delivered', 199.99, 16.00, 9.99, 225.98, '2025-01-06 13:45:00'),
(12, 'ORD-2025-016', 'delivered', 439.98, 35.20, 0, 475.18, '2025-01-07 09:30:00'),
(13, 'ORD-2025-017', 'pending', 69.99, 5.60, 5.99, 81.58, '2025-01-10 14:00:00'),
(14, 'ORD-2025-018', 'delivered', 279.98, 22.40, 10.00, 312.38, '2025-01-08 11:15:00'),
(15, 'ORD-2025-019', 'processing', 159.99, 12.80, 8.99, 181.78, '2025-01-10 16:30:00'),
(16, 'ORD-2025-020', 'delivered', 99.99, 8.00, 0, 107.99, '2025-01-04 15:00:00'),
(17, 'ORD-2025-021', 'shipped', 189.99, 15.20, 9.99, 215.18, '2025-01-09 08:30:00'),
(18, 'ORD-2025-022', 'delivered', 749.97, 60.00, 0, 809.97, '2025-01-05 12:00:00'),
(19, 'ORD-2025-023', 'pending', 119.99, 9.60, 7.99, 137.58, '2025-01-10 10:00:00'),
(20, 'ORD-2025-024', 'delivered', 329.98, 26.40, 12.00, 368.38, '2025-01-07 14:30:00'),
(21, 'ORD-2025-025', 'delivered', 89.99, 7.20, 0, 97.19, '2025-01-06 10:00:00'),
(22, 'ORD-2025-026', 'refunded', 199.99, 16.00, 0, 215.99, '2025-01-08 16:00:00'),
(23, 'ORD-2025-027', 'delivered', 259.98, 20.80, 10.00, 290.78, '2025-01-09 12:30:00'),
(24, 'ORD-2025-028', 'shipped', 149.99, 12.00, 9.99, 171.98, '2025-01-10 09:30:00'),
(25, 'ORD-2025-029', 'delivered', 549.97, 44.00, 0, 593.97, '2025-01-05 11:00:00'),
(26, 'ORD-2025-030', 'pending', 79.99, 6.40, 5.99, 92.38, '2025-01-10 15:00:00'),
(27, 'ORD-2025-031', 'delivered', 399.99, 32.00, 15.00, 446.99, '2025-01-04 13:00:00'),
(28, 'ORD-2025-032', 'processing', 129.99, 10.40, 7.99, 148.38, '2025-01-10 08:00:00'),
(29, 'ORD-2025-033', 'delivered', 229.97, 18.40, 12.00, 260.37, '2025-01-07 16:00:00'),
(30, 'ORD-2025-034', 'delivered', 179.98, 14.40, 9.99, 204.37, '2025-01-06 09:00:00'),
(1, 'ORD-2025-035', 'delivered', 89.99, 7.20, 0, 97.19, '2025-01-09 14:00:00'),
(2, 'ORD-2025-036', 'shipped', 249.99, 20.00, 10.00, 279.99, '2025-01-10 12:00:00'),
(3, 'ORD-2025-037', 'delivered', 159.99, 12.80, 8.99, 181.78, '2025-01-08 10:30:00'),
(4, 'ORD-2025-038', 'pending', 99.99, 8.00, 0, 107.99, '2025-01-10 17:00:00'),
(5, 'ORD-2025-039', 'delivered', 699.97, 56.00, 0, 755.97, '2025-01-05 15:30:00'),
(6, 'ORD-2025-040', 'delivered', 119.99, 9.60, 7.99, 137.58, '2025-01-09 11:00:00'),
(7, 'ORD-2025-041', 'processing', 189.99, 15.20, 9.99, 215.18, '2025-01-10 13:00:00'),
(8, 'ORD-2025-042', 'shipped', 299.98, 24.00, 12.00, 335.98, '2025-01-07 10:00:00'),
(9, 'ORD-2025-043', 'delivered', 449.97, 36.00, 0, 485.97, '2025-01-06 14:00:00'),
(10, 'ORD-2025-044', 'delivered', 169.99, 13.60, 9.99, 193.58, '2025-01-08 15:00:00'),
(11, 'ORD-2025-045', 'pending', 89.99, 7.20, 0, 97.19, '2025-01-10 11:30:00'),
(12, 'ORD-2025-046', 'delivered', 329.98, 26.40, 10.00, 366.38, '2025-01-05 09:00:00'),
(13, 'ORD-2025-047', 'delivered', 199.99, 16.00, 9.99, 225.98, '2025-01-09 16:00:00'),
(14, 'ORD-2025-048', 'shipped', 279.98, 22.40, 12.00, 314.38, '2025-01-10 10:30:00'),
(15, 'ORD-2025-049', 'delivered', 139.99, 11.20, 7.99, 159.18, '2025-01-07 11:00:00'),
(16, 'ORD-2025-050', 'delivered', 259.98, 20.80, 10.00, 290.78, '2025-01-08 12:00:00');

-- Update order timestamps
UPDATE sales.orders SET confirmed_at = ordered_at + INTERVAL '1 hour' WHERE status NOT IN ('pending', 'cancelled');
UPDATE sales.orders SET shipped_at = confirmed_at + INTERVAL '2 hours' WHERE status IN ('shipped', 'delivered');
UPDATE sales.orders SET delivered_at = shipped_at + INTERVAL '3 days' WHERE status = 'delivered';

-- Insert order items (approx 80 items)
INSERT INTO sales.order_items (order_id, product_id, quantity, unit_price, discount_percent, total_price) VALUES
(1, 1, 2, 29.99, 0, 59.98), (1, 2, 1, 149.99, 0, 149.99),
(2, 3, 1, 59.99, 0, 59.99),
(3, 4, 1, 399.99, 0, 399.99),
(4, 11, 1, 109.99, 0, 109.99),
(5, 1, 3, 29.99, 5, 85.47), (5, 6, 1, 199.99, 0, 199.99),
(6, 7, 1, 34.99, 0, 34.99), (6, 8, 1, 49.99, 0, 49.99),
(7, 2, 3, 149.99, 10, 404.97), (7, 5, 2, 79.99, 0, 159.98),
(8, 6, 1, 199.99, 0, 199.99),
(9, 12, 2, 14.99, 0, 29.98), (9, 16, 5, 9.99, 0, 49.95),
(10, 10, 2, 19.99, 0, 39.98), (10, 17, 2, 12.99, 0, 25.98),
(11, 4, 2, 399.99, 0, 799.98),
(12, 18, 1, 69.99, 0, 69.99),
(13, 1, 1, 29.99, 0, 29.99), (13, 2, 1, 149.99, 0, 149.99),
(14, 4, 1, 399.99, 0, 399.99), (14, 21, 1, 89.99, 0, 89.99),
(15, 6, 1, 199.99, 0, 199.99),
(16, 4, 1, 399.99, 0, 399.99), (16, 23, 1, 44.99, 0, 44.99),
(17, 19, 2, 24.99, 0, 49.98), (17, 25, 1, 29.99, 0, 29.99),
(18, 2, 2, 149.99, 0, 299.98),
(19, 1, 5, 29.99, 5, 142.45), (19, 22, 2, 7.99, 0, 15.98),
(20, 3, 1, 59.99, 0, 59.99), (20, 13, 1, 29.99, 0, 29.99),
(21, 6, 1, 199.99, 0, 199.99),
(22, 4, 1, 399.99, 0, 399.99), (22, 2, 1, 149.99, 0, 149.99), (22, 5, 2, 79.99, 0, 159.98),
(23, 14, 3, 39.99, 0, 119.97),
(24, 4, 1, 399.99, 0, 399.99), (24, 15, 1, 19.99, 0, 19.99),
(25, 1, 3, 29.99, 0, 89.97),
(26, 6, 1, 199.99, 0, 199.99),
(27, 4, 1, 399.99, 0, 399.99), (27, 24, 1, 34.99, 0, 34.99),
(28, 2, 1, 149.99, 0, 149.99),
(29, 4, 1, 399.99, 0, 399.99), (29, 1, 5, 29.99, 0, 149.95),
(30, 3, 1, 59.99, 0, 59.99), (30, 16, 2, 9.99, 0, 19.98),
(31, 4, 1, 399.99, 0, 399.99),
(32, 11, 1, 109.99, 0, 109.99), (32, 20, 4, 9.99, 0, 39.96),
(33, 2, 1, 149.99, 0, 149.99), (33, 8, 1, 49.99, 0, 49.99),
(34, 1, 2, 29.99, 0, 59.98), (34, 7, 1, 34.99, 0, 34.99), (34, 12, 3, 14.99, 0, 44.97),
(35, 13, 3, 29.99, 0, 89.97),
(36, 4, 1, 399.99, 0, 399.99), (36, 17, 1, 12.99, 0, 12.99),
(37, 1, 2, 29.99, 0, 59.98), (37, 2, 1, 149.99, 0, 149.99),
(38, 14, 2, 39.99, 0, 79.98),
(39, 4, 1, 399.99, 0, 399.99), (39, 6, 1, 199.99, 0, 199.99), (39, 18, 1, 69.99, 0, 69.99),
(40, 3, 2, 59.99, 0, 119.98),
(41, 6, 1, 199.99, 0, 199.99),
(42, 4, 1, 399.99, 0, 399.99), (42, 21, 1, 89.99, 0, 89.99),
(43, 4, 1, 399.99, 0, 399.99), (43, 5, 1, 79.99, 0, 79.99), (43, 25, 1, 29.99, 0, 29.99),
(44, 1, 3, 29.99, 0, 89.97), (44, 19, 3, 24.99, 0, 74.97),
(45, 22, 5, 7.99, 0, 39.95), (45, 20, 5, 9.99, 0, 49.95),
(46, 2, 2, 149.99, 0, 299.98), (46, 23, 1, 44.99, 0, 44.99),
(47, 6, 1, 199.99, 0, 199.99),
(48, 4, 1, 399.99, 0, 399.99), (48, 11, 1, 109.99, 0, 109.99),
(49, 1, 2, 29.99, 0, 59.98), (49, 16, 4, 9.99, 0, 39.96), (49, 17, 3, 12.99, 0, 38.97),
(50, 2, 1, 149.99, 0, 149.99), (50, 24, 2, 34.99, 0, 69.98), (50, 25, 1, 29.99, 0, 29.99);

-- Insert discounts
INSERT INTO sales.discounts (code, description, discount_type, discount_value, min_order_amount, max_discount_amount, usage_limit, valid_from, valid_until, is_active) VALUES
('SAVE10', '10% off orders over $100', 'percentage', 10, 100, 50, 1000, '2025-01-01', '2025-12-31', true),
('SAVE20', '20% off orders over $300', 'percentage', 20, 300, 100, 500, '2025-01-01', '2025-12-31', true),
('FLAT50', '$50 off orders over $200', 'fixed', 50, 200, 50, 200, '2025-01-01', '2025-06-30', true),
('FIRST20', '20% off first order', 'percentage', 20, 0, 100, NULL, '2025-01-01', '2025-12-31', true),
('FREE Shipping', 'Free shipping on orders over $50', 'shipping', 0, 50, 10, NULL, '2025-01-01', '2025-12-31', true);

-- =============================================================================
-- SAMPLE DATA - INVENTORY (Warehouses: 3, Suppliers: 10)
-- =============================================================================

-- Insert warehouses
INSERT INTO inventory.warehouses (name, location, capacity_cubic_feet, is_active) VALUES
('East Coast DC', ROW('123 Industrial Blvd', 'Newark', 'NJ', '07102', 'USA'), 50000, true),
('West Coast DC', ROW('456 Commerce Way', 'Los Angeles', 'CA', '90001', 'USA'), 75000, true),
('Central DC', ROW('789 Distribution Ave', 'Chicago', 'IL', '60601', 'USA'), 60000, true);

-- Insert locations
INSERT INTO inventory.locations (warehouse_id, zone, aisle, rack, shelf, bin, location_code) VALUES
(1, 'A', 1, 1, 1, '01', 'E-A01-R01-S01-B01'),
(1, 'A', 1, 1, 1, '02', 'E-A01-R01-S01-B02'),
(1, 'A', 1, 1, 2, '01', 'E-A01-R01-S02-B01'),
(1, 'A', 1, 2, 1, '01', 'E-A01-R02-S01-B01'),
(1, 'B', 2, 1, 1, '01', 'E-B02-R01-S01-B01'),
(2, 'A', 1, 1, 1, '01', 'W-A01-R01-S01-B01'),
(2, 'A', 1, 1, 2, '01', 'W-A01-R01-S02-B01'),
(2, 'A', 2, 1, 1, '01', 'W-A02-R01-S01-B01'),
(2, 'B', 1, 1, 1, '01', 'W-B01-R01-S01-B01'),
(3, 'A', 1, 1, 1, '01', 'C-A01-R01-S01-B01'),
(3, 'A', 1, 1, 2, '01', 'C-A01-R01-S02-B01'),
(3, 'B', 1, 1, 1, '01', 'C-B01-R01-S01-B01');

-- Insert suppliers
INSERT INTO inventory.suppliers (company_name, contact_name, email, phone, address, lead_time_days, rating) VALUES
('TechSupply Co', 'John Tech', 'john@techsupply.com', '555-1001', ROW('100 Supply St', 'Shenzhen', 'GD', '518000', 'China'), 14, 4.5),
('GlobalParts Inc', 'Mary Global', 'mary@globalparts.com', '555-1002', ROW('200 Parts Ave', 'Shanghai', 'SH', '200000', 'China'), 21, 4.2),
('FastShip Electronics', 'Tom Fast', 'tom@fastship.com', '555-1003', ROW('300 Ship Rd', 'Shenzhen', 'GD', '518000', 'China'), 7, 4.8),
('Quality Components', 'Sarah Quality', 'sarah@qualitycomp.com', '555-1004', ROW('400 Quality Ln', 'Beijing', 'BJ', '100000', 'China'), 30, 4.0),
('Budget Wholesale', 'Mike Budget', 'mike@budgetwholesale.com', '555-1005', ROW('500 Budget Blvd', 'Guangzhou', 'GD', '510000', 'China'), 14, 3.8),
('Premium Parts Ltd', 'Lisa Premium', 'lisa@premiumparts.com', '555-1006', ROW('600 Premium Ave', 'Shanghai', 'SH', '200000', 'China'), 10, 4.7),
('Direct Factory', 'Wang Factory', 'wang@directfactory.com', '555-1007', ROW('700 Factory Rd', 'Dongguan', 'GD', '523000', 'China'), 35, 4.3),
('Express Supply', 'Jane Express', 'jane@expresssupply.com', '555-1008', ROW('800 Express Way', 'Hangzhou', 'ZJ', '310000', 'China'), 5, 4.6),
('Mega Distribution', 'Bob Mega', 'bob@megadist.com', '555-1009', ROW('900 Mega Blvd', 'Suzhou', 'JS', '215000', 'China'), 12, 4.1),
('Smart Sourcing', 'Amy Smart', 'amy@smartsourcing.com', '555-1010', ROW('1000 Smart St', 'Ningbo', 'ZJ', '315000', 'China'), 18, 4.4);

-- Insert stock
INSERT INTO inventory.stock (product_id, warehouse_id, location_id, quantity_on_hand, quantity_reserved, reorder_point) VALUES
(1, 1, 1, 500, 50, 100), (1, 2, 6, 300, 30, 100),
(2, 1, 2, 200, 20, 50), (2, 3, 10, 150, 15, 50),
(3, 1, 3, 400, 40, 100),
(4, 1, 4, 50, 5, 20), (4, 2, 7, 30, 3, 20),
(5, 2, 8, 250, 25, 50),
(6, 1, 5, 100, 10, 30), (6, 3, 11, 80, 8, 30),
(7, 2, 9, 300, 30, 50),
(8, 1, 1, 200, 20, 50), (8, 3, 10, 150, 15, 50),
(9, 2, 6, 400, 40, 100),
(10, 1, 2, 500, 50, 100), (10, 2, 7, 350, 35, 100),
(11, 1, 3, 150, 15, 50), (11, 3, 11, 100, 10, 50),
(12, 1, 4, 800, 80, 200),
(13, 2, 8, 300, 30, 100),
(14, 1, 5, 400, 40, 100), (14, 3, 12, 250, 25, 100),
(15, 2, 9, 500, 50, 100),
(16, 1, 1, 1000, 100, 200), (16, 2, 6, 800, 80, 200),
(17, 3, 10, 600, 60, 150),
(18, 1, 2, 150, 15, 50), (18, 2, 7, 100, 10, 50),
(19, 2, 8, 300, 30, 100),
(20, 1, 3, 500, 50, 100), (20, 3, 11, 400, 40, 100),
(21, 1, 4, 80, 8, 20), (21, 2, 9, 60, 6, 20),
(22, 3, 12, 2000, 200, 500),
(23, 1, 5, 200, 20, 50),
(24, 2, 6, 250, 25, 50),
(25, 1, 1, 300, 30, 100), (1, 3, 12, 200, 20, 50);

-- Insert product suppliers
INSERT INTO inventory.product_suppliers (product_id, supplier_id, is_primary, lead_time_days, unit_cost, min_order_quantity) VALUES
(1, 1, true, 14, 15.00, 100),
(1, 3, false, 7, 14.50, 200),
(2, 2, true, 21, 95.00, 50),
(3, 1, true, 14, 35.00, 50),
(4, 3, true, 7, 280.00, 20),
(5, 6, true, 10, 50.00, 30),
(6, 2, true, 21, 140.00, 20),
(7, 5, true, 14, 20.00, 100),
(8, 4, true, 30, 32.00, 50),
(9, 5, true, 14, 15.00, 100),
(10, 1, true, 14, 12.00, 200),
(11, 7, true, 35, 75.00, 30),
(12, 8, true, 5, 8.00, 500),
(13, 9, true, 12, 18.00, 100),
(14, 3, true, 7, 25.00, 100),
(15, 10, true, 18, 12.00, 200),
(16, 8, true, 5, 5.00, 1000),
(17, 5, true, 14, 7.00, 500),
(18, 6, true, 10, 45.00, 50),
(19, 1, true, 14, 15.00, 100),
(20, 9, true, 12, 5.50, 500),
(21, 2, true, 21, 60.00, 20),
(22, 8, true, 5, 4.00, 1000),
(23, 4, true, 30, 28.00, 50),
(24, 10, true, 18, 22.00, 50),
(25, 3, true, 7, 18.00, 100);

-- =============================================================================
-- SAMPLE DATA - HR (Departments: 5, Employees: 20)
-- =============================================================================

-- Insert departments
INSERT INTO hr.departments (name, code, parent_department_id, budget, manager_id) VALUES
('Corporate', 'CORP', NULL, 5000000, NULL),
('Sales', 'SALES', 1, 1500000, NULL),
('Marketing', 'MKT', 1, 800000, NULL),
('Engineering', 'ENG', 1, 2000000, NULL),
('Human Resources', 'HR', 1, 400000, NULL);

-- Insert employees
INSERT INTO hr.employees (employee_code, first_name, last_name, email, phone, department_id, job_title, hire_date, salary, commission_rate) VALUES
('EMP001', 'Alice', 'Johnson', 'alice.johnson@company.com', '555-2001', 1, 'CEO', '2020-01-15', 250000, 0),
('EMP002', 'Bob', 'Williams', 'bob.williams@company.com', '555-2002', 2, 'Sales Director', '2020-03-01', 150000, 0.05),
('EMP003', 'Carol', 'Brown', 'carol.brown@company.com', '555-2003', 3, 'Marketing Director', '2020-02-15', 130000, 0),
('EMP004', 'Dan', 'Martinez', 'dan.martinez@company.com', '555-2004', 4, 'Engineering Director', '2019-11-01', 180000, 0),
('EMP005', 'Eve', 'Davis', 'eve.davis@company.com', '555-2005', 5, 'HR Director', '2020-05-01', 120000, 0),
('EMP006', 'Frank', 'Garcia', 'frank.garcia@company.com', '555-2006', 2, 'Senior Sales Rep', '2021-01-15', 80000, 0.08),
('EMP007', 'Grace', 'Miller', 'grace.miller@company.com', '555-2007', 2, 'Sales Rep', '2021-06-01', 65000, 0.10),
('EMP008', 'Henry', 'Rodriguez', 'henry.rodriguez@company.com', '555-2008', 2, 'Sales Rep', '2022-01-10', 60000, 0.10),
('EMP009', 'Ivy', 'Wilson', 'ivy.wilson@company.com', '555-2009', 3, 'Marketing Specialist', '2021-08-15', 70000, 0),
('EMP010', 'Jack', 'Anderson', 'jack.anderson@company.com', '555-2010', 3, 'Content Writer', '2022-03-01', 55000, 0),
('EMP011', 'Kate', 'Taylor', 'kate.taylor@company.com', '555-2011', 4, 'Senior Engineer', '2020-09-01', 140000, 0),
('EMP012', 'Leo', 'Thomas', 'leo.thomas@company.com', '555-2012', 4, 'Engineer', '2021-04-15', 110000, 0),
('EMP013', 'Mia', 'Jackson', 'mia.jackson@company.com', '555-2013', 4, 'Engineer', '2022-02-01', 95000, 0),
('EMP014', 'Noah', 'White', 'noah.white@company.com', '555-2014', 4, 'Junior Engineer', '2023-01-15', 75000, 0),
('EMP015', 'Olivia', 'Harris', 'olivia.harris@company.com', '555-2015', 4, 'QA Engineer', '2022-05-01', 85000, 0),
('EMP016', 'Peter', 'Martin', 'peter.martin@company.com', '555-2016', 5, 'HR Specialist', '2021-10-01', 60000, 0),
('EMP017', 'Quinn', 'Thompson', 'quinn.thompson@company.com', '555-2017', 5, 'Recruiter', '2022-08-15', 55000, 0),
('EMP018', 'Rachel', 'Lee', 'rachel.lee@company.com', '555-2018', 3, 'SEO Specialist', '2022-06-01', 65000, 0),
('EMP019', 'Sam', 'Walker', 'sam.walker@company.com', '555-2019', 2, 'Account Manager', '2021-09-01', 75000, 0.06),
('EMP020', 'Tina', 'Hall', 'tina.hall@company.com', '555-2020', 4, 'DevOps Engineer', '2021-12-01', 120000, 0);

-- Update department managers
UPDATE hr.departments SET manager_id = 1 WHERE department_id = 1;
UPDATE hr.departments SET manager_id = 2 WHERE department_id = 2;
UPDATE hr.departments SET manager_id = 3 WHERE department_id = 3;
UPDATE hr.departments SET manager_id = 4 WHERE department_id = 4;
UPDATE hr.departments SET manager_id = 5 WHERE department_id = 5;

-- Insert attendance (last 20 days for each employee)
INSERT INTO hr.attendance (employee_id, date, check_in, check_out, hours_worked, overtime_hours)
SELECT
    e.employee_id,
    CURRENT_DATE - (n || ' days')::INTERVAL,
    '09:00'::TIME + (random() * 15 || ' minutes')::INTERVAL,
    '18:00'::TIME + (random() * 30 || ' minutes')::INTERVAL,
    8 + random() * 1,
    CASE WHEN random() > 0.8 THEN random() * 2 ELSE 0 END
FROM hr.employees e
CROSS JOIN generate_series(0, 19) AS n;

-- Insert salary history
INSERT INTO hr.salary_history (employee_id, salary, effective_date, reason) VALUES
(1, 250000, '2024-01-01', 'Annual review'),
(2, 150000, '2024-01-01', 'Promotion'),
(3, 130000, '2024-03-01', 'New hire adjustment'),
(4, 180000, '2024-01-01', 'Annual review'),
(5, 120000, '2024-06-01', 'Promotion'),
(6, 75000, '2024-01-01', 'New hire'), (6, 80000, '2024-07-01', 'Promotion'),
(7, 60000, '2024-01-01', 'New hire'), (7, 65000, '2024-09-01', 'Performance'),
(11, 140000, '2024-01-01', 'Annual review'),
(12, 100000, '2024-01-01', 'New hire'), (12, 110000, '2024-07-01', 'Promotion'),
(20, 120000, '2024-01-01', 'Annual review');

-- =============================================================================
-- SAMPLE DATA - PAYMENTS (30 payments)
-- =============================================================================

INSERT INTO sales.payments (order_id, payment_method, amount, payment_status, transaction_id, paid_at) VALUES
(1, 'credit_card', 204.37, 'completed', 'TXN-001', '2025-01-01 10:05:00'),
(2, 'paypal', 53.99, 'completed', 'TXN-002', '2025-01-05 14:35:00'),
(3, 'credit_card', 446.99, 'completed', 'TXN-003', '2025-01-02 09:20:00'),
(5, 'credit_card', 260.37, 'completed', 'TXN-004', '2025-01-03 11:50:00'),
(7, 'bank_transfer', 971.97, 'completed', 'TXN-005', '2025-01-06 10:35:00'),
(8, 'credit_card', 171.98, 'completed', 'TXN-006', '2025-01-09 15:05:00'),
(9, 'paypal', 92.38, 'completed', 'TXN-007', '2025-01-07 12:05:00'),
(11, 'credit_card', 647.97, 'completed', 'TXN-008', '2025-01-08 14:05:00'),
(13, 'credit_card', 148.38, 'completed', 'TXN-009', '2025-01-05 16:35:00'),
(15, 'credit_card', 225.98, 'completed', 'TXN-010', '2025-01-06 13:50:00'),
(16, 'paypal', 475.18, 'completed', 'TXN-011', '2025-01-07 09:35:00'),
(18, 'credit_card', 312.38, 'completed', 'TXN-012', '2025-01-08 11:20:00'),
(20, 'bank_transfer', 107.99, 'completed', 'TXN-013', '2025-01-04 15:05:00'),
(22, 'credit_card', 809.97, 'completed', 'TXN-014', '2025-01-08 14:05:00'),
(23, 'credit_card', 137.58, 'completed', 'TXN-015', '2025-01-10 14:05:00'),
(24, 'paypal', 368.38, 'completed', 'TXN-016', '2025-01-07 14:35:00'),
(25, 'credit_card', 97.19, 'completed', 'TXN-017', '2025-01-06 10:05:00'),
(27, 'credit_card', 290.78, 'completed', 'TXN-018', '2025-01-09 12:35:00'),
(29, 'credit_card', 593.97, 'completed', 'TXN-019', '2025-01-05 11:05:00'),
(31, 'paypal', 446.99, 'completed', 'TXN-020', '2025-01-04 13:10:00'),
(33, 'credit_card', 260.37, 'completed', 'TXN-021', '2025-01-07 16:05:00'),
(35, 'credit_card', 97.19, 'completed', 'TXN-022', '2025-01-09 14:10:00'),
(39, 'bank_transfer', 755.97, 'completed', 'TXN-023', '2025-01-05 15:35:00'),
(40, 'credit_card', 137.58, 'completed', 'TXN-024', '2025-01-09 11:10:00'),
(43, 'credit_card', 485.97, 'completed', 'TXN-025', '2025-01-06 14:05:00'),
(44, 'paypal', 193.58, 'completed', 'TXN-026', '2025-01-08 15:10:00'),
(46, 'credit_card', 366.38, 'completed', 'TXN-027', '2025-01-05 09:05:00'),
(47, 'credit_card', 225.98, 'completed', 'TXN-028', '2025-01-09 16:10:00'),
(49, 'bank_transfer', 159.18, 'completed', 'TXN-029', '2025-01-07 11:15:00'),
(50, 'credit_card', 290.78, 'completed', 'TXN-030', '2025-01-08 12:10:00');

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- SELECT 'Database db_pg_mcp_medium created successfully!' AS status;
-- SELECT table_schema, COUNT(*) FROM information_schema.tables GROUP BY table_schema ORDER BY table_schema;
