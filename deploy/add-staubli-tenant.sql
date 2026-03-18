-- Run this in Supabase SQL Editor if Staubli tenant is missing.
-- (e.g. DB was seeded before Staubli was added to the seed)
INSERT INTO tenants (name, is_active)
VALUES ('Staubli', true)
ON CONFLICT (name) DO NOTHING;
