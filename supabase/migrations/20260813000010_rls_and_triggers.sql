-- File 10: RLS and Triggers
-- Enables Row Level Security and WORM triggers for immutable tables.

-- 1. Enable RLS on all 60 tables

DO $$
DECLARE
    t_name text;
BEGIN
    FOR t_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t_name);
    END LOOP;
END $$;

-- 2. Create a generic RLS policy for organizations
-- This assumes application passes organization_id via current_setting('app.current_org_id')
-- Or for supabase auth it might use auth.uid() mapped to org members.
-- For this reference implementation, we provide a template policy.

-- Note: In a real Supabase setup, you'd link this to auth.uid().
-- Example: CREATE POLICY "tenant_isolation" ON public.receipts FOR ALL USING (organization_id = current_setting('app.current_org_id', true)::uuid);

-- 3. WORM (Write Once Read Many) Triggers for Immutable Tables
-- The CIAF architecture requires cryptographic tables to be append-only.

CREATE OR REPLACE FUNCTION public.prevent_update_or_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Updates and Deletes are strictly prohibited on this immutable table for cryptographic integrity.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply WORM to Receipts
CREATE TRIGGER worm_receipts
BEFORE UPDATE OR DELETE ON public.receipts
FOR EACH ROW EXECUTE FUNCTION public.prevent_update_or_delete();

-- Apply WORM to Policy Versions
CREATE TRIGGER worm_policy_versions
BEFORE UPDATE OR DELETE ON public.policy_versions
FOR EACH ROW EXECUTE FUNCTION public.prevent_update_or_delete();

-- Apply WORM to Gate Evaluations
CREATE TRIGGER worm_gate_evaluations
BEFORE UPDATE OR DELETE ON public.gate_evaluations
FOR EACH ROW EXECUTE FUNCTION public.prevent_update_or_delete();

-- Apply WORM to Receipt Batches
CREATE TRIGGER worm_receipt_batches
BEFORE UPDATE OR DELETE ON public.receipt_batches
FOR EACH ROW EXECUTE FUNCTION public.prevent_update_or_delete();

-- Apply WORM to Vault Objects
CREATE TRIGGER worm_vault_objects
BEFORE UPDATE OR DELETE ON public.vault_objects
FOR EACH ROW EXECUTE FUNCTION public.prevent_update_or_delete();

-- Apply WORM to Audit Packs
CREATE TRIGGER worm_audit_packs
BEFORE UPDATE OR DELETE ON public.audit_packs
FOR EACH ROW EXECUTE FUNCTION public.prevent_update_or_delete();

-- Apply WORM to Privacy Redaction Events
CREATE TRIGGER worm_privacy_redaction_events
BEFORE UPDATE OR DELETE ON public.privacy_redaction_events
FOR EACH ROW EXECUTE FUNCTION public.prevent_update_or_delete();

-- Additional immutability could be applied to api_request_logs, agent_tool_invocations, etc.
