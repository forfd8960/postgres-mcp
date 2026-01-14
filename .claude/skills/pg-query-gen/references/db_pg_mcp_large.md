# Database: db_pg_mcp_large

A large-scale e-commerce platform database with comprehensive modules.

## Connection Info
- Host: localhost
- Port: 5432
- User: postgres
- Password: postgres
- Schemas: accounts, analytics, catalog, inventory, logistics, marketing, orders, payments, shipping, support

---

## Schema: accounts

### accounts.users
User accounts with authentication info.

| Column | Type | Nullable |
|--------|------|----------|
| user_id | integer | NO |
| username | varchar | NO (UNIQUE) |
| email | varchar | NO (UNIQUE) |
| password_hash | varchar | NO |
| first_name | varchar | YES |
| last_name | varchar | YES |
| phone | varchar | YES |
| status | user_status | YES |
| role | user_role | YES |
| profile_image_url | varchar | YES |
| timezone | varchar | YES |
| language | varchar | YES |
| email_verified | boolean | YES |
| two_factor_enabled | boolean | YES |
| last_login_at | timestamp | YES |
| created_at | timestamp | YES |
| updated_at | timestamp | YES |
| deleted_at | timestamp | YES |

### accounts.profiles
Extended user profile information.

| Column | Type | Nullable |
|--------|------|----------|
| profile_id | integer | NO |
| user_id | integer | NO (UNIQUE) |
| date_of_birth | date | YES |
| gender | varchar | YES |
| bio | text | YES |
| company | varchar | YES |
| job_title | varchar | YES |
| social_links | jsonb | YES |
| preferences | jsonb | YES |

### accounts.addresses
User addresses for shipping/billing.

| Column | Type | Nullable |
|--------|------|----------|
| address_id | integer | NO |
| user_id | integer | NO |
| address_type | varchar | YES |
| is_default | boolean | YES |
| recipient_name | varchar | YES |
| street_address | varchar | NO |
| apartment_unit | varchar | YES |
| city | varchar | NO |
| state_province | varchar | YES |
| postal_code | varchar | NO |
| country | varchar | NO |
| delivery_instructions | text | YES |

### accounts.sessions
Active user sessions.

### accounts.auth_logs
Authentication event logging.

### accounts.verifications
Email/phone verification tokens.

### accounts.user_preferences
User notification and display preferences.

### accounts.wishlists / accounts.wishlist_items
User wishlists and items.

### accounts.customer_summary (VIEW)
Customer overview with order stats.

---

## Schema: catalog

### catalog.products
Main product catalog.

| Column | Type | Nullable |
|--------|------|----------|
| product_id | integer | NO |
| sku | varchar | NO (UNIQUE) |
| name | varchar | NO |
| slug | varchar | NO (UNIQUE) |
| description | text | YES |
| short_description | text | YES |
| brand_id | integer | YES |
| base_price | numeric | NO |
| cost_price | numeric | YES |
| tax_class | varchar | YES |
| status | product_status | YES |
| requires_shipping | boolean | YES |
| weight | numeric | YES |
| length/width/height | numeric | YES |
| meta_title | varchar | YES |
| meta_description | text | YES |
| average_rating | numeric | YES |
| review_count | integer | YES |
| view_count | integer | YES |
| sale_count | integer | YES |
| created_at | timestamp | YES |
| published_at | timestamp | YES |
| deleted_at | timestamp | YES |

### catalog.brands
Product brands.

### catalog.categories
Hierarchical product categories (parent_id self-reference).

### catalog.product_categories
Many-to-many product-category relationship.

### catalog.product_images
Product images with display order.

### catalog.product_tags / catalog.tags
Product tagging system.

### catalog.product_variant_attrs
Product variants (size, color, etc.) with attributes stored as JSONB.

### catalog.attributes / catalog.attribute_values
Filterable product attributes.

### catalog.reviews
Product reviews with ratings.

### catalog.active_products (VIEW)
Active products with brand and primary category.

---

## Schema: inventory

### inventory.warehouses
Warehouse locations with capacity.

### inventory.locations
Storage locations within warehouses (zone/aisle/rack/shelf/bin).

