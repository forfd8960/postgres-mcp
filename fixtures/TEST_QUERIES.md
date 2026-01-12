# pg-mcp Natural Language Query Test Cases

This document contains natural language query examples for testing PostgreSQL MCP server's SQL generation capability across three test databases:
- **Small Database** (`db_pg_mcp_small`): 5 tables, 2 views, testbed schema
- **Medium Database** (`db_pg_mcp_medium`): 20 tables, 5 views, sales/inventory/hr schemas
- **Large Database** (`db_pg_mcp_large`): More complex schema with additional features

---

## Table of Contents

1. [Simple Queries](#simple-queries)
2. [Medium Queries](#medium-queries)
3. [Complex Queries](#complex-queries)
4. [Advanced Queries](#advanced-queries)

---

## Simple Queries

Basic SELECT statements with single table queries, simple filters, and basic aggregations.

### Small Database (testbed schema)

* **case 1: Count all users**
    自然语言：有多少用户？
    期望 SQL：SELECT COUNT(*) FROM testbed.users;

* **case 2: List all products**
    自然语言：列出所有产品名称和价格
    期望 SQL：SELECT name, price FROM testbed.products;

* **case 3: Find active users**
    自然语言：查找所有状态为active的用户
    期望 SQL：SELECT * FROM testbed.users WHERE status = 'active';

* **case 4: Get product by ID**
    自然语言：获取ID为1的产品信息
    期望 SQL：SELECT * FROM testbed.products WHERE id = 1;

* **case 5: Count orders**
    自然语言：有多少个订单？
    期望 SQL：SELECT COUNT(*) FROM testbed.orders;

* **case 6: List product categories**
    自然语言：列出所有产品类别
    期望 SQL：SELECT DISTINCT category FROM testbed.products;

* **case 7: Get users by status**
    自然语言：查找所有状态为inactive的用户
    期望 SQL：SELECT * FROM testbed.users WHERE status = 'inactive';

* **case 8: Count products by category**
    自然语言：每个类别有多少产品？
    期望 SQL：SELECT category, COUNT(*) FROM testbed.products GROUP BY category;

* **case 9: List orders with pending status**
    自然语言：查找所有状态为pending的订单
    期望 SQL：SELECT * FROM testbed.orders WHERE status = 'pending';

* **case 10: Get top 5 expensive products**
    自然语言：价格最高的前5个产品
    期望 SQL：SELECT * FROM testbed.products ORDER BY price DESC LIMIT 5;

### Medium Database (sales/inventory/hr schemas)

* **case 11: Count all customers**
    自然语言：有多少客户？
    期望 SQL：SELECT COUNT(*) FROM sales.customers;

* **case 12: List all products with prices**
    自然语言：列出所有产品的名称和基础价格
    期望 SQL：SELECT name, base_price FROM sales.products;

* **case 13: Find active products**
    自然语言：查找所有is_active为true的产品
    期望 SQL：SELECT * FROM sales.products WHERE is_active = true;

* **case 14: Get employees by department**
    自然语言：查找Engineering部门的员工
    期望 SQL：SELECT * FROM hr.employees WHERE department_id = (SELECT department_id FROM hr.departments WHERE name = 'Engineering');

* **case 15: Count orders by status**
    自然语言：按状态统计订单数量
    期望 SQL：SELECT status, COUNT(*) FROM sales.orders GROUP BY status;

* **case 16: List warehouses**
    自然语言：列出所有仓库名称
    期望 SQL：SELECT name FROM inventory.warehouses;

* **case 17: Find high-value customers**
    自然语言：loyalty_points大于300的客户
    期望 SQL：SELECT * FROM sales.customers WHERE loyalty_points > 300;

* **case 18: Get product stock levels**
    自然语言：获取产品的库存数量
    期望 SQL：SELECT product_id, SUM(quantity_available) FROM inventory.stock GROUP BY product_id;

* **case 19: List suppliers**
    自然语言：列出所有供应商公司名称
    期望 SQL：SELECT company_name FROM inventory.suppliers;

* **case 20: Count departments**
    自然语言：有多少个部门？
    期望 SQL：SELECT COUNT(*) FROM hr.departments;

---

## Medium Queries

Intermediate queries with JOINs, subqueries, multiple conditions, and more complex aggregations.

### Small Database (testbed schema)

* **case 21: Get user orders with user details**
    自然语言：获取每个用户及其所有订单
    期望 SQL：SELECT u.*, o.* FROM testbed.users u LEFT JOIN testbed.orders o ON u.id = o.user_id;

* **case 22: Get order items with product info**
    自然语言：获取订单明细及对应的产品信息
    期望 SQL：SELECT oi.*, p.name, p.price FROM testbed.order_items oi JOIN testbed.products p ON oi.product_id = p.id;

* **case 23: Find users with orders**
    自然语言：查找有订单的用户
    期望 SQL：SELECT DISTINCT u.* FROM testbed.users u JOIN testbed.orders o ON u.id = o.user_id;

* **case 24: Calculate total order amount per user**
    自然语言：计算每个用户的订单总金额
    期望 SQL：SELECT u.username, SUM(o.total_amount) as total FROM testbed.users u LEFT JOIN testbed.orders o ON u.id = o.user_id GROUP BY u.id, u.username;

* **case 25: Get product with category**
    自然语言：获取产品及其所属类别
    期望 SQL：SELECT p.*, c.name as category_name FROM testbed.products p LEFT JOIN testbed.categories c ON p.category = c.name;

* **case 26: Find products in specific category**
    自然语言：查找Laptops类别的所有产品
    期望 SQL：SELECT * FROM testbed.products WHERE category = 'Laptops';

* **case 27: Get completed orders with user email**
    自然语言：获取已完成订单的用户邮箱
    期望 SQL：SELECT o.*, u.email FROM testbed.orders o JOIN testbed.users u ON o.user_id = u.id WHERE o.status = 'completed';

* **case 28: Count order items per order**
    自然语言：统计每个订单的商品数量
    期望 SQL：SELECT order_id, COUNT(*) as item_count, SUM(quantity) as total_quantity FROM testbed.order_items GROUP BY order_id;

* **case 29: Get users without orders**
    自然语言：查找没有任何订单的用户
    期望 SQL：SELECT * FROM testbed.users WHERE id NOT IN (SELECT user_id FROM testbed.orders);

* **case 30: Calculate average product price per category**
    自然语言：计算每个类别的平均产品价格
    期望 SQL：SELECT category, AVG(price) as avg_price FROM testbed.products GROUP BY category;

### Medium Database (sales/inventory/hr schemas)

* **case 31: Get customer with all their orders**
    自然语言：获取客户及其所有订单信息
    期望 SQL：SELECT c.*, o.* FROM sales.customers c LEFT JOIN sales.orders o ON c.customer_id = o.customer_id;

* **case 32: Get order with customer details**
    自然语言：获取订单及对应的客户信息
    期望 SQL：SELECT o.*, c.first_name, c.last_name, c.email FROM sales.orders o JOIN sales.customers c ON o.customer_id = c.customer_id;

* **case 33: Get products with inventory levels**
    自然语言：获取产品及库存信息
    期望 SQL：SELECT p.*, COALESCE(SUM(s.quantity_available), 0) as total_available FROM sales.products p LEFT JOIN inventory.stock s ON p.product_id = s.product_id GROUP BY p.product_id;

* **case 34: Find employees and their departments**
    自然语言：获取员工及其所属部门
    期望 SQL：SELECT e.*, d.name as department_name FROM hr.employees e LEFT JOIN hr.departments d ON e.department_id = d.department_id;

* **case 35: Get order items with product names**
    自然语言：获取订单明细及产品名称
    期望 SQL：SELECT oi.*, p.name as product_name FROM sales.order_items oi JOIN sales.products p ON oi.product_id = p.product_id;

* **case 36: Calculate total spent per customer**
    自然语言：计算每个客户的总消费金额
    期望 SQL：SELECT c.customer_id, c.first_name, c.last_name, COALESCE(SUM(o.total_amount), 0) as total_spent FROM sales.customers c LEFT JOIN sales.orders o ON c.customer_id = o.customer_id GROUP BY c.customer_id, c.first_name, c.last_name;

* **case 37: Get stock levels per warehouse**
    自然语言：获取每个仓库的库存详情
    期望 SQL：SELECT w.name as warehouse, p.name as product, s.quantity_available FROM inventory.stock s JOIN inventory.warehouses w ON s.warehouse_id = w.warehouse_id JOIN sales.products p ON s.product_id = p.product_id;

* **case 38: Find suppliers for a product**
    自然语言：查找某个产品的所有供应商
    期望 SQL：SELECT s.*, ps.is_primary, ps.unit_cost FROM inventory.suppliers s JOIN inventory.product_suppliers ps ON s.supplier_id = ps.supplier_id WHERE ps.product_id = 1;

* **case 39: Get customer addresses**
    自然语言：获取客户的地址信息
    期望 SQL：SELECT c.*, ca.address, ca.address_type FROM sales.customers c LEFT JOIN sales.customer_addresses ca ON c.customer_id = ca.customer_id;

* **case 40: Calculate average salary per department**
    自然语言：计算每个部门的平均工资
    期望 SQL：SELECT d.name as department, AVG(e.salary) as avg_salary FROM hr.departments d LEFT JOIN hr.employees e ON d.department_id = e.department_id GROUP BY d.department_id, d.name;

---

## Complex Queries

Advanced queries with CTEs, window functions, complex aggregations, and multi-level JOINs.

### Small Database (testbed schema)

* **case 41: Get users with order summary using CTE**
    自然语言：使用CTE获取用户及其订单统计
    期望 SQL：WITH user_orders AS (SELECT user_id, COUNT(*) as order_count, SUM(total_amount) as total_spent FROM testbed.orders GROUP BY user_id) SELECT u.*, COALESCE(uo.order_count, 0) as order_count, COALESCE(uo.total_spent, 0) as total_spent FROM testbed.users u LEFT JOIN user_orders uo ON u.id = uo.user_id;

* **case 42: Get products with stock value**
    自然语言：计算每个产品的库存总价值
    期望 SQL：SELECT p.id, p.name, p.price, p.stock_quantity, (p.price * p.stock_quantity) as stock_value FROM testbed.products p;

* **case 43: Rank users by total spending**
    自然语言：根据消费金额对用户排名
    期望 SQL：SELECT u.id, u.username, SUM(o.total_amount) as total_spent, RANK() OVER (ORDER BY SUM(o.total_amount) DESC) as rank FROM testbed.users u LEFT JOIN testbed.orders o ON u.id = o.user_id GROUP BY u.id, u.username ORDER BY total_spent DESC;

* **case 44: Get order totals with running total**
    自然语言：获取订单及其累计金额
    期望 SQL：SELECT o.id, o.created_at, o.total_amount, SUM(o.total_amount) OVER (ORDER BY o.created_at) as running_total FROM testbed.orders o WHERE o.status = 'completed' ORDER BY o.created_at;

* **case 45: Find top 3 selling products**
    自然语言：找出销量最高的前3个产品
    期望 SQL：SELECT p.id, p.name, SUM(oi.quantity) as total_sold FROM testbed.products p JOIN testbed.order_items oi ON p.id = oi.product_id GROUP BY p.id, p.name ORDER BY total_sold DESC LIMIT 3;

* **case 46: Get monthly order statistics**
    自然语言：获取每月订单统计
    期望 SQL：SELECT DATE_TRUNC('month', created_at) as month, COUNT(*) as order_count, SUM(total_amount) as total_revenue FROM testbed.orders GROUP BY DATE_TRUNC('month', created_at) ORDER BY month;

* **case 47: Find customers with multiple orders**
    自然语言：查找有多笔订单的客户
    期望 SQL：SELECT u.id, u.username, COUNT(o.id) as order_count FROM testbed.users u JOIN testbed.orders o ON u.id = o.user_id GROUP BY u.id, u.username HAVING COUNT(o.id) > 1;

* **case 48: Get product performance analysis**
    自然语言：获取产品销售表现分析
    期望 SQL：SELECT p.id, p.name, p.price, p.stock_quantity, COALESCE(SUM(oi.quantity), 0) as units_sold, COALESCE(SUM(oi.quantity * oi.price), 0) as revenue FROM testbed.products p LEFT JOIN testbed.order_items oi ON p.id = oi.product_id GROUP BY p.id, p.name, p.price, p.stock_quantity;

* **case 49: Find orders with high-value items**
    自然语言：查找包含高价商品的订单
    期望 SQL：SELECT DISTINCT o.* FROM testbed.orders o JOIN testbed.order_items oi ON o.id = oi.order_id JOIN testbed.products p ON oi.product_id = p.id WHERE p.price > 100;

* **case 50: Get category hierarchy**
    自然语言：获取类别层级结构
    期望 SQL：SELECT c1.id, c1.name, c1.parent_id, c2.name as parent_name FROM testbed.categories c1 LEFT JOIN testbed.categories c2 ON c1.parent_id = c2.id;

### Medium Database (sales/inventory/hr schemas)

* **case 51: Get customer lifetime value**
    自然语言：计算客户终身价值
    期望 SQL：WITH customer_stats AS (SELECT customer_id, COUNT(*) as total_orders, SUM(total_amount) as total_spent, MAX(ordered_at) as last_order FROM sales.orders GROUP BY customer_id) SELECT c.*, COALESCE(cs.total_orders, 0) as orders, COALESCE(cs.total_spent, 0) as lifetime_value FROM sales.customers c LEFT JOIN customer_stats cs ON c.customer_id = cs.customer_id;

* **case 52: Get product revenue ranking**
    自然语言：获取产品收入排名
    期望 SQL：SELECT p.product_id, p.name, SUM(oi.quantity * oi.total_price) as total_revenue, RANK() OVER (ORDER BY SUM(oi.quantity * oi.total_price) DESC) as revenue_rank FROM sales.products p LEFT JOIN sales.order_items oi ON p.product_id = oi.product_id GROUP BY p.product_id, p.name ORDER BY revenue_rank;

* **case 53: Calculate warehouse utilization**
    自然语言：计算仓库利用率
    期望 SQL：SELECT w.name, w.capacity_cubic_feet, COALESCE(SUM(s.quantity_on_hand * 10), 0) as used_capacity, (COALESCE(SUM(s.quantity_on_hand * 10), 0) / w.capacity_cubic_feet * 100) as utilization_percent FROM inventory.warehouses w LEFT JOIN inventory.stock s ON w.warehouse_id = s.warehouse_id GROUP BY w.warehouse_id, w.name, w.capacity_cubic_feet;

* **case 54: Get employee tenure and salary analysis**
    自然语言：获取员工任期和薪资分析
    期望 SQL：SELECT e.*, d.name as department, EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.hire_date)) as years_tenure, (e.salary / NULLIF(EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.hire_date)), 0)) as salary_per_year FROM hr.employees e LEFT JOIN hr.departments d ON e.department_id = d.department_id;

