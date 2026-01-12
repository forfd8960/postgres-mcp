# =============================================================================
# pg-mcp Test Database Makefile
# Purpose: Rebuild test databases for development and testing
# =============================================================================

# Database connection defaults
DB_HOST ?= localhost
DB_PORT ?= 5432
DB_USER ?= postgres
DB_PASSWORD ?=

# Database names
DB_SMALL := db_pg_mcp_small
DB_MEDIUM := db_pg_mcp_medium
DB_LARGE := db_pg_mcp_large

# PostgreSQL commands
PSQL := psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER)
DROP_DB := $(PSQL) -c "DROP DATABASE IF EXISTS"
CREATE_DB := $(PSQL) -c "CREATE DATABASE"

# SQL files
SQL_SMALL := 01_small_database.sql
SQL_MEDIUM := 02_medium_database.sql
SQL_LARGE := 03_large_database.sql

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.PHONY: help
help:
	@echo ""
	@echo "pg-mcp Test Database Management"
	@echo "================================"
	@echo ""
	@echo "Available targets:"
	@echo "  $(GREEN)setup-all$(NC)    - Create all test databases (small, medium, large)"
	@echo "  $(GREEN)setup-small$(NC)  - Create small test database (~5 tables)"
	@echo "  $(GREEN)setup-medium$(NC) - Create medium test database (~20 tables)"
	@echo "  $(GREEN)setup-large$(NC)  - Create large test database (~55 tables)"
	@echo "  $(GREEN)drop-all$(NC)     - Drop all test databases"
	@echo "  $(GREEN)drop-small$(NC)   - Drop small test database"
	@echo "  $(GREEN)drop-medium$(NC)  - Drop medium test database"
	@echo "  $(GREEN)drop-large$(NC)   - Drop large test database"
	@echo "  $(GREEN)recreate-all$(NC) - Recreate all test databases"
	@echo "  $(GREEN)verify-all$(NC)   - Verify all databases are set up correctly"
	@echo "  $(GREEN)verify-small$(NC) - Verify small database"
	@echo "  $(GREEN)verify-medium$(NC)- Verify medium database"
	@echo "  $(GREEN)verify-large$(NC) - Verify large database"
	@echo "  $(GREEN)stats$(NC)        - Show database statistics"
	@echo "  $(GREEN)help$(NC)         - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make setup-all"
	@echo "  make setup-large DB_USER=myuser"
	@echo "  make verify-all"
	@echo ""

# -----------------------------------------------------------------------------
# Setup Targets
# -----------------------------------------------------------------------------

.PHONY: setup-all
setup-all: setup-small setup-medium setup-large
	@echo ""
	@echo "$(GREEN)✓ All test databases created successfully!$(NC)"

.PHONY: setup-small
setup-small:
	@echo "$(BLUE)Setting up small test database...$(NC)"
	@$(DROP_DB) $(DB_SMALL) 2>/dev/null || true
	@$(CREATE_DB) $(DB_SMALL)
	@$(PSQL) -d $(DB_SMALL) -f $(SQL_SMALL)
	@echo "$(GREEN)✓ Small database created: $(DB_SMALL)$(NC)"

.PHONY: setup-medium
setup-medium:
	@echo "$(BLUE)Setting up medium test database...$(NC)"
	@$(DROP_DB) $(DB_MEDIUM) 2>/dev/null || true
	@$(CREATE_DB) $(DB_MEDIUM)
	@$(PSQL) -d $(DB_MEDIUM) -f $(SQL_MEDIUM)
	@echo "$(GREEN)✓ Medium database created: $(DB_MEDIUM)$(NC)"

.PHONY: setup-large
setup-large:
	@echo "$(BLUE)Setting up large test database...$(NC)"
	@$(DROP_DB) $(DB_LARGE) 2>/dev/null || true
	@$(CREATE_DB) $(DB_LARGE)
	@$(PSQL) -d $(DB_LARGE) -f $(SQL_LARGE)
	@echo "$(GREEN)✓ Large database created: $(DB_LARGE)$(NC)"

# -----------------------------------------------------------------------------
# Drop Targets
# -----------------------------------------------------------------------------

.PHONY: drop-all
drop-all: drop-small drop-medium drop-large
	@echo ""
	@echo "$(GREEN)✓ All test databases dropped!$(NC)"

