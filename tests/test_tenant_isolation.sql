-- tests/test_tenant_isolation.sql

-- 1. Create Organizations
INSERT INTO public.organizations (id, name, slug) VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Org A', 'org-a'),
    ('22222222-2222-2222-2222-222222222222', 'Org B', 'org-b')
ON CONFLICT DO NOTHING;

-- Grant privileges so the role can actually insert/select and test RLS
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Test Case 1: Insert as Org A (superuser setup)
DO $$
BEGIN
    INSERT INTO public.receipts (id, organization_id, content_hash, signature, receipt_type, event_timestamp, payload)
    VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'hash_a', '\x00', 'test', now(), '{}'::jsonb)
    ON CONFLICT DO NOTHING;
END $$;

-- Switch to the authenticated role for RLS read testing
SET ROLE authenticated;

-- Test Case 2: Read as Org B (Should not see Org A's receipt)
SET app.current_org_id = '22222222-2222-2222-2222-222222222222';

DO $$
DECLARE
    rec_count integer;
BEGIN
    SELECT count(*) INTO rec_count FROM public.receipts WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    IF rec_count > 0 THEN
        RAISE EXCEPTION 'Tenant Isolation Failed: Org B can see Org A data!';
    ELSE
        RAISE NOTICE 'Tenant Isolation Success: Org B cannot see Org A data.';
    END IF;
END $$;

-- Switch back to superuser
RESET ROLE;
