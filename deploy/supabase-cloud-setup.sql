-- =============================================================
-- Cortex ETL — Supabase Cloud Setup
-- Run this ONCE in the Supabase Cloud SQL Editor.
-- Before running: enable the "vector" and "http" extensions
-- via Dashboard → Database → Extensions.
-- =============================================================

-- 001: Core tables
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TYPE user_role AS ENUM ('tenant', 'admin');

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE,
    first_name TEXT,
    last_name TEXT,
    role user_role NOT NULL DEFAULT 'tenant',
    tenant_id UUID REFERENCES public.tenants(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id)
);

CREATE TYPE file_type AS ENUM ('pdf', 'csv');

CREATE TABLE IF NOT EXISTS file_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type file_type NOT NULL,
    name TEXT NOT NULL,
    bucket_id TEXT NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TYPE extraction_status AS ENUM ('queued', 'processing', 'completed', 'failed');

CREATE TABLE IF NOT EXISTS extracted_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_file_id UUID NOT NULL REFERENCES file_uploads(id) ON DELETE CASCADE,
    status extraction_status NOT NULL,
    extracted_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_file_uploads_tenant_id ON file_uploads(tenant_id);
CREATE INDEX idx_profiles_tenant_id ON public.profiles(tenant_id);
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_file_uploads_name_pattern ON file_uploads(name) WHERE name LIKE '%.pdf';
CREATE INDEX idx_extracted_files_source_file ON extracted_files(source_file_id);

CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- 002: Row-Level Security policies
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE file_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE extracted_files ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenants
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND (role = 'admin' OR tenant_id = tenants.id)
    )
);

CREATE POLICY profiles_policy ON public.profiles
FOR ALL USING (auth.uid() = id);

CREATE POLICY file_uploads_policy ON file_uploads
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND (role = 'admin' OR tenant_id = file_uploads.tenant_id)
    )
);

CREATE POLICY extracted_files_policy ON extracted_files
FOR ALL USING (
    EXISTS (
        SELECT 1
        FROM file_uploads fu
        JOIN public.profiles p ON p.id = auth.uid()
        WHERE fu.id = extracted_files.source_file_id
        AND (p.role = 'admin' OR p.tenant_id = fu.tenant_id)
    )
);

-- 003: exec_sql helper
CREATE OR REPLACE FUNCTION public.exec_sql(sql text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  EXECUTE sql;
END;
$$;

-- 004: Storage bucket and policies
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Tenants can upload to own folder"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = (
    SELECT tenant_id::text FROM public.profiles WHERE id = auth.uid()
  )
);

CREATE POLICY "Tenants can read own files"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = (
    SELECT tenant_id::text FROM public.profiles WHERE id = auth.uid()
  )
);

CREATE POLICY "Tenants can delete own files"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = (
    SELECT tenant_id::text FROM public.profiles WHERE id = auth.uid()
  )
);

CREATE POLICY "Admins can access all files"
ON storage.objects FOR ALL TO authenticated
USING (
  bucket_id = 'documents'
  AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 005: Webhook automation
CREATE TABLE IF NOT EXISTS webhook_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO webhook_config (key, value)
VALUES
  ('extract_webhook_url', ''),
  ('extract_webhook_secret', '')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION handle_storage_upload()
RETURNS TRIGGER AS $$
DECLARE
  tenant_id_val UUID;
  webhook_url TEXT;
  webhook_secret TEXT;
  filename TEXT;
  file_upload_id UUID;
  file_type_val file_type;
BEGIN
  IF NEW.bucket_id != 'documents' THEN
    RETURN NEW;
  END IF;

  BEGIN
    tenant_id_val := (regexp_matches(NEW.name, '^([a-f0-9-]{36})/'))[1]::UUID;
    filename := regexp_replace(NEW.name, '^[a-f0-9-]{36}/', '');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
  END;

  IF filename ILIKE '%.pdf' THEN
    file_type_val := 'pdf';
  ELSIF filename ILIKE '%.csv' THEN
    file_type_val := 'csv';
  ELSE
    RETURN NEW;
  END IF;

  INSERT INTO file_uploads (type, name, bucket_id, tenant_id)
  VALUES (file_type_val, filename, NEW.bucket_id, tenant_id_val)
  ON CONFLICT DO NOTHING
  RETURNING id INTO file_upload_id;

  IF file_type_val != 'pdf' THEN
    RETURN NEW;
  END IF;

  SELECT value INTO webhook_url
  FROM webhook_config WHERE key = 'extract_webhook_url';

  SELECT value INTO webhook_secret
  FROM webhook_config WHERE key = 'extract_webhook_secret';

  IF webhook_url IS NULL OR webhook_url = '' THEN
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := webhook_url || '/' || file_upload_id,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Webhook-Secret', COALESCE(webhook_secret, '')
    ),
    timeout_milliseconds := 5000
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_storage_upload ON storage.objects;
CREATE TRIGGER trigger_storage_upload
  AFTER INSERT ON storage.objects
  FOR EACH ROW
  WHEN (NEW.bucket_id = 'documents')
  EXECUTE FUNCTION handle_storage_upload();