.PHONY: drop-small
drop-small:
	@echo "$(YELLOW)Dropping small test database...$(NC)"
	@$(DROP_DB) $(DB_SMALL) 2>/dev/null || true
	@echo "$(GREEN)✓ Small database dropped$(NC)"

.PHONY: drop-medium
drop-medium:
	@echo "$(YELLOW)Dropping medium test database...$(NC)"
	@$(DROP_DB) $(DB_MEDIUM) 2>/dev/null || true
	@echo "$(GREEN)✓ Medium database dropped$(NC)"

.PHONY: drop-large
drop-large:
	@echo "$(YELLOW)Dropping large test database...$(NC)"
	@$(DROP_DB) $(DB_LARGE) 2>/dev/null || true
	@echo "$(GREEN)✓ Large database dropped$(NC)"

# -----------------------------------------------------------------------------
# Recreate Targets
# -----------------------------------------------------------------------------

.PHONY: recreate-all
recreate-all: drop-all setup-all
	@echo "$(GREEN)✓ All databases recreated!$(NC)"

.PHONY: recreate-small
recreate-small: drop-small setup-small

.PHONY: recreate-medium
recreate-medium: drop-medium setup-medium

.PHONY: recreate-large
recreate-large: drop-large setup-large

# -----------------------------------------------------------------------------
# Verify Targets
# -----------------------------------------------------------------------------

.PHONY: verify-all
verify-all: verify-small verify-medium verify-large
	@echo ""
	@echo "$(GREEN)✓ All databases verified!$(NC)"

.PHONY: verify-small
verify-small:
	@echo "$(BLUE)Verifying small database...$(NC)"
	@echo "Tables:" && $(PSQL) -d $(DB_SMALL) -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'testbed'" | xargs
	@echo "Views:" && $(PSQL) -d $(DB_SMALL) -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'testbed'" | xargs
	@echo "Types:" && $(PSQL) -d $(DB_SMALL) -t -c "SELECT COUNT(*) FROM pg_type WHERE typnamespace IN (SELECT oid FROM pg_namespace WHERE nspname = 'testbed')" | xargs
	@echo "Users:" && $(PSQL) -d $(DB_SMALL) -t -c "SELECT COUNT(*) FROM testbed.users" | xargs
	@echo "Products:" && $(PSQL) -d $(DB_SMALL) -t -c "SELECT COUNT(*) FROM testbed.products" | xargs
	@echo "Orders:" && $(PSQL) -d $(DB_SMALL) -t -c "SELECT COUNT(*) FROM testbed.orders" | xargs
	@echo "$(GREEN)✓ Small database verified$(NC)"

.PHONY: verify-medium
verify-medium:
	@echo "$(BLUE)Verifying medium database...$(NC)"
	@echo "Tables:" && $(PSQL) -d $(DB_MEDIUM) -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema')" | xargs
	@echo "Views:" && $(PSQL) -d $(DB_MEDIUM) -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_schema NOT IN ('pg_catalog', 'information_schema')" | xargs
	@echo "Users:" && $(PSQL) -d $(DB_MEDIUM) -t -c "SELECT COUNT(*) FROM sales.customers" | xargs
	@echo "Products:" && $(PSQL) -d $(DB_MEDIUM) -t -c "SELECT COUNT(*) FROM sales.products" | xargs
	@echo "Orders:" && $(PSQL) -d $(DB_MEDIUM) -t -c "SELECT COUNT(*) FROM sales.orders" | xargs
	@echo "Warehouses:" && $(PSQL) -d $(DB_MEDIUM) -t -c "SELECT COUNT(*) FROM inventory.warehouses" | xargs
	@echo "Employees:" && $(PSQL) -d $(DB_MEDIUM) -t -c "SELECT COUNT(*) FROM hr.employees" | xargs
	@echo "$(GREEN)✓ Medium database verified$(NC)"