* **case 55: Get order fulfillment time**
    自然语言：计算订单履约时间
    期望 SQL：SELECT o.order_id, o.order_number, o.status, o.ordered_at, o.shipped_at, o.delivered_at, CASE WHEN o.status = 'delivered' THEN o.delivered_at - o.ordered_at END as fulfillment_time FROM sales.orders o;

* **case 56: Analyze stock movement trends**
    自然语言：分析库存移动趋势
    期望 SQL：SELECT product_id, movement_type, DATE_TRUNC('day', movement_date) as day, SUM(quantity) as total_quantity FROM inventory.stock_movements GROUP BY product_id, movement_type, DATE_TRUNC('day', movement_date) ORDER BY day;

* **case 57: Get supplier performance metrics**
    自然语言：获取供应商绩效指标
    期望 SQL：SELECT s.supplier_id, s.company_name, s.rating, s.lead_time_days, COUNT(DISTINCT ps.product_id) as product_count, AVG(ps.unit_cost) as avg_cost FROM inventory.suppliers s LEFT JOIN inventory.product_suppliers ps ON s.supplier_id = ps.supplier_id GROUP BY s.supplier_id, s.company_name, s.rating, s.lead_time_days;

* **case 58: Calculate customer loyalty tiers**
    自然语言：计算客户忠诚度等级
    期望 SQL：SELECT customer_id, first_name, last_name, loyalty_points, CASE WHEN loyalty_points >= 500 THEN 'Platinum' WHEN loyalty_points >= 300 THEN 'Gold' WHEN loyalty_points >= 100 THEN 'Silver' ELSE 'Bronze' END as loyalty_tier FROM sales.customers;

