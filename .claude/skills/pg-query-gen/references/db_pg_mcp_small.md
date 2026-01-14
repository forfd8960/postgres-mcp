# Database: db_pg_mcp_small

A small e-commerce database with basic user, product, and order management.

## Connection Info
- Host: localhost
- Port: 5432
- User: postgres
- Password: postgres
- Schema: testbed

## Tables

### testbed.users
User accounts for the e-commerce platform.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | integer | NO | auto |
| username | varchar | NO | |
| email | varchar | NO | |
| status | user_status | YES | 'active' |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |
| last_login | timestamp | YES | |

**Indexes:**
- `users_pkey` (id) - PRIMARY KEY
- `users_username_key` (username) - UNIQUE
- `idx_users_email` (email)
- `idx_users_status` (status)

### testbed.categories
Product categories with hierarchical structure.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | integer | NO | auto |
| name | varchar | NO | |
| parent_id | integer | YES | |
| description | text | YES | |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

**Indexes:**
- `categories_pkey` (id) - PRIMARY KEY

**Foreign Keys:**
- `parent_id` -> `testbed.categories(id)` (self-referential for hierarchy)

### testbed.products
Products available for sale.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | integer | NO | auto |
| name | varchar | NO | |
| description | text | YES | |
| price | numeric | NO | |
| stock_quantity | integer | YES | 0 |
| category | varchar | YES | |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

**Indexes:**
- `products_pkey` (id) - PRIMARY KEY
- `idx_products_category` (category)
- `idx_products_price` (price)

### testbed.orders
Customer orders.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | integer | NO | auto |
| user_id | integer | YES | |
| total_amount | numeric | NO | |
| status | varchar | YES | 'pending' |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |
| shipped_at | timestamp | YES | |

**Indexes:**
- `orders_pkey` (id) - PRIMARY KEY
- `idx_orders_user_id` (user_id)
- `idx_orders_status` (status)
- `idx_orders_created_at` (created_at)

**Foreign Keys:**
- `user_id` -> `testbed.users(id)`

### testbed.order_items
Line items within orders.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | integer | NO | auto |
| order_id | integer | YES | |
| product_id | integer | YES | |
| quantity | integer | NO | |
| price | numeric | NO | |

**Indexes:**
- `order_items_pkey` (id) - PRIMARY KEY

**Foreign Keys:**
- `order_id` -> `testbed.orders(id)`
- `product_id` -> `testbed.products(id)`

## Views

### testbed.active_users
Shows only active users.

```sql
SELECT id, username, email, created_at
FROM testbed.users
WHERE status = 'active';
```

### testbed.order_summary
Aggregated order information with user details.

```sql
SELECT
    o.id AS order_id,
    o.user_id,
    u.username,
    o.total_amount,
    o.status,
    o.created_at,
    count(oi.id) AS item_count
FROM testbed.orders o
JOIN testbed.users u ON o.user_id = u.id
LEFT JOIN testbed.order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.user_id, u.username, o.total_amount, o.status, o.created_at;
```

## Enum Types

### user_status
- active
- inactive
- suspended

## Common Query Patterns

### Get user orders with totals
```sql
SELECT u.username, COUNT(o.id) as order_count, SUM(o.total_amount) as total_spent
FROM testbed.users u
LEFT JOIN testbed.orders o ON u.id = o.user_id
GROUP BY u.id, u.username;
```

### Get product sales
```sql
SELECT p.name, SUM(oi.quantity) as units_sold, SUM(oi.quantity * oi.price) as revenue
FROM testbed.products p
JOIN testbed.order_items oi ON p.id = oi.product_id
GROUP BY p.id, p.name
ORDER BY revenue DESC;
```

### Orders by status
```sql
SELECT status, COUNT(*) as count, SUM(total_amount) as total
FROM testbed.orders
GROUP BY status;
```
