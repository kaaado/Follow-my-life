-- ==============================================================================
-- Follow My Life: Supabase Cloud Backup & Recovery Schema
-- Project: yyjhsexdlqpdbojpfngh
-- Host: db.yyjhsexdlqpdbojpfngh.supabase.co
-- ==============================================================================

-- 1. Create user_backups table
CREATE TABLE IF NOT EXISTS public.user_backups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    phone TEXT,
    email TEXT,
    identifier TEXT NOT NULL UNIQUE,
    checksum TEXT NOT NULL,
    schema_version INTEGER NOT NULL DEFAULT 5,
    record_counts JSONB,
    backup_data JSONB NOT NULL,
    raw_payload TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Ensure raw_payload column exists if table was previously created
ALTER TABLE public.user_backups ADD COLUMN IF NOT EXISTS raw_payload TEXT;

-- 2. Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_user_backups_identifier ON public.user_backups (identifier);
CREATE INDEX IF NOT EXISTS idx_user_backups_phone ON public.user_backups (phone);
CREATE INDEX IF NOT EXISTS idx_user_backups_user_id ON public.user_backups (user_id);
CREATE INDEX IF NOT EXISTS idx_user_backups_updated_at ON public.user_backups (updated_at DESC);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.user_backups ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
-- Users can view their own backups by user_id, phone, email, or identifier
DROP POLICY IF EXISTS "Users can view their own backups" ON public.user_backups;
CREATE POLICY "Users can view their own backups"
    ON public.user_backups
    FOR SELECT
    USING (
        auth.uid() = user_id 
        OR identifier = auth.uid()::text
        OR phone = (auth.jwt()->>'phone')
        OR email = (auth.jwt()->>'email')
        OR auth.role() = 'anon'
    );

-- Users can insert their own backups
DROP POLICY IF EXISTS "Users can insert their own backups" ON public.user_backups;
CREATE POLICY "Users can insert their own backups"
    ON public.user_backups
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id 
        OR identifier = auth.uid()::text
        OR phone = (auth.jwt()->>'phone')
        OR email = (auth.jwt()->>'email')
        OR auth.role() = 'anon'
    );

-- Users can update their own backups
DROP POLICY IF EXISTS "Users can update their own backups" ON public.user_backups;
CREATE POLICY "Users can update their own backups"
    ON public.user_backups
    FOR UPDATE
    USING (
        auth.uid() = user_id 
        OR identifier = auth.uid()::text
        OR phone = (auth.jwt()->>'phone')
        OR email = (auth.jwt()->>'email')
        OR auth.role() = 'anon'
    );

-- Users can delete their own backups
DROP POLICY IF EXISTS "Users can delete their own backups" ON public.user_backups;
CREATE POLICY "Users can delete their own backups"
    ON public.user_backups
    FOR DELETE
    USING (
        auth.uid() = user_id 
        OR identifier = auth.uid()::text
        OR phone = (auth.jwt()->>'phone')
        OR email = (auth.jwt()->>'email')
        OR auth.role() = 'anon'
    );