* **case 59: Get monthly revenue by category**
    自然语言：按类别统计月度收入
    期望 SQL：SELECT DATE_TRUNC('month', o.ordered_at) as month, p.category, SUM(oi.quantity * oi.total_price) as revenue FROM sales.orders o JOIN sales.order_items oi ON o.order_id = oi.order_id JOIN sales.products p ON oi.product_id = p.product_id GROUP BY DATE_TRUNC('month', o.ordered_at), p.category ORDER BY month, revenue DESC;

* **case 60: Find employees with attendance issues**
    自然语言：查找有考勤问题的员工
    期望 SQL：SELECT e.*, COUNT(a.attendance_id) as days_present, SUM(a.overtime_hours) as total_overtime FROM hr.employees e LEFT JOIN hr.attendance a ON e.employee_id = a.employee_id GROUP BY e.employee_id HAVING COUNT(a.attendance_id) < 15;

---

## Advanced Queries

Expert-level queries with recursive CTEs, complex window functions, JSON operations, and advanced analytics.

### Small Database (testbed schema)

* **case 61: Get category tree with recursive CTE**
    自然语言：使用递归CTE获取完整的类别树
    期望 SQL：WITH RECURSIVE category_tree AS (SELECT id, name, parent_id, 0 as level FROM testbed.categories WHERE parent_id IS NULL UNION ALL SELECT c.id, c.name, c.parent_id, ct.level + 1 FROM testbed.categories c JOIN category_tree ct ON c.parent_id = ct.id) SELECT * FROM category_tree ORDER BY level, name;