### inventory.items
Current inventory by product/warehouse/location.

| Column | Type | Nullable |
|--------|------|----------|
| item_id | integer | NO |
| product_id | integer | NO |
| warehouse_id | integer | NO |
| location_id | integer | YES |
| quantity_on_hand | integer | YES |
| quantity_reserved | integer | YES |
| quantity_available | integer | YES |
| reorder_point | integer | YES |
| max_stock_level | integer | YES |

### inventory.adjustments
Inventory adjustments with audit trail.

### inventory.movements
Stock movement history.

### inventory.transfers / inventory.transfer_items
Inter-warehouse transfers.

### inventory.reports
Inventory reports.

### inventory.inventory_summary (VIEW)
Stock status overview.

---

## Schema: orders

### orders.orders
Customer orders.

| Column | Type | Nullable |
|--------|------|----------|
| order_id | integer | NO |
| order_number | varchar | NO (UNIQUE) |
| user_id | integer | NO |
| status | order_status | YES |
| subtotal | numeric | NO |
| discount_amount | numeric | YES |
| tax_amount | numeric | YES |
| shipping_amount | numeric | YES |
| total_amount | numeric | NO |
| currency | varchar | YES |
| shipping_address_id | integer | YES |
| billing_address_id | integer | YES |
| notes | text | YES |
| metadata | jsonb | YES |
| created_at | timestamp | YES |
| updated_at | timestamp | YES |
| cancelled_at | timestamp | YES |

### orders.order_items
Order line items with product/variant info.

| Column | Type | Nullable |
|--------|------|----------|
| item_id | integer | NO |
| order_id | integer | NO |
| product_id | integer | NO |
| variant_id | integer | YES |
| sku | varchar | NO |
| name | varchar | NO |
| quantity | integer | NO |
| unit_price | numeric | NO |
| discount_amount | numeric | YES |
| tax_amount | numeric | YES |
| total_amount | numeric | NO |

### orders.status_history
Order status changes with user tracking.

### orders.notes
Internal order notes.

### orders.discounts
Order-level discounts applied.

### orders.subscriptions / orders.subscription_history
Recurring order subscriptions.

### orders.quote_requests
B2B quote requests.

### orders.order_summary (VIEW)
Order overview with customer info.

---

## Schema: payments

### payments.payments
Payment transactions.

| Column | Type | Nullable |
|--------|------|----------|
| payment_id | integer | NO |
| order_id | integer | NO |
| user_id | integer | NO |
| payment_method | payment_method | NO |
| amount | numeric | NO |
| currency | varchar | YES |
| status | payment_status | YES |
| transaction_id | varchar | YES |
| gateway_response | jsonb | YES |
| metadata | jsonb | YES |
| created_at | timestamp | YES |
| completed_at | timestamp | YES |

### payments.refunds
Refund processing.

### payments.invoices
Invoice generation.

### payments.disputes
Payment disputes.

### payments.user_payment_methods
Saved payment methods.

### payments.payment_summary (VIEW)
Payment analytics.

---

## Schema: shipping

### shipping.carriers
Shipping carriers (FedEx, UPS, etc.).

### shipping.methods
Shipping methods by carrier.

### shipping.shipments
Shipment tracking.

| Column | Type | Nullable |
|--------|------|----------|
| shipment_id | integer | NO |
| order_id | integer | NO |
| carrier_id | integer | YES |
| method_id | integer | YES |
| tracking_number | varchar | YES |
| status | shipping_status | YES |
| label_url | varchar | YES |
| ship_date | timestamp | YES |
| estimated_delivery | timestamp | YES |
| actual_delivery | timestamp | YES |
| shipping_cost | numeric | YES |

### shipping.events
Shipment tracking events.

### shipping.returns
Return processing.

### shipping.rates_cache
Cached shipping rates.

### shipping.shipping_status (VIEW)
Shipment status overview.

---

## Schema: logistics

### logistics.shipping_zones
Geographic shipping zones.

### logistics.zone_rates
Shipping rates by zone/carrier/method.

### logistics.delivery_slots
Available delivery time slots.

---

## Schema: marketing

### marketing.promotions
Promotional campaigns.

