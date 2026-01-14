# Database: db_pg_mcp_medium

A medium-sized enterprise database with HR, inventory, and sales management.

## Connection Info
- Host: localhost
- Port: 5432
- User: postgres
- Password: postgres
- Schemas: hr, inventory, sales

---

## Schema: hr (Human Resources)

### hr.departments
Organizational departments.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| department_id | integer | NO | auto |
| name | varchar | NO | |
| code | varchar | NO | UNIQUE |
| parent_department_id | integer | YES | |
| budget | numeric | YES | 0 |
| manager_id | integer | YES | |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

**Foreign Keys:**
- `parent_department_id` -> `hr.departments(department_id)` (hierarchy)
- `manager_id` -> `hr.employees(employee_id)`

### hr.employees
Employee records.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| employee_id | integer | NO | auto |
| employee_code | varchar | NO | UNIQUE |
| first_name | varchar | NO | |
| last_name | varchar | NO | |
| email | varchar | NO | UNIQUE |
| phone | varchar | YES | |
| department_id | integer | YES | |
| job_title | varchar | YES | |
| hire_date | date | NO | |
| salary | numeric | YES | |
| commission_rate | numeric | YES | 0 |
| is_active | boolean | YES | true |
| termination_date | date | YES | |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |
| updated_at | timestamp | YES | CURRENT_TIMESTAMP |

**Foreign Keys:**
- `department_id` -> `hr.departments(department_id)`

### hr.attendance
Employee attendance tracking.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| attendance_id | integer | NO | auto |
| employee_id | integer | NO | |
| date | date | NO | |
| check_in | time | YES | |
| check_out | time | YES | |
| hours_worked | numeric | YES | |
| overtime_hours | numeric | YES | 0 |
| notes | text | YES | |

**Unique:** (employee_id, date)

**Foreign Keys:**
- `employee_id` -> `hr.employees(employee_id)`

### hr.salary_history
Historical salary records.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| history_id | integer | NO | auto |
| employee_id | integer | NO | |
| salary | numeric | NO | |
| effective_date | date | NO | |
| end_date | date | YES | |
| reason | varchar | YES | |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

**Foreign Keys:**
- `employee_id` -> `hr.employees(employee_id)`

### hr.employee_summary (VIEW)
Active employees with department and attendance info.

---

## Schema: inventory

### inventory.warehouses
Warehouse locations.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| warehouse_id | integer | NO | auto |
| name | varchar | NO | |
| location | address_type | YES | |
| capacity_cubic_feet | integer | YES | |
| is_active | boolean | YES | true |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

### inventory.locations
Specific storage locations within warehouses.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| location_id | integer | NO | auto |
| warehouse_id | integer | NO | |
| zone | char | NO | |
| aisle | integer | NO | |
| rack | integer | NO | |
| shelf | integer | NO | |
| bin | varchar | YES | |
| location_code | varchar | NO | UNIQUE |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

**Foreign Keys:**
- `warehouse_id` -> `inventory.warehouses(warehouse_id)`

### inventory.suppliers
Supplier information.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| supplier_id | integer | NO | auto |
| company_name | varchar | NO | |
| contact_name | varchar | YES | |
| email | varchar | YES | |
| phone | varchar | YES | |
| address | address_type | YES | |
| lead_time_days | integer | YES | 7 |
| rating | numeric | YES | 3.0 |
| is_active | boolean | YES | true |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

### inventory.stock
Current inventory levels.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| stock_id | integer | NO | auto |
| product_id | integer | NO | |
| warehouse_id | integer | NO | |
| location_id | integer | YES | |
| quantity_on_hand | integer | YES | 0 |
| quantity_reserved | integer | YES | 0 |
| quantity_available | integer | YES | computed |
| reorder_point | integer | YES | 10 |
| last_restocked_at | timestamp | YES | |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |
| updated_at | timestamp | YES | CURRENT_TIMESTAMP |

**Foreign Keys:**
- `product_id` -> `sales.products(product_id)`
- `warehouse_id` -> `inventory.warehouses(warehouse_id)`
- `location_id` -> `inventory.locations(location_id)`

### inventory.stock_movements
Inventory movement history.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| movement_id | integer | NO | auto |
| product_id | integer | NO | |
| from_warehouse_id | integer | YES | |
| to_warehouse_id | integer | YES | |
| movement_type | varchar | NO | |
| quantity | integer | NO | |
| reference_type | varchar | YES | |
| reference_id | varchar | YES | |
| notes | text | YES | |
| movement_date | timestamp | YES | CURRENT_TIMESTAMP |
| created_by | varchar | YES | |

### inventory.purchase_orders
Purchase orders to suppliers.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| po_id | integer | NO | auto |
| supplier_id | integer | NO | |
| warehouse_id | integer | NO | |
| po_number | varchar | NO | UNIQUE |
| status | varchar | YES | 'draft' |
| expected_delivery | date | YES | |
| actual_delivery | date | YES | |
| notes | text | YES | |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

### inventory.po_items
Line items in purchase orders.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| po_item_id | integer | NO | auto |
| po_id | integer | NO | |
| product_id | integer | NO | |
| quantity | integer | NO | |
| unit_cost | numeric | NO | |
| received_quantity | integer | YES | 0 |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

### inventory.product_suppliers
Products and their suppliers (many-to-many).

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| product_id | integer | NO | |
| supplier_id | integer | NO | |
| is_primary | boolean | YES | false |
| lead_time_days | integer | YES | 7 |
| unit_cost | numeric | NO | |
| min_order_quantity | integer | YES | 1 |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