.PHONY: verify-large
verify-large:
	@echo "$(BLUE)Verifying large database...$(NC)"
	@echo "Tables:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema')" | xargs
	@echo "Views:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_schema NOT IN ('pg_catalog', 'information_schema')" | xargs
	@echo "Indexes:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname NOT IN ('pg_catalog', 'information_schema')" | xargs
	@echo "Triggers:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM pg_triggers WHERE schemaname NOT IN ('pg_catalog', 'information_schema')" | xargs
	@echo "Users:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM accounts.users" | xargs
	@echo "Products:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM catalog.products" | xargs
	@echo "Categories:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM catalog.categories" | xargs
	@echo "Brands:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM catalog.brands" | xargs
	@echo "Warehouses:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM inventory.warehouses" | xargs
	@echo "Orders:" && $(PSQL) -d $(DB_LARGE) -t -c "SELECT COUNT(*) FROM orders.orders" | xargs
	@echo "$(GREEN)✓ Large database verified$(NC)"

# -----------------------------------------------------------------------------
# Stats Target
# -----------------------------------------------------------------------------

.PHONY: stats
stats:
	@echo ""
	@echo "pg-mcp Test Database Statistics"
	@echo "================================"
	@echo ""
	@echo "$(BLUE)Small Database: $(DB_SMALL)$(NC)"
	@$(PSQL) -d $(DB_SMALL) -c "
		SELECT 'Tables' AS entity, COUNT(*) AS count FROM information_schema.tables WHERE table_schema = 'testbed'
		UNION ALL SELECT 'Views', COUNT(*) FROM information_schema.views WHERE table_schema = 'testbed'
		UNION ALL SELECT 'Users', COUNT(*) FROM testbed.users
		UNION ALL SELECT 'Products', COUNT(*) FROM testbed.products
		UNION ALL SELECT 'Orders', COUNT(*) FROM testbed.orders
		UNION ALL SELECT 'Order Items', COUNT(*) FROM testbed.order_items
	"
	@echo ""
	@echo "$(BLUE)Medium Database: $(DB_MEDIUM)$(NC)"
	@$(PSQL) -d $(DB_MEDIUM) -c "
		SELECT 'Tables' AS entity, COUNT(*) AS count FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
		UNION ALL SELECT 'Views', COUNT(*) FROM information_schema.views WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
		UNION ALL SELECT 'Customers', COUNT(*) FROM sales.customers
		UNION ALL SELECT 'Products', COUNT(*) FROM sales.products
		UNION ALL SELECT 'Orders', COUNT(*) FROM sales.orders
		UNION ALL SELECT 'Warehouses', COUNT(*) FROM inventory.warehouses
		UNION ALL SELECT 'Employees', COUNT(*) FROM hr.employees
	"
	@echo ""
	@echo "$(BLUE)Large Database: $(DB_LARGE)$(NC)"
	@$(PSQL) -d $(DB_LARGE) -c "
		SELECT 'Tables' AS entity, COUNT(*) AS count FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
		UNION ALL SELECT 'Views', COUNT(*) FROM information_schema.views WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
		UNION ALL SELECT 'Indexes', COUNT(*) FROM pg_indexes WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
		UNION ALL SELECT 'Triggers', COUNT(*) FROM pg_triggers WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
		UNION ALL SELECT 'Users', COUNT(*) FROM accounts.users
		UNION ALL SELECT 'Products', COUNT(*) FROM catalog.products
		UNION ALL SELECT 'Categories', COUNT(*) FROM catalog.categories
		UNION ALL SELECT 'Brands', COUNT(*) FROM catalog.brands
		UNION ALL SELECT 'Warehouses', COUNT(*) FROM inventory.warehouses
		UNION ALL SELECT 'Orders', COUNT(*) FROM orders.orders
	"

# -----------------------------------------------------------------------------
# Test Connection Targets
# -----------------------------------------------------------------------------

.PHONY: test-connection
test-connection:
	@echo "$(BLUE)Testing database connection...$(NC)"
	@$(PSQL) -c "SELECT version();" 2>/dev/null && echo "$(GREEN)✓ Connection successful$(NC)" || echo "$(RED)✗ Connection failed$(NC)"

.PHONY: test-small
test-small:
	@$(PSQL) -d $(DB_SMALL) -c "SELECT 1" 2>/dev/null && echo "$(GREEN)✓ Small database is accessible$(NC)" || echo "$(RED)✗ Small database not found$(NC)"

.PHONY: test-medium
test-medium:
	@$(PSQL) -d $(DB_MEDIUM) -c "SELECT 1" 2>/dev/null && echo "$(GREEN)✓ Medium database is accessible$(NC)" || echo "$(RED)✗ Medium database not found$(NC)"