* **case 72: Analyze user purchase patterns**
    自然语言：分析用户购买模式
    期望 SQL：SELECT u.id, u.username, COUNT(DISTINCT DATE(o.created_at)) as unique_purchase_days, AVG(o.total_amount) as avg_order_value, SUM(o.total_amount) as total_spent FROM testbed.users u JOIN testbed.orders o ON u.id = o.user_id GROUP BY u.id, u.username;

* **case 73: Product recommendation based on co-purchase**
    自然语言：基于共同购买的产品推荐分析
    期望 SQL：SELECT p1.id as product_id, p1.name as product_name, p2.id as recommended_id, p2.name as recommended_name, COUNT(*) as co_purchase_count FROM testbed.order_items oi1 JOIN testbed.order_items oi2 ON oi1.order_id = oi2.order_id AND oi1.product_id != oi2.product_id JOIN testbed.products p1 ON oi1.product_id = p1.id JOIN testbed.products p2 ON oi2.product_id = p2.id GROUP BY p1.id, p1.name, p2.id, p2.name ORDER BY co_purchase_count DESC LIMIT 10;

* **case 74: Calculate customer retention metrics**
    自然语言：计算客户留存率指标
    期望 SQL：WITH first_order AS (SELECT user_id, MIN(created_at) as first_order_date FROM testbed.orders GROUP BY user_id), repeat_customers AS (SELECT user_id, COUNT(*) as order_count FROM testbed.orders GROUP BY user_id HAVING COUNT(*) > 1) SELECT COUNT(*) as total_customers, (SELECT COUNT(*) FROM repeat_customers) as repeat_customers, (SELECT COUNT(*) FROM first_order WHERE first_order_date > CURRENT_DATE - INTERVAL '90 days') as new_customers_90d;

