-- =============================================================================
-- Database Monitoring User Setup Script
-- =============================================================================
-- This script creates dedicated monitoring users for Datadog Agent integration
-- 
-- Execute these commands in your respective databases to create the monitoring users
-- that match the credentials in your .env file:
-- 
-- PostgreSQL monitoring user: datadog / DatadogPassword123!
-- SQL Server monitoring user: datadog / DatadogPassword123!
--
-- =============================================================================

-- =============================================================================
-- POSTGRESQL SETUP
-- =============================================================================
-- Execute these commands in your PostgreSQL database as a superuser (postgres)
-- 
-- Connect to your database:
-- psql -h 192.168.1.100 -p 5432 -U postgres -d images

-- Create the datadog monitoring user
CREATE USER datadog WITH PASSWORD 'DatadogPassword123!';

-- Grant necessary permissions for monitoring
GRANT pg_monitor TO datadog;
GRANT SELECT ON pg_stat_database TO datadog;
GRANT SELECT ON pg_stat_user_tables TO datadog;
GRANT SELECT ON pg_stat_user_indexes TO datadog;
GRANT SELECT ON pg_statio_user_tables TO datadog;
GRANT SELECT ON pg_statio_user_indexes TO datadog;

-- For Database Monitoring (DBM) - additional permissions
GRANT SELECT ON pg_stat_statements TO datadog;
GRANT SELECT ON pg_stat_activity TO datadog;
GRANT SELECT ON pg_stat_replication TO datadog;

-- Grant access to specific database (replace 'images' with your database name)
GRANT CONNECT ON DATABASE images TO datadog;
GRANT USAGE ON SCHEMA public TO datadog;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO datadog;

-- Ensure pg_stat_statements extension is enabled for query monitoring
-- (Run as superuser if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Verify the user was created successfully
\du datadog

-- Test connection (optional - run from command line)
-- psql -h 192.168.1.100 -p 5432 -U datadog -d images -c "SELECT version();"

-- =============================================================================
-- SQL SERVER SETUP  
-- =============================================================================
-- Execute these commands in SQL Server Management Studio or sqlcmd
-- 
-- Connect as sa user or another user with sysadmin privileges
-- sqlcmd -S 192.168.1.100,9003 -U sa -P Pass@word123

-- Create the datadog monitoring login
CREATE LOGIN datadog WITH PASSWORD = 'DatadogPassword123!';

-- Create user in master database
USE master;
CREATE USER datadog FOR LOGIN datadog;

-- Grant necessary server-level permissions for monitoring
ALTER SERVER ROLE serveradmin ADD MEMBER datadog;
GRANT VIEW SERVER STATE TO datadog;
GRANT VIEW ANY DEFINITION TO datadog;

-- Grant database-level permissions for each database you want to monitor
-- Replace with your specific database names as needed
USE master;
GRANT VIEW DATABASE STATE TO datadog;

-- For additional databases, repeat these grants:
-- USE [YourDatabaseName];
-- CREATE USER datadog FOR LOGIN datadog;
-- GRANT VIEW DATABASE STATE TO datadog;
-- GRANT SELECT ON sys.dm_exec_query_stats TO datadog;
-- GRANT SELECT ON sys.dm_exec_requests TO datadog;
-- GRANT SELECT ON sys.dm_exec_sessions TO datadog;

-- Verify the login was created successfully
SELECT name FROM sys.server_principals WHERE name = 'datadog';

-- Test connection (optional - run from command line)
-- sqlcmd -S 192.168.1.100,9003 -U datadog -P DatadogPassword123! -Q "SELECT @@VERSION"

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- PostgreSQL - Verify monitoring user permissions
-- SELECT * FROM pg_roles WHERE rolname = 'datadog';
-- SELECT * FROM information_schema.role_table_grants WHERE grantee = 'datadog';

-- SQL Server - Verify monitoring user permissions  
-- SELECT 
--     dp.name AS principal_name,
--     dp.type_desc AS principal_type,
--     o.name AS object_name,
--     p.permission_name,
--     p.state_desc AS permission_state
-- FROM sys.database_permissions p
-- LEFT JOIN sys.objects o ON p.major_id = o.object_id
-- LEFT JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
-- WHERE dp.name = 'datadog';

-- =============================================================================
-- SECURITY NOTES
-- =============================================================================
-- 1. The monitoring users have read-only access to system catalogs and statistics
-- 2. They cannot modify data or schema in your databases
-- 3. For production environments, consider using more restrictive permissions
-- 4. Store passwords securely and rotate them regularly
-- 5. Monitor login attempts for the datadog users
-- 
-- =============================================================================