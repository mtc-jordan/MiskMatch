-- MiskMatch — PostgreSQL initialization
-- Runs once when the Docker container is first created.

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pg_trgm for fuzzy text search (name search, bio search)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enable unaccent for Arabic/accented text search
CREATE EXTENSION IF NOT EXISTS unaccent;