* **case 75: Inventory health analysis**
    自然语言：库存健康度分析
    期望 SQL：SELECT p.id, p.name, p.stock_quantity, p.price, SUM(oi.quantity) as total_sold_30d, CASE WHEN p.stock_quantity = 0 THEN 'Out of Stock' WHEN p.stock_quantity < 10 THEN 'Critical' WHEN p.stock_quantity < 50 THEN 'Low' ELSE 'Healthy' END as stock_health FROM testbed.products p LEFT JOIN testbed.order_items oi ON p.id = oi.product_id AND oi.order_id IN (SELECT id FROM testbed.orders WHERE created_at > CURRENT_DATE - INTERVAL '30 days') GROUP BY p.id, p.name, p.stock_quantity, p.price;

### Medium Database (sales/inventory/hr schemas)

* **case 76: Calculate employee churn risk**
    自然语言：计算员工离职风险
    期望 SQL：WITH emp_stats AS (SELECT e.employee_id, e.first_name, e.last_name, e.salary, e.hire_date, COUNT(a.attendance_id) as work_days, SUM(a.overtime_hours) as total_overtime, MAX(sh.salary) as current_salary, (SELECT salary FROM hr.salary_history WHERE employee_id = e.employee_id AND effective_date < CURRENT_DATE ORDER BY effective_date DESC LIMIT 1) as previous_salary FROM hr.employees e LEFT JOIN hr.attendance a ON e.employee_id = a.employee_id LEFT JOIN hr.salary_history sh ON e.employee_id = sh.employee_id GROUP BY e.employee_id, e.first_name, e.last_name, e.salary, e.hire_date) SELECT *, CASE WHEN total_overtime > 40 THEN 'High Risk' WHEN work_days < 15 THEN 'Medium Risk' ELSE 'Low Risk' END as churn_risk FROM emp_stats;