### marketing.promotion_rules
Promotion conditions and rules.

### marketing.coupons
Discount coupon codes.

### marketing.campaigns
Email/notification campaigns.

### marketing.subscribers
Newsletter subscribers.

---

## Schema: analytics

### analytics.daily_metrics
Daily aggregate metrics.

### analytics.page_views
User page view tracking.

### analytics.product_analytics
Product performance metrics.

### analytics.sales_by_day (VIEW)
Daily sales summary.

### analytics.top_products (VIEW)
Best-selling products.

### analytics.cart_abandonment (VIEW)
Cart abandonment analysis.

### analytics.customer_retention (VIEW)
Customer retention metrics.

---

## Schema: support

### support.tickets
Customer support tickets.

| Column | Type | Nullable |
|--------|------|----------|
| ticket_id | integer | NO |
| user_id | integer | NO |
| order_id | integer | YES |
| subject | varchar | NO |
| description | text | NO |
| status | varchar | YES |
| priority | varchar | YES |
| category | varchar | YES |
| assigned_to | integer | YES |
| created_at | timestamp | YES |
| updated_at | timestamp | YES |
| resolved_at | timestamp | YES |

### support.messages
Ticket messages/replies.

### support.ticket_stats (VIEW)
Ticket statistics.

---

## Enum Types

### user_status
active, inactive, suspended, pending_verification

### user_role
customer, vendor, admin, super_admin, affiliate

### product_status
draft, active, inactive, discontinued, out_of_stock

### order_status
pending, confirmed, processing, shipped, delivered, cancelled, refunded

### payment_method
credit_card, debit_card, paypal, bank_transfer, apple_pay, google_pay

### payment_status
pending, completed, failed, refunded, disputed

### shipping_status
label_created, in_transit, out_for_delivery, delivered, returned, exception

### refund_status
requested, approved, rejected, processed, completed

---

## Cross-Schema Relationships

- accounts.users is the central user table referenced by most other schemas
- catalog.products is referenced by orders.order_items, inventory.items, analytics.product_analytics
- orders.orders links to payments.payments, shipping.shipments, support.tickets
- inventory.warehouses is used by logistics.delivery_slots

---

## Common Query Patterns

### Customer lifetime value
```sql
SELECT u.user_id, u.username, u.email,
       COUNT(o.order_id) as total_orders,
       SUM(o.total_amount) as lifetime_value,
       AVG(o.total_amount) as avg_order_value
FROM accounts.users u
JOIN orders.orders o ON u.user_id = o.user_id
WHERE o.status NOT IN ('cancelled', 'refunded')
GROUP BY u.user_id
ORDER BY lifetime_value DESC;
```

### Product performance
```sql
SELECT p.product_id, p.sku, p.name, p.base_price,
       COALESCE(SUM(oi.quantity), 0) as units_sold,
       COALESCE(SUM(oi.total_amount), 0) as revenue,
       p.average_rating, p.review_count
FROM catalog.products p
LEFT JOIN orders.order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders.orders o ON oi.order_id = o.order_id
    AND o.status NOT IN ('cancelled', 'refunded')
WHERE p.status = 'active'
GROUP BY p.product_id
ORDER BY revenue DESC;
```

### Inventory alerts
```sql
SELECT p.sku, p.name, i.warehouse_id, w.name as warehouse,
       i.quantity_available, i.reorder_point
FROM inventory.items i
JOIN catalog.products p ON i.product_id = p.product_id
JOIN inventory.warehouses w ON i.warehouse_id = w.warehouse_id
WHERE i.quantity_available <= i.reorder_point
ORDER BY i.quantity_available ASC;
```

### Daily revenue
```sql
SELECT DATE(created_at) as date,
       COUNT(*) as orders,
       SUM(total_amount) as revenue
FROM orders.orders
WHERE status NOT IN ('cancelled', 'refunded')
  AND created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date;
```

### Support ticket backlog
```sql
SELECT status, priority, COUNT(*) as count,
       AVG(EXTRACT(EPOCH FROM (COALESCE(resolved_at, NOW()) - created_at))/3600) as avg_hours
FROM support.tickets
GROUP BY status, priority
ORDER BY priority, status;
```
