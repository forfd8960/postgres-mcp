-- =============================================================================
-- pg-mcp Large Test Database
-- Purpose: Testing large schema discovery, complex queries, performance
-- Tables: 55+ | Views: 12 | Types: 8 | Indexes: 100+ | Triggers: 8
-- =============================================================================

-- This file should be loaded into an existing database.
-- Use Makefile to create and populate the database:
--   make setup-large

-- =============================================================================
-- TYPE DEFINITIONS (8 types)
-- =============================================================================

-- Enums
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded', 'disputed');
CREATE TYPE payment_method AS ENUM ('credit_card', 'debit_card', 'paypal', 'bank_transfer', 'apple_pay', 'google_pay');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'pending_verification');
CREATE TYPE user_role AS ENUM ('customer', 'vendor', 'admin', 'super_admin', 'affiliate');
CREATE TYPE product_status AS ENUM ('draft', 'active', 'inactive', 'discontinued', 'out_of_stock');
CREATE TYPE shipping_status AS ENUM ('label_created', 'in_transit', 'out_for_delivery', 'delivered', 'returned', 'exception');
CREATE TYPE refund_status AS ENUM ('requested', 'approved', 'rejected', 'processed', 'completed');

-- Composite types
CREATE TYPE contact_info AS (
    phone VARCHAR(20),
    email VARCHAR(100),
    website VARCHAR(200)
);

CREATE TYPE inventory_level AS (
    total_on_hand INTEGER,
    total_reserved INTEGER,
    total_available INTEGER,
    reorder_needed BOOLEAN
);

CREATE TYPE financial_summary AS (
    total_revenue DECIMAL(15, 2),
    total_costs DECIMAL(15, 2),
    gross_profit DECIMAL(15, 2),
    net_profit DECIMAL(15, 2)
);