* **case 77: Supply chain lead time optimization**
    自然语言：供应链交货期优化分析
    期望 SQL：WITH lead_time_analysis AS (SELECT ps.supplier_id, s.company_name, p.name as product_name, ps.lead_time_days, po.expected_delivery, po.actual_delivery, EXTRACT(DAY FROM (po.actual_delivery - po.created_at)) as actual_lead_time FROM inventory.product_suppliers ps JOIN inventory.suppliers s ON ps.supplier_id = s.supplier_id JOIN sales.products p ON ps.product_id = p.product_id JOIN inventory.purchase_orders po ON ps.supplier_id = po.supplier_id) SELECT supplier_id, company_name, AVG(lead_time_days) as avg_quoted_lt, AVG(actual_lead_time) as avg_actual_lt, AVG(actual_lead_time - lead_time_days) as lt_variance FROM lead_time_analysis GROUP BY supplier_id, company_name;

* **case 78: Customer segmentation analysis**
    自然语言：客户细分分析
    期望 SQL：WITH customer_segments AS (SELECT c.customer_id, c.first_name, c.last_name, c.loyalty_points, COUNT(o.order_id) as total_orders, COALESCE(SUM(o.total_amount), 0) as total_spent, MAX(o.ordered_at) as last_purchase, EXTRACT(DAY FROM (CURRENT_DATE - MAX(o.ordered_at))) as days_since_last FROM sales.customers c LEFT JOIN sales.orders o ON c.customer_id = o.customer_id GROUP BY c.customer_id, c.first_name, c.last_name, c.loyalty_points) SELECT *, CASE WHEN total_spent > 1000 AND total_orders > 5 THEN 'VIP' WHEN total_spent > 500 THEN 'Premium' WHEN total_orders > 2 THEN 'Regular' ELSE 'New' END as segment FROM customer_segments;