### inventory.inventory_status (VIEW)
Product stock status by warehouse.

### inventory.supplier_performance (VIEW)
Supplier metrics.

---

## Schema: sales

### sales.customers
Customer accounts.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| customer_id | integer | NO | auto |
| first_name | varchar | NO | |
| last_name | varchar | NO | |
| email | varchar | NO | UNIQUE |
| phone | varchar | YES | |
| role | user_role | YES | 'customer' |
| loyalty_points | integer | YES | 0 |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |
| updated_at | timestamp | YES | CURRENT_TIMESTAMP |

### sales.customer_addresses
Customer shipping/billing addresses.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| address_id | integer | NO | auto |
| customer_id | integer | NO | |
| address_type | varchar | YES | 'shipping' |
| address | address_type | YES | |
| is_default | boolean | YES | false |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

### sales.products
Products for sale.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| product_id | integer | NO | auto |
| sku | varchar | NO | UNIQUE |
| name | varchar | NO | |
| description | text | YES | |
| base_price | numeric | NO | |
| tax_rate | numeric | YES | 0.08 |
| is_active | boolean | YES | true |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |
| updated_at | timestamp | YES | CURRENT_TIMESTAMP |

### sales.orders
Customer orders.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| order_id | integer | NO | auto |
| customer_id | integer | NO | |
| order_number | varchar | NO | UNIQUE |
| status | order_status | YES | 'pending' |
| subtotal | numeric | NO | 0 |
| tax_amount | numeric | YES | 0 |
| shipping_cost | numeric | YES | 0 |
| total_amount | numeric | NO | 0 |
| discount_amount | numeric | YES | 0 |
| notes | text | YES | |
| ordered_at | timestamp | YES | CURRENT_TIMESTAMP |
| confirmed_at | timestamp | YES | |
| shipped_at | timestamp | YES | |
| delivered_at | timestamp | YES | |

**Foreign Keys:**
- `customer_id` -> `sales.customers(customer_id)`

### sales.order_items
Order line items.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| item_id | integer | NO | auto |
| order_id | integer | NO | |
| product_id | integer | NO | |
| quantity | integer | NO | |
| unit_price | numeric | NO | |
| discount_percent | numeric | YES | 0 |
| total_price | numeric | NO | |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

**Foreign Keys:**
- `order_id` -> `sales.orders(order_id)`
- `product_id` -> `sales.products(product_id)`

### sales.payments
Order payments.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| payment_id | integer | NO | auto |
| order_id | integer | NO | |
| payment_method | varchar | NO | |
| amount | numeric | NO | |
| payment_status | payment_status | YES | 'pending' |
| transaction_id | varchar | YES | |
| paid_at | timestamp | YES | |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

### sales.discounts
Discount codes.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| discount_id | integer | NO | auto |
| code | varchar | NO | UNIQUE |
| description | varchar | YES | |
| discount_type | varchar | NO | |
| discount_value | numeric | NO | |
| min_order_amount | numeric | YES | 0 |
| max_discount_amount | numeric | YES | |
| usage_limit | integer | YES | |
| usage_count | integer | YES | 0 |
| valid_from | timestamp | NO | |
| valid_until | timestamp | NO | |
| is_active | boolean | YES | true |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

### sales.pricing_tiers
Volume-based pricing.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| tier_id | integer | NO | auto |
| product_id | integer | NO | |
| min_quantity | integer | NO | |
| max_quantity | integer | YES | |
| price_multiplier | numeric | YES | 1.00 |
| created_at | timestamp | YES | CURRENT_TIMESTAMP |

### sales.customer_orders (VIEW)
Customer order summary.

### sales.order_details (VIEW)
Detailed order information with products.

---

## Enum Types

### order_status
pending, confirmed, processing, shipped, delivered, cancelled, refunded

### payment_status
pending, completed, failed, refunded

### user_role
customer, admin, moderator, vendor

### address_type (composite)
Composite type for addresses.

---

## Common Query Patterns

### Top customers by spending
```sql
SELECT c.customer_id, c.first_name, c.last_name,
       SUM(o.total_amount) as total_spent, COUNT(o.order_id) as order_count
FROM sales.customers c
JOIN sales.orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 10;
```

### Low stock alerts
```sql
SELECT p.sku, p.name, s.quantity_available, s.reorder_point, w.name as warehouse
FROM inventory.stock s
JOIN sales.products p ON s.product_id = p.product_id
JOIN inventory.warehouses w ON s.warehouse_id = w.warehouse_id
WHERE s.quantity_available <= s.reorder_point;
```

### Employee salary by department
```sql
SELECT d.name as department, COUNT(e.employee_id) as employees,
       AVG(e.salary) as avg_salary, SUM(e.salary) as total_salary
FROM hr.departments d
LEFT JOIN hr.employees e ON d.department_id = e.department_id AND e.is_active = true
GROUP BY d.department_id, d.name
ORDER BY total_salary DESC;
```

### Monthly sales trend
```sql
SELECT DATE_TRUNC('month', ordered_at) as month,
       COUNT(*) as orders, SUM(total_amount) as revenue
FROM sales.orders
WHERE status NOT IN ('cancelled', 'refunded')
GROUP BY DATE_TRUNC('month', ordered_at)
ORDER BY month;
```
