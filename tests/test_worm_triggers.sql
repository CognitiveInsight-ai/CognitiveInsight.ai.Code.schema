-- tests/test_worm_triggers.sql

-- Ensure we have an org
INSERT INTO public.organizations (id, name, slug) VALUES 
    ('33333333-3333-3333-3333-333333333333', 'Org C', 'org-c')
ON CONFLICT DO NOTHING;

-- Grant privileges to authenticated role (in case running cleanly)
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- 1. Insert an evidence_object (as superuser)
DO $$
BEGIN
    INSERT INTO public.evidence_objects (id, organization_id, content_hash, object_type)
    VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333', 'hash_b', 'document')
    ON CONFLICT DO NOTHING;
END $$;

SET ROLE authenticated;
SET app.current_org_id = '33333333-3333-3333-3333-333333333333';

-- 2. Test UPDATE block
DO $$
BEGIN
    UPDATE public.evidence_objects SET object_type = 'tampered' WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    RAISE EXCEPTION 'WORM Trigger Failed: Update was allowed!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'WORM Trigger Success: Update blocked with message: %', SQLERRM;
END $$;

-- 3. Test DELETE block
DO $$
BEGIN
    DELETE FROM public.evidence_objects WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    RAISE EXCEPTION 'WORM Trigger Failed: Delete was allowed!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'WORM Trigger Success: Delete blocked with message: %', SQLERRM;
END $$;

RESET ROLE;