* **case 79: Inventory turnover analysis**
    自然语言：库存周转率分析
    期望 SQL：WITH inventory_turnover AS (SELECT s.product_id, p.name, SUM(s.quantity_on_hand) as avg_inventory, COALESCE((SELECT SUM(quantity) FROM inventory.stock_movements WHERE product_id = s.product_id AND movement_type = 'out'), 0) as total_sold_90d FROM inventory.stock s JOIN sales.products p ON s.product_id = p.product_id GROUP BY s.product_id, p.name) SELECT *, (total_sold_90d / NULLIF(avg_inventory, 0)) * 4 as annual_turnover_rate FROM inventory_turnover ORDER BY annual_turnover_rate DESC;

* **case 80: Sales forecasting based on historical data**
    自然语言：基于历史数据的销售预测
    期望 SQL：WITH historical_sales AS (SELECT DATE_TRUNC('day', ordered_at) as date, SUM(total_amount) as daily_revenue FROM sales.orders WHERE ordered_at >= CURRENT_DATE - INTERVAL '90 days' GROUP BY DATE_TRUNC('day', ordered_at)), moving_avg AS (SELECT date, daily_revenue, AVG(daily_revenue) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as week_avg FROM historical_sales) SELECT date, daily_revenue, week_avg, LEAD(week_avg, 7) OVER (ORDER BY date) as next_week_forecast FROM moving_avg ORDER BY date DESC LIMIT 7;

* **case 81: Product profitability analysis**
    自然语言：产品盈利分析
    期望 SQL：WITH product_costs AS (SELECT p.product_id, p.name, p.base_price, COALESCE((SELECT AVG(unit_cost) FROM inventory.product_suppliers WHERE product_id = p.product_id), 0) as avg_unit_cost, SUM(oi.quantity) as units_sold, SUM(oi.quantity * oi.total_price) as gross_revenue FROM sales.products p LEFT JOIN sales.order_items oi ON p.product_id = oi.product_id GROUP BY p.product_id, p.name, p.base_price) SELECT *, (base_price - avg_unit_cost) as profit_per_unit, (base_price - avg_unit_cost) / NULLIF(base_price, 0) * 100 as profit_margin_percent, (base_price - avg_unit_cost) * units_sold as total_profit FROM product_costs ORDER BY total_profit DESC;

* **case 82: Warehouse space optimization**
    自然语言：仓库空间优化
    期望 SQL：WITH warehouse_utilization AS (SELECT w.warehouse_id, w.name, w.capacity_cubic_feet, COUNT(DISTINCT s.location_id) as locations_used, COUNT(DISTINCT s.product_id) as products_stored, SUM(s.quantity_on_hand * 2) as estimated_cubic_feet_used FROM inventory.warehouses w LEFT JOIN inventory.stock s ON w.warehouse_id = s.warehouse_id GROUP BY w.warehouse_id, w.name, w.capacity_cubic_feet) SELECT *, (estimated_cubic_feet_used / NULLIF(capacity_cubic_feet, 0) * 100) as utilization_percent, CASE WHEN estimated_cubic_feet_used / NULLIF(capacity_cubic_feet, 0) > 0.8 THEN 'Near Capacity' WHEN estimated_cubic_feet_used / NULLIF(capacity_cubic_feet, 0) > 0.5 THEN 'Moderate' ELSE 'Underutilized' END as space_status FROM warehouse_utilization;

