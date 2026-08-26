-- Create audit schema (separate from app schema per HIPAA isolation requirements)
CREATE SCHEMA IF NOT EXISTS audit;

-- Enable pgcrypto for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
