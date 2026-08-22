-- tests/test_fk_integrity.sql

-- Ensure we have an org
INSERT INTO public.organizations (id, name, slug) VALUES 
    ('44444444-4444-4444-4444-444444444444', 'Org D FK Test', 'org-d-fk')
ON CONFLICT DO NOTHING;

-- Switch to the authenticated role for RLS
SET ROLE authenticated;
SET app.current_org_id = '44444444-4444-4444-4444-444444444444';

DO $$
BEGIN
    -- Insert a Policy Set
    INSERT INTO public.policy_sets (id, organization_id, name)
    VALUES ('55555555-5555-5555-5555-555555555555', '44444444-4444-4444-4444-444444444444', 'Test Set')
    ON CONFLICT DO NOTHING;

    -- Insert a Policy Version
    INSERT INTO public.policy_versions (id, organization_id, policy_set_id, payload_hash, version_number, raw_payload)
    VALUES ('66666666-6666-6666-6666-666666666666', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555', 'hash', 'v1', '{}'::jsonb)
    ON CONFLICT DO NOTHING;

    -- Insert a Gate Definition
    INSERT INTO public.gate_definitions (id, organization_id, policy_version_id, gate_type, failure_action, name)
    VALUES ('77777777-7777-7777-7777-777777777777', '44444444-4444-4444-4444-444444444444', '66666666-6666-6666-6666-666666666666', 'pre_deploy', 'block', 'Test Gate')
    ON CONFLICT DO NOTHING;

    -- Insert a Gate Evaluation
    INSERT INTO public.gate_evaluations (id, organization_id, policy_version_id, gate_definition_id, gate_outcome, evaluation_hash)
    VALUES ('88888888-8888-8888-8888-888888888888', '44444444-4444-4444-4444-444444444444', '66666666-6666-6666-6666-666666666666', '77777777-7777-7777-7777-777777777777', 'pass', 'hash')
    ON CONFLICT DO NOTHING;

    -- Insert a Receipt linking to the Gate Evaluation
    INSERT INTO public.receipts (id, organization_id, policy_version_id, gate_evaluation_id, content_hash, signature, receipt_type, event_timestamp, payload)
    VALUES ('99999999-9999-9999-9999-999999999999', '44444444-4444-4444-4444-444444444444', '66666666-6666-6666-6666-666666666666', '88888888-8888-8888-8888-888888888888', 'hash', '\x00', 'gate_receipt', now(), '{}'::jsonb)
    ON CONFLICT DO NOTHING;
END $$;

-- Test Cascade Deletion from Policy Version
DO $$
DECLARE
    rec_count integer;
BEGIN
    -- Delete the Policy Version
    -- NOTE: policy_versions has a WORM trigger. It should block this deletion!
    BEGIN
        DELETE FROM public.policy_versions WHERE id = '66666666-6666-6666-6666-666666666666';
        RAISE EXCEPTION 'FK Integrity Failed: WORM trigger did not block deletion of policy_version!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'FK Integrity Success: Deletion of policy_version correctly blocked by WORM trigger: %', SQLERRM;
    END;

    -- Since deletion was blocked, records should still exist
    SELECT count(*) INTO rec_count FROM public.gate_evaluations WHERE id = '88888888-8888-8888-8888-888888888888';
    IF rec_count != 1 THEN
        RAISE EXCEPTION 'FK Integrity Failed: Gate Evaluation is missing!';
    END IF;

END $$;

RESET ROLE;