.PHONY: test-large
test-large:
	@$(PSQL) -d $(DB_LARGE) -c "SELECT 1" 2>/dev/null && echo "$(GREEN)✓ Large database is accessible$(NC)" || echo "$(RED)✗ Large database not found$(NC)"

# -----------------------------------------------------------------------------
# Query Testing Targets
# -----------------------------------------------------------------------------

.PHONY: test-queries-small
test-queries-small:
	@echo "$(BLUE)Testing queries on small database...$(NC)"
	@echo "Query 1 - Active users:" && $(PSQL) -d $(DB_SMALL) -c "SELECT COUNT(*) FROM testbed.users WHERE status = 'active'"
	@echo "Query 2 - Products by category:" && $(PSQL) -d $(DB_SMALL) -c "SELECT COUNT(*) FROM testbed.products WHERE category = 'Electronics'"
	@echo "Query 3 - Orders with items:" && $(PSQL) -d $(DB_SMALL) -c "SELECT COUNT(*) FROM testbed.orders o JOIN testbed.order_items oi ON o.id = oi.order_id"
	@echo "Query 4 - View check:" && $(PSQL) -d $(DB_SMALL) -c "SELECT COUNT(*) FROM testbed.active_users"
	@echo "$(GREEN)✓ All queries passed on small database$(NC)"

.PHONY: test-queries-medium
test-queries-medium:
	@echo "$(BLUE)Testing queries on medium database...$(NC)"
	@echo "Query 1 - Customer orders:" && $(PSQL) -d $(DB_MEDIUM) -c "SELECT COUNT(*) FROM sales.customer_orders"
	@echo "Query 2 - Inventory status:" && $(PSQL) -d $(DB_MEDIUM) -c "SELECT COUNT(*) FROM inventory.inventory_status"
	@echo "Query 3 - Employee summary:" && $(PSQL) -d $(DB_MEDIUM) -c "SELECT COUNT(*) FROM hr.employee_summary"
	@echo "Query 4 - Order summary:" && $(PSQL) -d $(DB_MEDIUM) -c "SELECT COUNT(*) FROM sales.order_details"
	@echo "$(GREEN)✓ All queries passed on medium database$(NC)"

.PHONY: test-queries-large
test-queries-large:
	@echo "$(BLUE)Testing queries on large database...$(NC)"
	@echo "Query 1 - Active products:" && $(PSQL) -d $(DB_LARGE) -c "SELECT COUNT(*) FROM catalog.active_products"
	@echo "Query 2 - Inventory summary:" && $(PSQL) -d $(DB_LARGE) -c "SELECT COUNT(*) FROM inventory.inventory_summary"
	@echo "Query 3 - Customer summary:" && $(PSQL) -d $(DB_LARGE) -c "SELECT COUNT(*) FROM accounts.customer_summary"
	@echo "Query 4 - Top products:" && $(PSQL) -d $(DB_LARGE) -c "SELECT COUNT(*) FROM analytics.top_products"
	@echo "$(GREEN)✓ All queries passed on large database$(NC)"

# -----------------------------------------------------------------------------
# Docker Support
# -----------------------------------------------------------------------------

.PHONY: docker-up
docker-up:
	@echo "$(BLUE)Starting PostgreSQL container...$(NC)"
	docker run -d --name pg-mcp-test \
		-e POSTGRES_PASSWORD=postgres \
		-p 5432:5432 \
		-v pg_mcp_data:/var/lib/postgresql/data \
		postgres:16
	@echo "$(GREEN)✓ PostgreSQL container started$(NC)"
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	@make test-connection

.PHONY: docker-down
docker-down:
	@echo "$(BLUE)Stopping PostgreSQL container...$(NC)"
	docker stop pg-mcp-test 2>/dev/null || true
	docker rm pg-mcp-test 2>/dev/null || true
	@echo "$(GREEN)✓ PostgreSQL container stopped$(NC)"

.PHONY: docker-restart
docker-restart: docker-down docker-up

# -----------------------------------------------------------------------------
# Development Targets
# -----------------------------------------------------------------------------

.PHONY: dev-setup
dev-setup: test-connection setup-all verify-all
	@echo ""
	@echo "$(GREEN)✓ Development environment ready!$(NC)"
	@echo "You can now run tests with:"
	@echo "  pytest tests/"