CREATE OR REPLACE FUNCTION update_webhook_config(url TEXT, secret TEXT)
RETURNS void AS $$
BEGIN
  UPDATE webhook_config
  SET value = url, updated_at = NOW()
  WHERE key = 'extract_webhook_url';

  UPDATE webhook_config
  SET value = secret, updated_at = NOW()
  WHERE key = 'extract_webhook_secret';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 006: pgvector embeddings
CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE extracted_files
ADD COLUMN embedding vector(768);

CREATE INDEX ON extracted_files USING ivfflat (embedding vector_cosine_ops);

CREATE OR REPLACE FUNCTION match_documents(
    query_embedding vector(768),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 10,
    filter_tenant_id uuid DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    source_file_id uuid,
    extracted_data jsonb,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ef.id,
        ef.source_file_id,
        ef.extracted_data,
        1 - (ef.embedding <=> query_embedding) as similarity
    FROM extracted_files ef
    JOIN file_uploads fu ON fu.id = ef.source_file_id
    WHERE
        ef.embedding IS NOT NULL
        AND (filter_tenant_id IS NULL OR fu.tenant_id = filter_tenant_id)
        AND 1 - (ef.embedding <=> query_embedding) > match_threshold
    ORDER BY ef.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 007: Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE extracted_files;

-- 008: Classifications
CREATE TABLE IF NOT EXISTS classifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, name)
);

ALTER TABLE file_uploads
ADD COLUMN classification_id UUID REFERENCES classifications(id);

CREATE INDEX idx_classifications_tenant_id ON classifications(tenant_id);
CREATE INDEX idx_file_uploads_classification_id ON file_uploads(classification_id);

ALTER TABLE classifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY classifications_policy ON classifications
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND (role = 'admin' OR tenant_id = classifications.tenant_id)
    )
);

CREATE OR REPLACE FUNCTION check_classification_tenant()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.classification_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM classifications c
            WHERE c.id = NEW.classification_id
            AND c.tenant_id = NEW.tenant_id
        ) THEN
            RAISE EXCEPTION 'Classification must belong to the same tenant as the file';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_file_classification
    BEFORE INSERT OR UPDATE ON file_uploads
    FOR EACH ROW
    EXECUTE FUNCTION check_classification_tenant();

-- 009: Relationships
CREATE TYPE relationship_type AS ENUM ('one-to-one', 'one-to-many', 'many-to-many');

CREATE TABLE IF NOT EXISTS relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    from_classification_id UUID NOT NULL REFERENCES classifications(id) ON DELETE CASCADE,
    to_classification_id UUID NOT NULL REFERENCES classifications(id) ON DELETE CASCADE,
    type relationship_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, from_classification_id, to_classification_id)
);

CREATE INDEX idx_relationships_tenant_id ON relationships(tenant_id);
CREATE INDEX idx_relationships_from_classification_id ON relationships(from_classification_id);
CREATE INDEX idx_relationships_to_classification_id ON relationships(to_classification_id);

ALTER TABLE relationships ENABLE ROW LEVEL SECURITY;

CREATE POLICY relationships_policy ON relationships
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND (role = 'admin' OR tenant_id = relationships.tenant_id)
    )
);

-- 010: Migrations table
CREATE TABLE IF NOT EXISTS migrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    sql TEXT NOT NULL,
    sequence INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, sequence)
);

CREATE INDEX idx_migrations_tenant_id ON migrations(tenant_id);
CREATE INDEX idx_migrations_sequence ON migrations(sequence);

ALTER TABLE migrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY migrations_policy ON migrations
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND (role = 'admin' OR tenant_id = migrations.tenant_id)
    )
);

CREATE OR REPLACE FUNCTION execute_sql(query text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  EXECUTE query;
END;
$$;