-- Domain types
CREATE DOMAIN positive_int AS INTEGER CHECK (VALUE > 0);
CREATE DOMAIN positive_decimal AS DECIMAL(10, 2) CHECK (VALUE >= 0);
CREATE DOMAIN email_address AS VARCHAR(100) CHECK (VALUE ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

-- =============================================================================
-- SCHEMAS (10 schemas)
-- =============================================================================

CREATE SCHEMA accounts;
CREATE SCHEMA catalog;
CREATE SCHEMA inventory;
CREATE SCHEMA orders;
CREATE SCHEMA payments;
CREATE SCHEMA shipping;
CREATE SCHEMA marketing;
CREATE SCHEMA analytics;
CREATE SCHEMA logistics;
CREATE SCHEMA support;

-- =============================================================================
-- TABLES - ACCOUNTS SCHEMA (8 tables)
-- =============================================================================

-- Users table
CREATE TABLE accounts.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email email_address NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    phone VARCHAR(20),
    status user_status DEFAULT 'pending_verification',
    role user_role DEFAULT 'customer',
    profile_image_url VARCHAR(500),
    timezone VARCHAR(50) DEFAULT 'UTC',
    language VARCHAR(10) DEFAULT 'en',
    email_verified BOOLEAN DEFAULT FALSE,
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

-- User profiles
CREATE TABLE accounts.profiles (
    profile_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES accounts.users(user_id) ON DELETE CASCADE,
    date_of_birth DATE,
    gender VARCHAR(20),
    bio TEXT,
    company VARCHAR(100),
    job_title VARCHAR(100),
    social_links JSONB DEFAULT '{}',
    preferences JSONB DEFAULT '{"notifications": true, "newsletter": true}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User addresses
CREATE TABLE accounts.addresses (
    address_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id) ON DELETE CASCADE,
    address_type VARCHAR(20) DEFAULT 'shipping',
    is_default BOOLEAN DEFAULT FALSE,
    recipient_name VARCHAR(100),
    street_address VARCHAR(255) NOT NULL,
    apartment_unit VARCHAR(50),
    city VARCHAR(100) NOT NULL,
    state_province VARCHAR(100),
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(100) NOT NULL,
    delivery_instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User preferences
CREATE TABLE accounts.user_preferences (
    preference_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES accounts.users(user_id) ON DELETE CASCADE,
    currency VARCHAR(3) DEFAULT 'USD',
    measurement_unit VARCHAR(10) DEFAULT 'metric',
    date_format VARCHAR(20) DEFAULT 'YYYY-MM-DD',
    communication_channel VARCHAR(20) DEFAULT 'email',
    marketing_opt_in BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User sessions
CREATE TABLE accounts.sessions (
    session_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    ip_address INET,
    user_agent TEXT,
    device_type VARCHAR(20),
    location VARCHAR(100),
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Authentication logs
CREATE TABLE accounts.auth_logs (
    log_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES accounts.users(user_id),
    action VARCHAR(50) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User verification
CREATE TABLE accounts.verifications (
    verification_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id) ON DELETE CASCADE,
    verification_type VARCHAR(50) NOT NULL,
    verification_token VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    verified_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'pending',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Wishlists
CREATE TABLE accounts.wishlists (
    wishlist_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL DEFAULT 'My Wishlist',
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, name)
);

-- Wishlist items
CREATE TABLE accounts.wishlist_items (
    item_id SERIAL PRIMARY KEY,
    wishlist_id INTEGER NOT NULL REFERENCES accounts.wishlists(wishlist_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    priority INTEGER DEFAULT 0,
    UNIQUE(wishlist_id, product_id)
);

-- =============================================================================
-- TABLES - CATALOG SCHEMA (10 tables)
-- =============================================================================

-- Categories
CREATE TABLE catalog.categories (
    category_id SERIAL PRIMARY KEY,
    parent_id INTEGER REFERENCES catalog.categories(category_id),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    image_url VARCHAR(500),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    meta_title VARCHAR(200),
    meta_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Brands
CREATE TABLE catalog.brands (
    brand_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    logo_url VARCHAR(500),
    website VARCHAR(200),
    contact_info contact_info,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products
CREATE TABLE catalog.products (
    product_id SERIAL PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) NOT NULL UNIQUE,
    description TEXT,
    short_description TEXT,
    brand_id INTEGER REFERENCES catalog.brands(brand_id),
    base_price positive_decimal NOT NULL,
    cost_price positive_decimal,
    tax_class VARCHAR(20) DEFAULT 'standard',
    status product_status DEFAULT 'draft',
    requires_shipping BOOLEAN DEFAULT TRUE,
    weight DECIMAL(8, 3),
    length DECIMAL(8, 2),
    width DECIMAL(8, 2),
    height DECIMAL(8, 2),
    meta_title VARCHAR(200),
    meta_description TEXT,
    average_rating DECIMAL(3, 2) DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    sale_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMP,
    deleted_at TIMESTAMP
);

-- Product categories (many-to-many)
CREATE TABLE catalog.product_categories (
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES catalog.categories(category_id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id, category_id)
);

-- Product attributes
CREATE TABLE catalog.attributes (
    attribute_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    type VARCHAR(20) NOT NULL DEFAULT 'text',
    is_filterable BOOLEAN DEFAULT FALSE,
    is_required BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product attribute values
CREATE TABLE catalog.attribute_values (
    value_id SERIAL PRIMARY KEY,
    attribute_id INTEGER NOT NULL REFERENCES catalog.attributes(attribute_id) ON DELETE CASCADE,
    value VARCHAR(200) NOT NULL,
    slug VARCHAR(200) NOT NULL,
    display_value VARCHAR(200),
    color_hex VARCHAR(7),
    image_url VARCHAR(500),
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(attribute_id, value)
);

-- Product variant attributes
CREATE TABLE catalog.product_variant_attrs (
    variant_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    sku VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    price positive_decimal NOT NULL,
    cost_price positive_decimal,
    stock_quantity INTEGER DEFAULT 0,
    weight DECIMAL(8, 3),
    is_available BOOLEAN DEFAULT TRUE,
    image_urls TEXT[] DEFAULT '{}',
    attributes JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product images
CREATE TABLE catalog.product_images (
    image_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    alt_text VARCHAR(200),
    is_primary BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product tags
CREATE TABLE catalog.tags (
    tag_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    slug VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product tag relationships
CREATE TABLE catalog.product_tags (
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    tag_id INTEGER NOT NULL REFERENCES catalog.tags(tag_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id, tag_id)
);

-- Product reviews
CREATE TABLE catalog.reviews (
    review_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id) ON DELETE CASCADE,
    order_id INTEGER,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title VARCHAR(200),
    content TEXT NOT NULL,
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    is_approved BOOLEAN DEFAULT FALSE,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, user_id, order_id)
);

-- =============================================================================
-- TABLES - INVENTORY SCHEMA (8 tables)
-- =============================================================================

-- Warehouses
CREATE TABLE inventory.warehouses (
    warehouse_id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(100) NOT NULL,
    contact_name VARCHAR(100),
    contact_phone VARCHAR(20),
    contact_email email_address,
    capacity_cubic_feet INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory locations
CREATE TABLE inventory.locations (
    location_id SERIAL PRIMARY KEY,
    warehouse_id INTEGER NOT NULL REFERENCES inventory.warehouses(warehouse_id) ON DELETE CASCADE,
    zone CHAR(1) NOT NULL,
    aisle INTEGER NOT NULL,
    rack INTEGER NOT NULL,
    shelf INTEGER NOT NULL,
    bin VARCHAR(10),
    location_code VARCHAR(50) NOT NULL UNIQUE,
    location_type VARCHAR(20) DEFAULT 'standard',
    picking_priority INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(warehouse_id, zone, aisle, rack, shelf, bin)
);

-- Inventory items
CREATE TABLE inventory.items (
    item_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id),
    warehouse_id INTEGER NOT NULL REFERENCES inventory.warehouses(warehouse_id),
    location_id INTEGER REFERENCES inventory.locations(location_id),
    quantity_on_hand INTEGER DEFAULT 0,
    quantity_reserved INTEGER DEFAULT 0,
    quantity_available INTEGER GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved) STORED,
    quantity_on_order INTEGER DEFAULT 0,
    reorder_point INTEGER DEFAULT 10,
    reorder_quantity INTEGER DEFAULT 50,
    last_counted_at TIMESTAMP,
    last_restocked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, warehouse_id)
);

-- Inventory adjustments
CREATE TABLE inventory.adjustments (
    adjustment_id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES inventory.items(item_id) ON DELETE CASCADE,
    adjustment_type VARCHAR(20) NOT NULL,
    quantity_change INTEGER NOT NULL,
    reason VARCHAR(100),
    reference_type VARCHAR(50),
    reference_id VARCHAR(100),
    performed_by INTEGER REFERENCES accounts.users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory transfers
CREATE TABLE inventory.transfers (
    transfer_id SERIAL PRIMARY KEY,
    from_warehouse_id INTEGER NOT NULL REFERENCES inventory.warehouses(warehouse_id),
    to_warehouse_id INTEGER NOT NULL REFERENCES inventory.warehouses(warehouse_id),
    status VARCHAR(20) DEFAULT 'pending',
    initiated_by INTEGER REFERENCES accounts.users(user_id),
    approved_by INTEGER REFERENCES accounts.users(user_id),
    shipped_at TIMESTAMP,
    received_at TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transfer items
CREATE TABLE inventory.transfer_items (
    transfer_item_id SERIAL PRIMARY KEY,
    transfer_id INTEGER NOT NULL REFERENCES inventory.transfers(transfer_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id),
    quantity INTEGER NOT NULL,
    received_quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stock movements
CREATE TABLE inventory.movements (
    movement_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id),
    from_warehouse_id INTEGER REFERENCES inventory.warehouses(warehouse_id),
    to_warehouse_id INTEGER REFERENCES inventory.warehouses(warehouse_id),
    movement_type VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL,
    reference_type VARCHAR(50),
    reference_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory reports
CREATE TABLE inventory.reports (
    report_id SERIAL PRIMARY KEY,
    report_type VARCHAR(50) NOT NULL,
    warehouse_id INTEGER REFERENCES inventory.warehouses(warehouse_id),
    generated_by INTEGER REFERENCES accounts.users(user_id),
    report_data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLES - ORDERS SCHEMA (8 tables)
-- =============================================================================

-- Orders
CREATE TABLE orders.orders (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(30) NOT NULL UNIQUE,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id),
    status order_status DEFAULT 'pending',
    currency VARCHAR(3) DEFAULT 'USD',
    subtotal positive_decimal NOT NULL DEFAULT 0,
    discount_amount positive_decimal DEFAULT 0,
    tax_amount positive_decimal DEFAULT 0,
    shipping_amount positive_decimal DEFAULT 0,
    shipping_tax positive_decimal DEFAULT 0,
    total_amount positive_decimal NOT NULL DEFAULT 0,
    paid_amount positive_decimal DEFAULT 0,
    refunded_amount positive_decimal DEFAULT 0,
    shipping_address_id INTEGER REFERENCES accounts.addresses(address_id),
    billing_address_id INTEGER REFERENCES accounts.addresses(address_id),
    coupon_code VARCHAR(20),
    notes TEXT,
    internal_notes TEXT,
    source VARCHAR(50) DEFAULT 'web',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    cancelled_at TIMESTAMP
);

-- Order items
CREATE TABLE orders.order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id),
    variant_id INTEGER REFERENCES catalog.product_variant_attrs(variant_id),
    sku VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price positive_decimal NOT NULL,
    unit_cost positive_decimal,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    discount_amount positive_decimal DEFAULT 0,
    tax_percent DECIMAL(5, 2) DEFAULT 0,
    tax_amount positive_decimal DEFAULT 0,
    total_price positive_decimal NOT NULL,
    fulfilled_quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Order status history
CREATE TABLE orders.status_history (
    history_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id) ON DELETE CASCADE,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    changed_by INTEGER REFERENCES accounts.users(user_id),
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Order notes
CREATE TABLE orders.notes (
    note_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id) ON DELETE CASCADE,
    note_type VARCHAR(20) DEFAULT 'general',
    content TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT FALSE,
    created_by INTEGER REFERENCES accounts.users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Order discounts
CREATE TABLE orders.discounts (
    discount_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL,
    discount_type VARCHAR(20) NOT NULL,
    discount_value positive_decimal NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions
CREATE TABLE orders.subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id),
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id),
    status VARCHAR(20) DEFAULT 'active',
    frequency VARCHAR(20) NOT NULL,
    quantity INTEGER DEFAULT 1,
    next_delivery_date DATE,
    price_at_subscription positive_decimal NOT NULL,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    shipping_address_id INTEGER REFERENCES accounts.addresses(address_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cancelled_at TIMESTAMP
);

-- Subscription history
CREATE TABLE orders.subscription_history (
    history_id SERIAL PRIMARY KEY,
    subscription_id INTEGER NOT NULL REFERENCES orders.subscriptions(subscription_id) ON DELETE CASCADE,
    action VARCHAR(20) NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Quote requests
CREATE TABLE orders.quote_requests (
    quote_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id),
    status VARCHAR(20) DEFAULT 'pending',
    products JSONB NOT NULL,
    total_amount positive_decimal,
    valid_until DATE,
    responded_at TIMESTAMP,
    response_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLES - PAYMENTS SCHEMA (5 tables)
-- =============================================================================

-- Payments
CREATE TABLE payments.payments (
    payment_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id),
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id),
    payment_method payment_method NOT NULL,
    amount positive_decimal NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_status payment_status DEFAULT 'pending',
    transaction_id VARCHAR(200),
    gateway_response JSONB,
    payment_gateway VARCHAR(50),
    last_four_digits VARCHAR(4),
    receipt_url VARCHAR(500),
    paid_at TIMESTAMP,
    failed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Refunds
CREATE TABLE payments.refunds (
    refund_id SERIAL PRIMARY KEY,
    payment_id INTEGER NOT NULL REFERENCES payments.payments(payment_id),
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id),
    amount positive_decimal NOT NULL,
    reason VARCHAR(200),
    refund_status refund_status DEFAULT 'requested',
    processed_by INTEGER REFERENCES accounts.users(user_id),
    gateway_refund_id VARCHAR(200),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP
);

-- Payment methods
CREATE TABLE payments.user_payment_methods (
    method_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id) ON DELETE CASCADE,
    payment_method payment_method NOT NULL,
    token VARCHAR(255) NOT NULL,
    last_four VARCHAR(4),
    expiry_month INTEGER,
    expiry_year INTEGER,
    card_brand VARCHAR(50),
    bank_name VARCHAR(100),
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Invoices
CREATE TABLE payments.invoices (
    invoice_id SERIAL PRIMARY KEY,
    invoice_number VARCHAR(30) NOT NULL UNIQUE,
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id),
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id),
    subtotal positive_decimal NOT NULL,
    tax_amount positive_decimal DEFAULT 0,
    total_amount positive_decimal NOT NULL,
    paid_amount positive_decimal DEFAULT 0,
    due_date DATE,
    sent_at TIMESTAMP,
    paid_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payment disputes
CREATE TABLE payments.disputes (
    dispute_id SERIAL PRIMARY KEY,
    payment_id INTEGER NOT NULL REFERENCES payments.payments(payment_id),
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id),
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id),
    reason VARCHAR(100) NOT NULL,
    amount positive_decimal NOT NULL,
    status VARCHAR(20) DEFAULT 'open',
    evidence JSONB DEFAULT '{}',
    resolution TEXT,
    resolved_by INTEGER REFERENCES accounts.users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP
);

-- =============================================================================
-- TABLES - SHIPPING SCHEMA (6 tables)
-- =============================================================================

-- Shipping carriers
CREATE TABLE shipping.carriers (
    carrier_id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    tracking_url_template VARCHAR(500),
    logo_url VARCHAR(500),
    contact_info contact_info,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Shipping methods
CREATE TABLE shipping.methods (
    method_id SERIAL PRIMARY KEY,
    carrier_id INTEGER NOT NULL REFERENCES shipping.carriers(carrier_id),
    code VARCHAR(20) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    base_price positive_decimal DEFAULT 0,
    min_weight DECIMAL(8, 2),
    max_weight DECIMAL(8, 2),
    min_dimensions JSONB,
    max_dimensions JSONB,
    estimated_days_min INTEGER,
    estimated_days_max INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(carrier_id, code)
);

-- Shipments
CREATE TABLE shipping.shipments (
    shipment_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id),
    carrier_id INTEGER REFERENCES shipping.carriers(carrier_id),
    method_id INTEGER REFERENCES shipping.methods(method_id),
    tracking_number VARCHAR(100),
    shipping_status shipping_status DEFAULT 'label_created',
    label_url VARCHAR(500),
    shipping_cost positive_decimal,
    weight DECIMAL(8, 3),
    dimensions JSONB,
    estimated_delivery DATE,
    actual_delivery_date DATE,
    delivery_confirmed_by VARCHAR(100),
    shipped_at TIMESTAMP,
    out_for_delivery_at TIMESTAMP,
    delivered_at TIMESTAMP,
    exception_code VARCHAR(50),
    exception_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Shipment events
CREATE TABLE shipping.events (
    event_id SERIAL PRIMARY KEY,
    shipment_id INTEGER NOT NULL REFERENCES shipping.shipments(shipment_id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    event_date TIMESTAMP NOT NULL,
    location VARCHAR(200),
    description TEXT,
    raw_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Shipping rates cache
CREATE TABLE shipping.rates_cache (
    cache_id SERIAL PRIMARY KEY,
    origin_postal_code VARCHAR(20),
    dest_postal_code VARCHAR(20),
    dest_country VARCHAR(100),
    weight DECIMAL(8, 2),
    carrier_id INTEGER REFERENCES shipping.carriers(carrier_id),
    method_id INTEGER REFERENCES shipping.methods(method_id),
    rate positive_decimal NOT NULL,
    estimated_days INTEGER,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Return requests
CREATE TABLE shipping.returns (
    return_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders.orders(order_id),
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id),
    status VARCHAR(20) DEFAULT 'requested',
    reason VARCHAR(200),
    items JSONB NOT NULL,
    return_label_url VARCHAR(500),
    return_tracking_number VARCHAR(100),
    refund_amount positive_decimal,
    inspected_at TIMESTAMP,
    inspection_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP,
    shipped_at TIMESTAMP,
    received_at TIMESTAMP,
    refunded_at TIMESTAMP
);

-- =============================================================================
-- TABLES - MARKETING SCHEMA (5 tables)
-- =============================================================================

-- Promotions
CREATE TABLE marketing.promotions (
    promotion_id SERIAL PRIMARY KEY,
    code VARCHAR(20) UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    promotion_type VARCHAR(20) NOT NULL,
    discount_value positive_decimal NOT NULL,
    discount_type VARCHAR(20) NOT NULL,
    min_order_amount positive_decimal DEFAULT 0,
    max_discount_amount positive_decimal,
    usage_limit INTEGER,
    usage_limit_per_customer INTEGER,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Promotion products/categories
CREATE TABLE marketing.promotion_rules (
    rule_id SERIAL PRIMARY KEY,
    promotion_id INTEGER NOT NULL REFERENCES marketing.promotions(promotion_id) ON DELETE CASCADE,
    rule_type VARCHAR(20) NOT NULL,
    target_type VARCHAR(20) NOT NULL,
    target_id INTEGER NOT NULL,
    discount_modifier DECIMAL(4, 2) DEFAULT 1.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Coupons
CREATE TABLE marketing.coupons (
    coupon_id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    promotion_id INTEGER REFERENCES marketing.promotions(promotion_id),
    discount_type VARCHAR(20) NOT NULL,
    discount_value positive_decimal NOT NULL,
    min_order_amount positive_decimal DEFAULT 0,
    max_uses INTEGER,
    current_uses INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP,
    created_by INTEGER REFERENCES accounts.users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Email campaigns
CREATE TABLE marketing.campaigns (
    campaign_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    subject VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    segment_criteria JSONB,
    sent_count INTEGER DEFAULT 0,
    open_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    scheduled_at TIMESTAMP,
    sent_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'draft',
    created_by INTEGER REFERENCES accounts.users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Email subscribers
CREATE TABLE marketing.subscribers (
    subscriber_id SERIAL PRIMARY KEY,
    email email_address NOT NULL UNIQUE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    source VARCHAR(50) DEFAULT 'website',
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP,
    unsubscribed_at TIMESTAMP,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLES - ANALYTICS SCHEMA (3 tables)
-- =============================================================================

-- Page views
CREATE TABLE analytics.page_views (
    view_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES accounts.users(user_id),
    session_id VARCHAR(255),
    page_type VARCHAR(50) NOT NULL,
    object_id VARCHAR(100),
    referrer VARCHAR(500),
    user_agent TEXT,
    ip_address INET,
    country VARCHAR(100),
    device_type VARCHAR(20),
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product analytics
CREATE TABLE analytics.product_analytics (
    analytics_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES catalog.products(product_id),
    date DATE NOT NULL,
    views INTEGER DEFAULT 0,
    unique_views INTEGER DEFAULT 0,
    add_to_cart_count INTEGER DEFAULT 0,
    purchase_count INTEGER DEFAULT 0,
    conversion_rate DECIMAL(8, 6) DEFAULT 0,
    average_rating DECIMAL(3, 2) DEFAULT 0,
    revenue DECIMAL(15, 2) DEFAULT 0,
    UNIQUE(product_id, date)
);

-- Daily metrics
CREATE TABLE analytics.daily_metrics (
    metric_id SERIAL PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    total_orders INTEGER DEFAULT 0,
    total_revenue DECIMAL(15, 2) DEFAULT 0,
    total_items_sold INTEGER DEFAULT 0,
    average_order_value DECIMAL(10, 2) DEFAULT 0,
    new_customers INTEGER DEFAULT 0,
    returning_customers INTEGER DEFAULT 0,
    cart_abandonment_rate DECIMAL(5, 2) DEFAULT 0,
    conversion_rate DECIMAL(5, 2) DEFAULT 0
);

-- =============================================================================
-- TABLES - LOGISTICS SCHEMA (3 tables)
-- =============================================================================

-- Shipping zones
CREATE TABLE logistics.shipping_zones (
    zone_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    countries TEXT[],
    states TEXT[],
    postal_code_pattern VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Zone rates
CREATE TABLE logistics.zone_rates (
    rate_id SERIAL PRIMARY KEY,
    zone_id INTEGER NOT NULL REFERENCES logistics.shipping_zones(zone_id) ON DELETE CASCADE,
    carrier_id INTEGER NOT NULL REFERENCES shipping.carriers(carrier_id),
    method_id INTEGER NOT NULL REFERENCES shipping.methods(method_id),
    base_rate positive_decimal NOT NULL,
    weight_rate positive_decimal DEFAULT 0,
    min_weight DECIMAL(8, 2),
    max_weight DECIMAL(8, 2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Delivery slots
CREATE TABLE logistics.delivery_slots (
    slot_id SERIAL PRIMARY KEY,
    warehouse_id INTEGER REFERENCES inventory.warehouses(warehouse_id),
    date DATE NOT NULL,
    time_slot VARCHAR(50) NOT NULL,
    max_orders INTEGER DEFAULT 50,
    current_orders INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(date, time_slot, warehouse_id)
);

-- =============================================================================
-- TABLES - SUPPORT SCHEMA (2 tables)
-- =============================================================================

-- Support tickets
CREATE TABLE support.tickets (
    ticket_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES accounts.users(user_id),
    order_id INTEGER REFERENCES orders.orders(order_id),
    ticket_type VARCHAR(50) NOT NULL,
    subject VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'open',
    priority VARCHAR(20) DEFAULT 'medium',
    assigned_to INTEGER REFERENCES accounts.users(user_id),
    first_response_at TIMESTAMP,
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ticket messages
CREATE TABLE support.messages (
    message_id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL REFERENCES support.tickets(ticket_id) ON DELETE CASCADE,
    sender_id INTEGER NOT NULL REFERENCES accounts.users(user_id),
    sender_type VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- INDEXES (100+ indexes)
-- =============================================================================

-- Accounts indexes
CREATE INDEX idx_users_email ON accounts.users(email);
CREATE INDEX idx_users_status ON accounts.users(status);
CREATE INDEX idx_users_role ON accounts.users(role);
CREATE INDEX idx_users_created ON accounts.users(created_at);
CREATE INDEX idx_profiles_user ON accounts.profiles(user_id);
CREATE INDEX idx_addresses_user ON accounts.addresses(user_id);
CREATE INDEX idx_addresses_country ON accounts.addresses(country);
CREATE INDEX idx_sessions_user ON accounts.sessions(user_id);
CREATE INDEX idx_sessions_token ON accounts.sessions(session_token);
CREATE INDEX idx_sessions_expires ON accounts.sessions(expires_at);
CREATE INDEX idx_auth_logs_user ON accounts.auth_logs(user_id);
CREATE INDEX idx_auth_logs_created ON accounts.auth_logs(created_at);
CREATE INDEX idx_verifications_user ON accounts.verifications(user_id);
CREATE INDEX idx_verifications_token ON accounts.verifications(verification_token);
CREATE INDEX idx_wishlists_user ON accounts.wishlists(user_id);
CREATE INDEX idx_wishlist_items_wishlist ON accounts.wishlist_items(wishlist_id);

-- Catalog indexes
CREATE INDEX idx_categories_parent ON catalog.categories(parent_id);
CREATE INDEX idx_categories_slug ON catalog.categories(slug);
CREATE INDEX idx_categories_active ON catalog.categories(is_active);
CREATE INDEX idx_brands_slug ON catalog.brands(slug);
CREATE INDEX idx_products_sku ON catalog.products(sku);
CREATE INDEX idx_products_slug ON catalog.products(slug);
CREATE INDEX idx_products_brand ON catalog.products(brand_id);
CREATE INDEX idx_products_status ON catalog.products(status);
CREATE INDEX idx_products_price ON catalog.products(base_price);
CREATE INDEX idx_products_rating ON catalog.products(average_rating DESC);
CREATE INDEX idx_products_created ON catalog.products(created_at);
CREATE INDEX idx_products_categories ON catalog.product_categories(category_id);
CREATE INDEX idx_attributes_type ON catalog.attributes(type);
CREATE INDEX idx_variant_attrs_product ON catalog.product_variant_attrs(product_id);
CREATE INDEX idx_variant_attrs_sku ON catalog.product_variant_attrs(sku);
CREATE INDEX idx_images_product ON catalog.product_images(product_id);
CREATE INDEX idx_product_tags_tag ON catalog.product_tags(tag_id);
CREATE INDEX idx_reviews_product ON catalog.reviews(product_id);
CREATE INDEX idx_reviews_user ON catalog.reviews(user_id);
CREATE INDEX idx_reviews_rating ON catalog.reviews(rating DESC);

-- Inventory indexes
CREATE INDEX idx_warehouses_active ON inventory.warehouses(is_active);
CREATE INDEX idx_locations_warehouse ON inventory.locations(warehouse_id);
CREATE INDEX idx_locations_code ON inventory.locations(location_code);
CREATE INDEX idx_items_product ON inventory.items(product_id);
CREATE INDEX idx_items_warehouse ON inventory.items(warehouse_id);
CREATE INDEX idx_items_location ON inventory.items(location_id);
CREATE INDEX idx_adjustments_item ON inventory.adjustments(item_id);
CREATE INDEX idx_adjustments_type ON inventory.adjustments(adjustment_type);
CREATE INDEX idx_transfers_from ON inventory.transfers(from_warehouse_id);
CREATE INDEX idx_transfers_to ON inventory.transfers(to_warehouse_id);
CREATE INDEX idx_transfers_status ON inventory.transfers(status);
CREATE INDEX idx_movements_product ON inventory.movements(product_id);
CREATE INDEX idx_movements_type ON inventory.movements(movement_type);
CREATE INDEX idx_movements_created ON inventory.movements(created_at);

-- Orders indexes
CREATE INDEX idx_orders_user ON orders.orders(user_id);
CREATE INDEX idx_orders_number ON orders.orders(order_number);
CREATE INDEX idx_orders_status ON orders.orders(status);
CREATE INDEX idx_orders_created ON orders.orders(created_at);
CREATE INDEX idx_orders_total ON orders.orders(total_amount);
CREATE INDEX idx_order_items_order ON orders.order_items(order_id);
CREATE INDEX idx_order_items_product ON orders.order_items(product_id);
CREATE INDEX idx_order_items_sku ON orders.order_items(sku);
CREATE INDEX idx_status_history_order ON orders.status_history(order_id);
CREATE INDEX idx_notes_order ON orders.notes(order_id);
CREATE INDEX idx_discounts_order ON orders.discounts(order_id);
CREATE INDEX idx_subscriptions_user ON orders.subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON orders.subscriptions(status);
CREATE INDEX idx_subscriptions_next ON orders.subscriptions(next_delivery_date);
CREATE INDEX idx_quote_requests_user ON orders.quote_requests(user_id);
CREATE INDEX idx_quote_requests_status ON orders.quote_requests(status);

-- Payments indexes
CREATE INDEX idx_payments_order ON payments.payments(order_id);
CREATE INDEX idx_payments_user ON payments.payments(user_id);
CREATE INDEX idx_payments_status ON payments.payments(payment_status);
CREATE INDEX idx_payments_transaction ON payments.payments(transaction_id);
CREATE INDEX idx_payments_created ON payments.payments(created_at);
CREATE INDEX idx_refunds_payment ON payments.refunds(payment_id);
CREATE INDEX idx_refunds_order ON payments.refunds(order_id);
CREATE INDEX idx_user_methods_user ON payments.user_payment_methods(user_id);
CREATE INDEX idx_invoices_order ON payments.invoices(order_id);
CREATE INDEX idx_invoices_user ON payments.invoices(user_id);
CREATE INDEX idx_disputes_payment ON payments.disputes(payment_id);
CREATE INDEX idx_disputes_order ON payments.disputes(order_id);

-- Shipping indexes
CREATE INDEX idx_carriers_code ON shipping.carriers(code);
CREATE INDEX idx_methods_carrier ON shipping.methods(carrier_id);
CREATE INDEX idx_shipments_order ON shipping.shipments(order_id);
CREATE INDEX idx_shipments_carrier ON shipping.shipments(carrier_id);
CREATE INDEX idx_shipments_tracking ON shipping.shipments(tracking_number);
CREATE INDEX idx_shipments_status ON shipping.shipments(shipping_status);
CREATE INDEX idx_shipments_created ON shipping.shipments(created_at);
CREATE INDEX idx_events_shipment ON shipping.events(shipment_id);
CREATE INDEX idx_events_date ON shipping.events(event_date);
CREATE INDEX idx_rates_cache_origin ON shipping.rates_cache(origin_postal_code);
CREATE INDEX idx_rates_cache_dest ON shipping.rates_cache(dest_postal_code);
CREATE INDEX idx_returns_order ON shipping.returns(order_id);
CREATE INDEX idx_returns_user ON shipping.returns(user_id);
CREATE INDEX idx_returns_status ON shipping.returns(status);

-- Marketing indexes
CREATE INDEX idx_promotions_code ON marketing.promotions(code);
CREATE INDEX idx_promotions_dates ON marketing.promotions(start_date, end_date);
CREATE INDEX idx_promotions_active ON marketing.promotions(is_active);
CREATE INDEX idx_promotion_rules_promo ON marketing.promotion_rules(promotion_id);
CREATE INDEX idx_coupons_code ON marketing.coupons(code);
CREATE INDEX idx_coupons_active ON marketing.coupons(is_active);
CREATE INDEX idx_campaigns_status ON marketing.campaigns(status);
CREATE INDEX idx_campaigns_scheduled ON marketing.campaigns(scheduled_at);
CREATE INDEX idx_subscribers_email ON marketing.subscribers(email);
CREATE INDEX idx_subscribers_verified ON marketing.subscribers(is_verified);

-- Analytics indexes
CREATE INDEX idx_page_views_user ON analytics.page_views(user_id);
CREATE INDEX idx_page_views_type ON analytics.page_views(page_type);
CREATE INDEX idx_page_views_date ON analytics.page_views(viewed_at);
CREATE INDEX idx_product_analytics_product ON analytics.product_analytics(product_id);
CREATE INDEX idx_product_analytics_date ON analytics.product_analytics(date);
CREATE INDEX idx_daily_metrics_date ON analytics.daily_metrics(date);

-- Logistics indexes
CREATE INDEX idx_zone_rates_zone ON logistics.zone_rates(zone_id);
CREATE INDEX idx_zone_rates_carrier ON logistics.zone_rates(carrier_id);
CREATE INDEX idx_delivery_slots_date ON logistics.delivery_slots(date);
CREATE INDEX idx_delivery_slots_warehouse ON logistics.delivery_slots(warehouse_id);

-- Support indexes
CREATE INDEX idx_tickets_user ON support.tickets(user_id);
CREATE INDEX idx_tickets_order ON support.tickets(order_id);
CREATE INDEX idx_tickets_status ON support.tickets(status);
CREATE INDEX idx_tickets_priority ON support.tickets(priority);
CREATE INDEX idx_tickets_created ON support.tickets(created_at);
CREATE INDEX idx_messages_ticket ON support.messages(ticket_id);
CREATE INDEX idx_messages_sender ON support.messages(sender_id);

-- =============================================================================
-- VIEWS (12 views)
-- =============================================================================

-- Active products view
CREATE VIEW catalog.active_products AS
SELECT p.*, b.name AS brand_name, c.name AS primary_category
FROM catalog.products p
LEFT JOIN catalog.brands b ON p.brand_id = b.brand_id
LEFT JOIN catalog.product_categories pc ON p.product_id = pc.product_id AND pc.is_primary = true
LEFT JOIN catalog.categories c ON pc.category_id = c.category_id
WHERE p.status = 'active' AND p.deleted_at IS NULL;

-- Order summary view
CREATE VIEW orders.order_summary AS
SELECT
    o.order_id,
    o.order_number,
    o.user_id,
    u.email,
    CONCAT(u.first_name, ' ', u.last_name) AS customer_name,
    o.status,
    o.total_amount,
    o.currency,
    o.created_at,
    COUNT(oi.item_id) AS item_count,
    STRING_AGG(DISTINCT p.name, ', ' ORDER BY p.name) AS products
FROM orders.orders o
JOIN accounts.users u ON o.user_id = u.user_id
LEFT JOIN orders.order_items oi ON o.order_id = oi.order_id
LEFT JOIN catalog.products p ON oi.product_id = p.product_id
GROUP BY o.order_id, o.order_number, o.user_id, u.email, u.first_name, u.last_name, o.status, o.total_amount, o.currency, o.created_at;

-- Inventory summary view
CREATE VIEW inventory.inventory_summary AS
SELECT
    p.product_id,
    p.sku,
    p.name,
    p.status,
    p.base_price,
    SUM(i.quantity_on_hand) AS total_stock,
    SUM(i.quantity_reserved) AS total_reserved,
    SUM(i.quantity_available) AS total_available,
    CASE
        WHEN SUM(i.quantity_available) <= 0 THEN 'out_of_stock'
        WHEN SUM(i.quantity_available) <= p.sale_count THEN 'low_stock'
        ELSE 'in_stock'
    END AS stock_status,
    COUNT(DISTINCT i.warehouse_id) AS warehouse_count
FROM catalog.products p
LEFT JOIN inventory.items i ON p.product_id = i.product_id
GROUP BY p.product_id, p.sku, p.name, p.status, p.base_price, p.sale_count;

-- Customer summary view
CREATE VIEW accounts.customer_summary AS
SELECT
    u.user_id,
    u.username,
    u.email,
    u.status,
    u.role,
    u.created_at AS member_since,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS total_spent,
    COALESCE(AVG(o.total_amount), 0) AS avg_order_value,
    MAX(o.created_at) AS last_order_date,
    COUNT(DISTINCT a.address_id) AS address_count
FROM accounts.users u
LEFT JOIN orders.orders o ON u.user_id = o.user_id
LEFT JOIN accounts.addresses a ON u.user_id = a.user_id
GROUP BY u.user_id, u.username, u.email, u.status, u.role, u.created_at;

-- Sales by day view
CREATE VIEW analytics.sales_by_day AS
SELECT
    DATE(o.created_at) AS sale_date,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.total_amount) AS total_revenue,
    SUM(o.paid_amount) AS total_paid,
    SUM(oi.quantity) AS items_sold,
    AVG(o.total_amount) AS avg_order_value
FROM orders.orders o
LEFT JOIN orders.order_items oi ON o.order_id = oi.order_id
WHERE o.status NOT IN ('cancelled')
GROUP BY DATE(o.created_at)
ORDER BY sale_date;

-- Top products view
CREATE VIEW analytics.top_products AS
SELECT
    p.product_id,
    p.sku,
    p.name,
    SUM(oi.quantity) AS total_sold,
    SUM(oi.total_price) AS total_revenue,
    AVG(p.average_rating) AS avg_rating,
    COUNT(DISTINCT r.review_id) AS review_count
FROM catalog.products p
LEFT JOIN orders.order_items oi ON p.product_id = oi.product_id
LEFT JOIN catalog.reviews r ON p.product_id = r.product_id
WHERE oi.order_id IS NOT NULL
GROUP BY p.product_id, p.sku, p.name, p.average_rating
ORDER BY total_revenue DESC
LIMIT 50;

-- Payment summary view
CREATE VIEW payments.payment_summary AS
SELECT
    DATE(p.created_at) AS payment_date,
    p.payment_method,
    p.payment_status,
    COUNT(p.payment_id) AS payment_count,
    SUM(p.amount) AS total_amount,
    COUNT(CASE WHEN p.payment_status = 'failed' THEN 1 END) AS failed_count,
    COUNT(CASE WHEN p.payment_status = 'completed' THEN 1 END) AS completed_count
FROM payments.payments p
GROUP BY DATE(p.created_at), p.payment_method, p.payment_status;

-- Shipping status view
CREATE VIEW shipping.shipping_status AS
SELECT
    s.shipment_id,
    s.order_id,
    s.tracking_number,
    s.shipping_status,
    s.carrier_id,
    c.name AS carrier_name,
    s.method_id,
    m.name AS method_name,
    s.shipping_cost,
    s.estimated_delivery,
    s.shipped_at,
    s.delivered_at,
    s.exception_code
FROM shipping.shipments s
LEFT JOIN shipping.carriers c ON s.carrier_id = c.carrier_id
LEFT JOIN shipping.methods m ON s.method_id = m.method_id;

-- Cart abandonment view (using page_views as proxy)
CREATE VIEW analytics.cart_abandonment AS
SELECT
    DATE(viewed_at) AS cart_date,
    COUNT(DISTINCT session_id) AS total_carts,
    0 AS converted_carts,
    0 AS abandoned_carts
FROM analytics.page_views
WHERE page_type = 'cart'
GROUP BY DATE(viewed_at);

-- Customer retention view
CREATE VIEW analytics.customer_retention AS
SELECT
    EXTRACT(YEAR FROM o.created_at) AS year,
    EXTRACT(MONTH FROM o.created_at) AS month,
    COUNT(DISTINCT o.user_id) AS total_customers,
    COUNT(DISTINCT CASE WHEN FIRST_ORDER.user_id IS NOT NULL THEN o.user_id END) AS returning_customers,
    ROUND(COUNT(DISTINCT CASE WHEN FIRST_ORDER.user_id IS NOT NULL THEN o.user_id END)::DECIMAL /
          COUNT(DISTINCT o.user_id) * 100, 2) AS retention_rate
FROM orders.orders o
LEFT JOIN (
    SELECT user_id, MIN(created_at) AS first_order_date
    FROM orders.orders
    GROUP BY user_id
) FIRST_ORDER ON o.user_id = FIRST_ORDER.user_id AND o.created_at > FIRST_ORDER.first_order_date + INTERVAL '30 days'
WHERE o.status NOT IN ('cancelled')
GROUP BY EXTRACT(YEAR FROM o.created_at), EXTRACT(MONTH FROM o.created_at)
ORDER BY year, month;

-- Support ticket stats view
CREATE VIEW support.ticket_stats AS
SELECT
    DATE(t.created_at) AS ticket_date,
    t.ticket_type,
    t.status,
    COUNT(t.ticket_id) AS ticket_count,
    AVG(EXTRACT(EPOCH FROM (t.first_response_at - t.created_at)) / 60) AS avg_first_response_minutes,
    AVG(EXTRACT(EPOCH FROM (t.resolved_at - t.created_at)) / 3600) AS avg_resolution_hours
FROM support.tickets t
GROUP BY DATE(t.created_at), t.ticket_type, t.status;

-- =============================================================================
-- TRIGGERS (8 triggers)
-- =============================================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at column
CREATE TRIGGER update_users_timestamp BEFORE UPDATE ON accounts.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_profiles_timestamp BEFORE UPDATE ON accounts.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_products_timestamp BEFORE UPDATE ON catalog.products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_items_timestamp BEFORE UPDATE ON inventory.items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_orders_timestamp BEFORE UPDATE ON orders.orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_payments_timestamp BEFORE UPDATE ON payments.payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_shipments_timestamp BEFORE UPDATE ON shipping.shipments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_tickets_timestamp BEFORE UPDATE ON support.tickets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_number IS NULL THEN
        NEW.order_number := 'ORD-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
            LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_order_number_trigger BEFORE INSERT ON orders.orders
    FOR EACH ROW EXECUTE FUNCTION generate_order_number();

-- Update order totals on item change
CREATE OR REPLACE FUNCTION update_order_totals()
RETURNS TRIGGER AS $$
DECLARE
    v_order_id INTEGER;
    v_subtotal DECIMAL(10, 2);
    v_tax DECIMAL(10, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_order_id := OLD.order_id;
    ELSE
        v_order_id := NEW.order_id;
    END IF;

    SELECT
        COALESCE(SUM(total_price), 0),
        COALESCE(SUM(tax_amount), 0)
    INTO v_subtotal, v_tax
    FROM orders.order_items
    WHERE order_id = v_order_id;

    UPDATE orders.orders
    SET subtotal = v_subtotal,
        tax_amount = v_tax,
        total_amount = v_subtotal + v_tax + shipping_amount + shipping_tax - discount_amount
    WHERE order_id = v_order_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_order_items_totals
    AFTER INSERT OR UPDATE OR DELETE ON orders.order_items
    FOR EACH ROW EXECUTE FUNCTION update_order_totals();

-- Update product sale count
CREATE OR REPLACE FUNCTION update_product_sale_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE catalog.products
        SET sale_count = sale_count + NEW.quantity
        WHERE product_id = NEW.product_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE catalog.products
        SET sale_count = sale_count - OLD.quantity
        WHERE product_id = OLD.product_id;
        RETURN OLD;
    ELSE
        UPDATE catalog.products
        SET sale_count = sale_count + NEW.quantity - OLD.quantity
        WHERE product_id = NEW.product_id;
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_product_sale_count_trigger
    AFTER INSERT OR UPDATE OR DELETE ON orders.order_items
    FOR EACH ROW EXECUTE FUNCTION update_product_sale_count();

-- Update product review stats
CREATE OR REPLACE FUNCTION update_product_review_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE catalog.products
        SET review_count = review_count + 1,
            average_rating = (
                SELECT AVG(rating)::DECIMAL(3, 2)
                FROM catalog.reviews
                WHERE product_id = NEW.product_id
            )
        WHERE product_id = NEW.product_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE catalog.products
        SET review_count = review_count - 1,
            average_rating = COALESCE((
                SELECT AVG(rating)::DECIMAL(3, 2)
                FROM catalog.reviews
                WHERE product_id = OLD.product_id
            ), 0)
        WHERE product_id = OLD.product_id;
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_review_stats_trigger
    AFTER INSERT OR DELETE ON catalog.reviews
    FOR EACH ROW EXECUTE FUNCTION update_product_review_stats();

-- =============================================================================
-- SAMPLE DATA GENERATION
-- =============================================================================

-- Insert categories (30 categories)
INSERT INTO catalog.categories (name, slug, description, display_order) VALUES
('Electronics', 'electronics', 'Electronic devices and accessories', 1),
('Computers', 'computers', 'Desktop and laptop computers', 2),
('Smartphones', 'smartphones', 'Mobile phones and tablets', 3),
('Audio', 'audio', 'Headphones, speakers, and audio equipment', 4),
('Video Games', 'video-games', 'Gaming consoles and accessories', 5),
('Books', 'books', 'Books and publications', 6),
('Clothing', 'clothing', 'Apparel and accessories', 7),
('Shoes', 'shoes', 'Footwear', 8),
('Home & Kitchen', 'home-kitchen', 'Home appliances and kitchenware', 9),
('Beauty', 'beauty', 'Beauty and personal care', 10),
('Sports', 'sports', 'Sports equipment and apparel', 11),
('Outdoors', 'outdoors', 'Outdoor gear and camping', 12),
('Toys', 'toys', 'Toys and games', 13),
('Baby', 'baby', 'Baby products', 14),
('Health', 'health', 'Health and wellness', 15),
('Automotive', 'automotive', 'Car accessories and parts', 16),
('Office Supplies', 'office-supplies', 'Office and stationery', 17),
('Pet Supplies', 'pet-supplies', 'Pet food and accessories', 18),
('Food & Beverages', 'food-beverages', 'Food and drinks', 19),
('Jewelry', 'jewelry', 'Jewelry and watches', 20),
('Handbags', 'handbags', 'Bags and luggage', 21),
('Garden', 'garden', 'Garden and outdoor living', 22),
('Tools', 'tools', 'Tools and hardware', 23),
('Musical Instruments', 'musical-instruments', 'Instruments and equipment', 24),
('Art & Crafts', 'art-crafts', 'Art supplies and craft materials', 25),
('Party Supplies', 'party-supplies', 'Party decorations and supplies', 26),
('Movies & Music', 'movies-music', 'Movies, music, and entertainment', 27),
('Magazines', 'magazines', 'Magazine subscriptions', 28),
('Groceries', 'groceries', 'Grocery items', 29),
('Other', 'other', 'Other products', 30);

-- Insert brands (25 brands)
INSERT INTO catalog.brands (name, slug, description, website) VALUES
('TechCorp', 'techcorp', 'Technology solutions provider', 'https://techcorp.example.com'),
('SmartGear', 'smartgear', 'Smart devices and gadgets', 'https://smartgear.example.com'),
('ComfortHome', 'comforthome', 'Home comfort products', 'https://comforthome.example.com'),
('ActiveLife', 'activelife', 'Sports and outdoor gear', 'https://activelife.example.com'),
('StyleFashion', 'stylefashion', 'Fashion and clothing', 'https://stylefashion.example.com'),
('PowerTools Pro', 'powertools-pro', 'Professional tools', 'https://powertoolspro.example.com'),
('EcoGoods', 'ecogoods', 'Eco-friendly products', 'https://ecogoods.example.com'),
('KidsWorld', 'kidsworld', 'Toys and kids products', 'https://kidsworld.example.com'),
('AudioPhile', 'audiophile', 'Premium audio equipment', 'https://audiophile.example.com'),
('GameZone', 'gamezone', 'Gaming products', 'https://gamezone.example.com'),
('BookWorm', 'bookworm', 'Books and publications', 'https://bookworm.example.com'),
('BeautyPlus', 'beautyplus', 'Beauty products', 'https://beautyplus.example.com'),
('FitGear', 'fitgear', 'Fitness equipment', 'https://fitgear.example.com'),
('PetLovers', 'petlovers', 'Pet supplies', 'https://petlovers.example.com'),
('HomeChef', 'homechef', 'Kitchen appliances', 'https://homechef.example.com'),
('OfficeMax', 'officemax', 'Office supplies', 'https://officemax.example.com'),
('AutoParts Inc', 'autoparts-inc', 'Auto parts and accessories', 'https://autopartsinc.example.com'),
('JewelBox', 'jewelbox', 'Jewelry and watches', 'https://jewelbox.example.com'),
('TravelGear', 'travelgear', 'Travel accessories', 'https://travelgear.example.com'),
('MusicWorld', 'musicworld', 'Musical instruments', 'https://musicworld.example.com'),
('ArtStudio', 'artstudio', 'Art supplies', 'https://artstudio.example.com'),
('GardenPro', 'gardenpro', 'Garden equipment', 'https://gardenpro.example.com'),
('BabyCare', 'babycare', 'Baby products', 'https://babycare.example.com'),
('HealthFirst', 'healthfirst', 'Health products', 'https://healthfirst.example.com'),
('General Goods', 'general-goods', 'General merchandise', 'https://generalgoods.example.com');

-- Insert tags (50 tags)
INSERT INTO catalog.tags (name, slug, description) VALUES
('Best Seller', 'best-seller', 'Popular products'),
('New Arrival', 'new-arrival', 'Recently added products'),
('Sale', 'sale', 'Discounted products'),
('Limited Edition', 'limited-edition', 'Limited quantity products'),
('Eco-Friendly', 'eco-friendly', 'Environmentally friendly'),
('Wireless', 'wireless', 'Wireless products'),
('Bluetooth', 'bluetooth', 'Bluetooth enabled'),
('Rechargeable', 'rechargeable', 'Rechargeable products'),
('Waterproof', 'waterproof', 'Water resistant products'),
('Portable', 'portable', 'Portable products'),
('Smart', 'smart', 'Smart home products'),
('Premium', 'premium', 'Premium quality products'),
('Budget', 'budget', 'Budget friendly'),
('Kids', 'kids', 'Products for kids'),
('Adult', 'adult', 'Products for adults'),
('Professional', 'professional', 'Professional grade'),
('Beginner', 'beginner', 'For beginners'),
('Advanced', 'advanced', 'Advanced level products'),
('Outdoor', 'outdoor', 'Outdoor use products'),
('Indoor', 'indoor', 'Indoor use products'),
('Heavy Duty', 'heavy-duty', 'Heavy duty products'),
('Lightweight', 'lightweight', 'Lightweight products'),
('Durable', 'durable', 'Durable products'),
('Compact', 'compact', 'Compact design'),
('Energy Efficient', 'energy-efficient', 'Energy saving products'),
('Quiet', 'quiet', 'Low noise products'),
('Fast', 'fast', 'Fast operating products'),
('Slow', 'slow', 'Slow speed products'),
('Automatic', 'automatic', 'Automatic operation'),
('Manual', 'manual', 'Manual operation'),
('Digital', 'digital', 'Digital products'),
('Analog', 'analog', 'Analog products'),
('Vintage', 'vintage', 'Vintage style products'),
('Modern', 'modern', 'Modern design products'),
('Classic', 'classic', 'Classic design'),
('Trending', 'trending', 'Currently trending'),
('Popular', 'popular', 'Popular items'),
('Exclusive', 'exclusive', 'Exclusive products'),
('Gift Idea', 'gift-idea', 'Good as gifts'),
('Set', 'set', 'Products that come in sets'),
('Bundle', 'bundle', 'Bundled products'),
('Single', 'single', 'Individual products'),
('Pack', 'pack', 'Products sold in packs'),
('Refurbished', 'refurbished', 'Refurbished items'),
('Open Box', 'open-box', 'Open box items'),
('Clearance', 'clearance', 'Clearance products'),
('Seasonal', 'seasonal', 'Seasonal products'),
('Holiday', 'holiday', 'Holiday themed products');

-- Insert warehouses (5 warehouses)
INSERT INTO inventory.warehouses (code, name, address_line1, city, state, postal_code, country, is_primary) VALUES
('WH-EAST', 'East Coast Warehouse', '100 Industrial Parkway', 'Newark', 'NJ', '07102', 'USA', true),
('WH-WEST', 'West Coast Warehouse', '200 Commerce Drive', 'Los Angeles', 'CA', '90001', 'USA', false),
('WH-CENTRAL', 'Central Warehouse', '300 Distribution Blvd', 'Chicago', 'IL', '60601', 'USA', false),
('WH-SOUTH', 'Southern Warehouse', '400 Logistics Way', 'Dallas', 'TX', '75001', 'USA', false),
('WH-EUROPE', 'European Warehouse', '500 Europa Street', 'London', '', 'EC1A 1BB', 'UK', false);

-- Insert carriers (10 carriers)
INSERT INTO shipping.carriers (code, name, tracking_url_template) VALUES
('FEDEX', 'FedEx', 'https://www.fedex.com/track?tracknumbers={tracking_number}'),
('UPS', 'UPS', 'https://www.ups.com/track?tracknum={tracking_number}'),
('USPS', 'USPS', 'https://tools.usps.com/go/TrackConfirmAction?tLabels={tracking_number}'),
('DHL', 'DHL', 'https://www.dhl.com/en/express/tracking.html?AWB={tracking_number}'),
('AMZL', 'Amazon Logistics', 'https://www.amazon.com/gp/your-account/shipping-track?trackingId={tracking_number}'),
('CANADAPOST', 'Canada Post', 'https://www.canadapost.ca/track/packagetracking.aspx?metric={tracking_number}'),
('AUSTRALIA', 'Australia Post', 'https://auspost.com.au/mypost/track/details/{tracking_number}'),
('ROYALMAIL', 'Royal Mail', 'https://www.royalmail.com/track-your-item?number={tracking_number}'),
('DPD', 'DPD', 'https://www.dpd.co.uk/apps/tracking/?reference={tracking_number}'),
('HERMES', 'Hermes', 'https://www.hermesparcel.co.uk/track-parcel/{tracking_number}');

-- Insert users (50 users)
INSERT INTO accounts.users (username, email, password_hash, first_name, last_name, phone, status, role) VALUES
('user001', 'user001@example.com', '$2b$12$hash1', 'John', 'Doe', '555-1001', 'active', 'customer'),
('user002', 'user002@example.com', '$2b$12$hash2', 'Jane', 'Smith', '555-1002', 'active', 'customer'),
('user003', 'user003@example.com', '$2b$12$hash3', 'Bob', 'Johnson', '555-1003', 'active', 'customer'),
('user004', 'user004@example.com', '$2b$12$hash4', 'Alice', 'Williams', '555-1004', 'inactive', 'customer'),
('user005', 'user005@example.com', '$2b$12$hash5', 'Charlie', 'Brown', '555-1005', 'active', 'customer'),
('user006', 'user006@example.com', '$2b$12$hash6', 'Diana', 'Miller', '555-1006', 'active', 'vendor'),
('user007', 'user007@example.com', '$2b$12$hash7', 'Eve', 'Davis', '555-1007', 'active', 'customer'),
('user008', 'user008@example.com', '$2b$12$hash8', 'Frank', 'Garcia', '555-1008', 'active', 'customer'),
('user009', 'user009@example.com', '$2b$12$hash9', 'Grace', 'Martinez', '555-1009', 'active', 'customer'),
('user010', 'user010@example.com', '$2b$12$hash10', 'Henry', 'Anderson', '555-1010', 'active', 'admin'),
('user011', 'user011@example.com', '$2b$12$hash11', 'Ivy', 'Taylor', '555-1011', 'active', 'customer'),
('user012', 'user012@example.com', '$2b$12$hash12', 'Jack', 'Thomas', '555-1012', 'active', 'customer'),
('user013', 'user013@example.com', '$2b$12$hash13', 'Kate', 'Jackson', '555-1013', 'active', 'customer'),
('user014', 'user014@example.com', '$2b$12$hash14', 'Leo', 'White', '555-1014', 'active', 'customer'),
('user015', 'user015@example.com', '$2b$12$hash15', 'Mia', 'Harris', '555-1015', 'active', 'vendor'),
('user016', 'user016@example.com', '$2b$12$hash16', 'Noah', 'Martin', '555-1016', 'active', 'customer'),
('user017', 'user017@example.com', '$2b$12$hash17', 'Olivia', 'Thompson', '555-1017', 'active', 'customer'),
('user018', 'user018@example.com', '$2b$12$hash18', 'Peter', 'Garcia', '555-1018', 'active', 'customer'),
('user019', 'user019@example.com', '$2b$12$hash19', 'Quinn', 'Lee', '555-1019', 'active', 'customer'),
('user020', 'user020@example.com', '$2b$12$hash20', 'Rachel', 'Walker', '555-1020', 'active', 'customer'),
('user021', 'user021@example.com', '$2b$12$hash21', 'Sam', 'Hall', '555-1021', 'active', 'customer'),
('user022', 'user022@example.com', '$2b$12$hash22', 'Tina', 'Allen', '555-1022', 'active', 'customer'),
('user023', 'user023@example.com', '$2b$12$hash23', 'Uma', 'Young', '555-1023', 'active', 'customer'),
('user024', 'user024@example.com', '$2b$12$hash24', 'Victor', 'King', '555-1024', 'active', 'customer'),
('user025', 'user025@example.com', '$2b$12$hash25', 'Wendy', 'Wright', '555-1025', 'active', 'customer'),
('user026', 'user026@example.com', '$2b$12$hash26', 'Xavier', 'Lopez', '555-1026', 'active', 'customer'),
('user027', 'user027@example.com', '$2b$12$hash27', 'Yara', 'Hill', '555-1027', 'active', 'customer'),
('user028', 'user028@example.com', '$2b$12$hash28', 'Zach', 'Scott', '555-1028', 'active', 'customer'),
('user029', 'user029@example.com', '$2b$12$hash29', 'Amy', 'Green', '555-1029', 'active', 'customer'),
('user030', 'user030@example.com', '$2b$12$hash30', 'Brian', 'Adams', '555-1030', 'active', 'customer'),
('user031', 'user031@example.com', '$2b$12$hash31', 'Cindy', 'Baker', '555-1031', 'active', 'customer'),
('user032', 'user032@example.com', '$2b$12$hash32', 'David', 'Nelson', '555-1032', 'active', 'customer'),
('user033', 'user033@example.com', '$2b$12$hash33', 'Emma', 'Carter', '555-1033', 'active', 'customer'),
('user034', 'user034@example.com', '$2b$12$hash34', 'Frank', 'Mitchell', '555-1034', 'active', 'customer'),
('user035', 'user035@example.com', '$2b$12$hash35', 'Gina', 'Perez', '555-1035', 'active', 'customer'),
('user036', 'user036@example.com', '$2b$12$hash36', 'Hugo', 'Roberts', '555-1036', 'active', 'customer'),
('user037', 'user037@example.com', '$2b$12$hash37', 'Irene', 'Turner', '555-1037', 'active', 'customer'),
('user038', 'user038@example.com', '$2b$12$hash38', 'Ivan', 'Phillips', '555-1038', 'active', 'customer'),
('user039', 'user039@example.com', '$2b$12$hash39', 'Judy', 'Campbell', '555-1039', 'active', 'customer'),
('user040', 'user040@example.com', '$2b$12$hash40', 'Kevin', 'Parker', '555-1040', 'active', 'customer'),
('user041', 'user041@example.com', '$2b$12$hash41', 'Laura', 'Evans', '555-1041', 'active', 'customer'),
('user042', 'user042@example.com', '$2b$12$hash42', 'Mike', 'Edwards', '555-1042', 'active', 'customer'),
('user043', 'user043@example.com', '$2b$12$hash43', 'Nina', 'Collins', '555-1043', 'active', 'customer'),
('user044', 'user044@example.com', '$2b$12$hash44', 'Oscar', 'Stewart', '555-1044', 'active', 'customer'),
('user045', 'user045@example.com', '$2b$12$hash45', 'Paula', 'Sanchez', '555-1045', 'active', 'customer'),
('user046', 'user046@example.com', '$2b$12$hash46', 'Quincy', 'Morris', '555-1046', 'active', 'customer'),
('user047', 'user047@example.com', '$2b$12$hash47', 'Rita', 'Rogers', '555-1047', 'active', 'customer'),
('user048', 'user048@example.com', '$2b$12$hash48', 'Steve', 'Reed', '555-1048', 'active', 'customer'),
('user049', 'user049@example.com', '$2b$12$hash49', 'Tara', 'Cook', '555-1049', 'active', 'customer'),
('user050', 'user050@example.com', '$2b$12$hash50', 'Ursula', 'Morgan', '555-1050', 'active', 'customer');

-- Insert products (100 products with basic data)
INSERT INTO catalog.products (sku, name, slug, description, base_price, status, view_count, sale_count) VALUES
('PROD-001', 'Wireless Bluetooth Headphones', 'wireless-bluetooth-headphones', 'Premium wireless headphones with noise cancellation', 149.99, 'active', 1500, 320),
('PROD-002', 'Smart Watch Pro', 'smart-watch-pro', 'Advanced fitness tracking smartwatch', 299.99, 'active', 2200, 180),
('PROD-003', 'Portable Bluetooth Speaker', 'portable-bluetooth-speaker', 'Waterproof portable speaker', 79.99, 'active', 980, 250),
('PROD-004', 'USB-C Hub 7-in-1', 'usb-c-hub-7-in-1', 'Multi-port USB-C hub', 49.99, 'active', 750, 420),
('PROD-005', 'Mechanical Gaming Keyboard', 'mechanical-gaming-keyboard', 'RGB mechanical keyboard for gaming', 129.99, 'active', 1100, 290),
('PROD-006', 'Wireless Gaming Mouse', 'wireless-gaming-mouse', 'High-precision wireless gaming mouse', 69.99, 'active', 890, 350),
('PROD-007', '27-inch 4K Monitor', '27-inch-4k-monitor', 'Professional 4K display', 449.99, 'active', 650, 85),
('PROD-008', 'Laptop Stand Adjustable', 'laptop-stand-adjustable', 'Ergonomic aluminum laptop stand', 59.99, 'active', 520, 180),
('PROD-009', 'Webcam 1080p HD', 'webcam-1080p-hd', 'Full HD webcam with microphone', 89.99, 'active', 780, 220),
('PROD-010', 'Desk Lamp LED', 'desk-lamp-led', 'Adjustable LED desk lamp', 39.99, 'active', 430, 150),
('PROD-011', 'Power Strip Surge Protector', 'power-strip-surge-protector', '6-outlet surge protector', 34.99, 'active', 620, 280),
('PROD-012', 'Cable Management Kit', 'cable-management-kit', 'Complete cable organization solution', 24.99, 'active', 380, 190),
('PROD-013', 'Ergonomic Office Chair', 'ergonomic-office-chair', 'Adjustable ergonomic chair', 349.99, 'active', 920, 65),
('PROD-014', 'Standing Desk Electric', 'standing-desk-electric', 'Electric height-adjustable desk', 599.99, 'active', 750, 45),
('PROD-015', 'Whiteboard Magnetic', 'whiteboard-magnetic', 'Large magnetic whiteboard', 79.99, 'active', 280, 90),
('PROD-016', 'Paper Shredder', 'paper-shredder', 'Cross-cut paper shredder', 119.99, 'active', 340, 75),
('PROD-017', 'Desk Organizer', 'desk-organizer', 'Multi-compartment desk organizer', 29.99, 'active', 410, 160),
('PROD-018', 'Footrest Ergonomic', 'footrest-ergonomic', 'Adjustable footrest', 44.99, 'active', 260, 110),
('PROD-019', 'Monitor Arm Single', 'monitor-arm-single', 'Single monitor arm mount', 99.99, 'active', 480, 140),
('PROD-020', 'Keyboard Wrist Rest', 'keyboard-wrist-rest', 'Gel memory foam wrist rest', 19.99, 'active', 520, 230),
('PROD-021', 'Blue Light Glasses', 'blue-light-glasses', 'Anti-blue light reading glasses', 29.99, 'active', 680, 310),
('PROD-022', 'Wireless Charger Fast', 'wireless-charger-fast', '15W fast wireless charger', 39.99, 'active', 890, 400),
('PROD-023', 'Power Bank 20000mAh', 'power-bank-20000mah', 'High-capacity portable charger', 49.99, 'active', 1100, 480),
('PROD-024', 'Phone Stand Adjustable', 'phone-stand-adjustable', 'Adjustable phone and tablet stand', 24.99, 'active', 570, 260),
('PROD-025', 'USB Flash Drive 128GB', 'usb-flash-drive-128gb', 'High-speed USB 3.0 flash drive', 19.99, 'active', 780, 520),
('PROD-026', 'External SSD 1TB', 'external-ssd-1tb', 'Portable 1TB SSD', 109.99, 'active', 920, 290),
('PROD-027', 'Memory Card 256GB', 'memory-card-256gb', 'High-speed microSD card', 39.99, 'active', 650, 340),
('PROD-028', 'HDMI Cable 6ft', 'hdmi-cable-6ft', 'Premium HDMI 2.1 cable', 14.99, 'active', 480, 380),
('PROD-029', 'Ethernet Cable Cat6', 'ethernet-cable-cat6', '10ft Cat6 ethernet cable', 9.99, 'active', 420, 290),
('PROD-030', 'Webcam Cover', 'webcam-cover', 'Sliding webcam privacy cover', 7.99, 'active', 350, 180),
('PROD-031', 'Screen Cleaner Kit', 'screen-cleaner-kit', 'Electronic screen cleaner', 12.99, 'active', 280, 140),
('PROD-032', 'Laptop Sleeve 15inch', 'laptop-sleeve-15inch', 'Protective laptop sleeve', 29.99, 'active', 520, 200),
('PROD-033', 'Wireless Presenter', 'wireless-presenter', 'Presentation remote control', 34.99, 'active', 320, 95),
('PROD-034', 'Portable Projector', 'portable-projector', 'Mini HD projector', 189.99, 'active', 680, 75),
('PROD-035', 'Smart Home Hub', 'smart-home-hub', 'Universal smart home controller', 129.99, 'active', 540, 120),
('PROD-036', 'Smart Bulb RGB', 'smart-bulb-rgb', 'Color-changing WiFi smart bulb', 24.99, 'active', 750, 380),
('PROD-037', 'Smart Plug Mini', 'smart-plug-mini', 'WiFi smart plug', 14.99, 'active', 680, 420),
('PROD-038', 'Security Camera WiFi', 'security-camera-wifi', 'Indoor security camera', 79.99, 'active', 820, 180),
('PROD-039', 'Doorbell Camera', 'doorbell-camera', 'Video doorbell', 149.99, 'active', 650, 95),
('PROD-040', 'Smart Thermostat', 'smart-thermostat', 'WiFi programmable thermostat', 199.99, 'active', 480, 85),
('PROD-041', 'Fitness Tracker Band', 'fitness-tracker-band', 'Waterproof fitness band', 49.99, 'active', 920, 350),
('PROD-042', 'Yoga Mat Premium', 'yoga-mat-premium', 'Non-slip exercise yoga mat', 39.99, 'active', 580, 220),
('PROD-043', 'Resistance Bands Set', 'resistance-bands-set', '5-piece resistance band set', 24.99, 'active', 420, 190),
('PROD-044', 'Adjustable Dumbbells', 'adjustable-dumbbells', 'Space-saving adjustable weights', 249.99, 'active', 680, 75),
('PROD-045', 'Foam Roller', 'foam-roller', 'High-density muscle roller', 29.99, 'active', 380, 160),
('PROD-046', 'Massage Gun', 'massage-gun', 'Percussion muscle massager', 179.99, 'active', 720, 120),
('PROD-047', 'Air Purifier HEPA', 'air-purifier-hepa', 'HEPA air purifier for room', 199.99, 'active', 540, 65),
('PROD-048', 'Humidifier Cool Mist', 'humidifier-cool-mist', 'Ultrasonic cool mist humidifier', 49.99, 'active', 420, 145),
('PROD-049', 'Oil Diffuser', 'oil-diffuser', 'Aromatherapy essential oil diffuser', 34.99, 'active', 480, 200),
('PROD-050', 'LED Strip Lights', 'led-strip-lights', '16ft RGB LED light strip', 29.99, 'active', 890, 420);

-- Generate more products (51-100)
INSERT INTO catalog.products (sku, name, slug, description, base_price, status, view_count, sale_count)
SELECT
    'PROD-' || LPAD((s.n)::text, 3, '0'),
    'Product ' || s.n,
    'product-' || s.n,
    'Description for product ' || s.n,
    (random() * 200 + 10)::DECIMAL(10, 2),
    'active',
    (random() * 500 + 50)::INTEGER,
    (random() * 100)::INTEGER
FROM generate_series(51, 100) AS s(n);

-- Insert daily metrics (last 90 days)
INSERT INTO analytics.daily_metrics (date, total_orders, total_revenue, total_items_sold, average_order_value, new_customers, returning_customers)
SELECT
    CURRENT_DATE - make_interval(days => n),
    (random() * 100 + 20)::INTEGER,
    (random() * 15000 + 2000)::DECIMAL(10, 2),
    (random() * 300 + 50)::INTEGER,
    (random() * 150 + 50)::DECIMAL(10, 2),
    (random() * 30 + 5)::INTEGER,
    (random() * 50 + 10)::INTEGER
FROM generate_series(0, 89) AS n;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- SELECT 'Database db_pg_mcp_large created successfully!' AS status;
-- SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema');
-- SELECT COUNT(*) FROM information_schema.views WHERE table_schema NOT IN ('pg_catalog', 'information_schema');
