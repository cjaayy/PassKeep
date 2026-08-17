-- ==============================================================================
-- PassKeep: Zero-Knowledge Encrypted Vault Database Schema (Supabase PostgreSQL)
-- ==============================================================================

-- 1. Create the `vault_items` table
CREATE TABLE IF NOT EXISTS public.vault_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    username_enc TEXT NOT NULL,
    password_enc TEXT NOT NULL,
    iv TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    notes TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Performance & Query Optimization Indexes
CREATE INDEX IF NOT EXISTS idx_vault_items_user_id ON public.vault_items(user_id);
CREATE INDEX IF NOT EXISTS idx_vault_items_user_updated ON public.vault_items(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_vault_items_user_deleted ON public.vault_items(user_id, is_deleted);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.vault_items ENABLE ROW LEVEL SECURITY;

-- 4. Row Level Security Policies
-- (Only authenticated users can view, insert, update, or delete their own vault items)

-- Policy: SELECT - Users can only view their own items
CREATE POLICY "Users can view their own vault items"
    ON public.vault_items
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: INSERT - Users can insert vault items assigned to their own user_id
CREATE POLICY "Users can insert their own vault items"
    ON public.vault_items
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: UPDATE - Users can only update their own vault items
CREATE POLICY "Users can update their own vault items"
    ON public.vault_items
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: DELETE - Users can only delete their own vault items
CREATE POLICY "Users can delete their own vault items"
    ON public.vault_items
    FOR DELETE
    USING (auth.uid() = user_id);

-- 5. Trigger for automated updated_at timestamp updates
CREATE OR REPLACE FUNCTION public.handle_vault_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_vault_item_updated ON public.vault_items;
CREATE TRIGGER on_vault_item_updated
    BEFORE UPDATE ON public.vault_items
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_vault_updated_at();