* **case 83: Employee performance scorecard**
    自然语言：员工绩效记分卡
    期望 SQL：WITH emp_metrics AS (SELECT e.employee_id, e.first_name || ' ' || e.last_name as full_name, d.name as department, e.salary, COUNT(DISTINCT a.attendance_id) as work_days, SUM(a.hours_worked) as total_hours, SUM(a.overtime_hours) as overtime, MAX(sh.salary) as current_salary, (SELECT COUNT(*) FROM hr.salary_history WHERE employee_id = e.employee_id) as promotion_count FROM hr.employees e LEFT JOIN hr.departments d ON e.department_id = d.department_id LEFT JOIN hr.attendance a ON e.employee_id = a.employee_id LEFT JOIN hr.salary_history sh ON e.employee_id = sh.employee_id GROUP BY e.employee_id, e.first_name, e.last_name, d.name, e.salary) SELECT *, ROUND((total_hours / NULLIF(work_days, 0))::numeric, 1) as avg_hours_per_day, ROUND((overtime / NULLIF(total_hours, 0) * 100)::numeric, 1) as overtime_percent, ROUND((current_salary / NULLIF(work_days, 0) * 30)::numeric, 2) as daily_cost FROM emp_metrics;

* **case 84: Discount campaign effectiveness**
    自然语言：促销活动效果分析
    期望 SQL：WITH discount_usage AS (SELECT d.discount_id, d.code, d.description, d.discount_type, d.discount_value, COUNT(o.order_id) as times_used, SUM(o.discount_amount) as total_discount_given, SUM(o.total_amount) as total_revenue FROM sales.discounts d LEFT JOIN sales.orders o ON d.code = ANY(string_to_array(o.notes, ' ')) WHERE d.is_active = true GROUP BY d.discount_id, d.code, d.description, d.discount_type, d.discount_value) SELECT *, ROUND((total_revenue / NULLIF(times_used, 0))::numeric, 2) as avg_order_value, ROUND((total_discount_given / NULLIF(total_revenue, 0) * 100)::numeric, 1) as discount_percent FROM discount_usage ORDER BY times_used DESC;

* **case 85: Multi-warehouse stock consolidation**
    自然语言：多仓库库存整合分析
    期望 SQL：WITH warehouse_stock AS (SELECT product_id, SUM(CASE WHEN warehouse_id = 1 THEN quantity_available ELSE 0 END) as east_coast, SUM(CASE WHEN warehouse_id = 2 THEN quantity_available ELSE 0 END) as west_coast, SUM(CASE WHEN warehouse_id = 3 THEN quantity_available ELSE 0 END) as central, SUM(quantity_available) as total_stock FROM inventory.stock GROUP BY product_id) SELECT p.sku, p.name, ws.east_coast, ws.west_coast, ws.central, ws.total_stock, CASE WHEN ws.east_coast = 0 AND ws.west_coast > 10 THEN 'Consolidate to East' WHEN ws.west_coast = 0 AND ws.east_coast > 10 THEN 'Consolidate to West' ELSE 'Balanced' END as recommendation FROM sales.products p JOIN warehouse_stock ws ON p.product_id = ws.product_id WHERE ws.total_stock > 0;

---

## Test Database Reference

### Small Database Schema (testbed)

| Table | Columns | Description |
|-------|---------|-------------|
| users | id, username, email, status, created_at, last_login | User accounts |
| products | id, name, description, price, stock_quantity, category, created_at | Product catalog |
| orders | id, user_id, total_amount, status, created_at, shipped_at | Customer orders |
| order_items | id, order_id, product_id, quantity, price | Order line items |
| categories | id, name, parent_id, description, created_at | Product categories |

### Medium Database Schemas

**sales schema:**
- customers, customer_addresses, products, pricing_tiers, orders, order_items, payments, discounts

**inventory schema:**
- warehouses, locations, stock, stock_movements, suppliers, purchase_orders, po_items, product_suppliers

**hr schema:**
- departments, employees, attendance, salary_history

---

## Running Tests

```bash
# Test against small database
export PG_MCP_POSTGRES_DSN="postgresql://postgres:postgres@localhost:5432/db_pg_mcp_small"
pytest tests/ -k "test_nlq" -v

# Test against medium database
export PG_MCP_POSTGRES_DSN="postgresql://postgres:postgres@localhost:5432/db_pg_mcp_medium"
pytest tests/ -k "test_nlq" -v
```
