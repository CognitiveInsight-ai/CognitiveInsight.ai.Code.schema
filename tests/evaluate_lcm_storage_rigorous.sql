-- tests/evaluate_lcm_storage_rigorous.sql

-- Rigorous Benchmark for LCM Blended Storage Savings
-- NOTE: Materialization rates (e.g. 5%) are assumed inputs (models), not observed production data.

DO $$
DECLARE
    org_id uuid;
    i integer;
    
    receipt_row record;
    capsule_row record;
    
    receipt_total_bytes bigint := 0;
    capsule_total_bytes bigint := 0;
    
    avg_receipt_size numeric;
    avg_capsule_size numeric;
    
    simulated_payload jsonb;
    payload_hash text;
    receipt_type text;
    
    rates numeric[] := ARRAY[0.01, 0.05, 0.10, 0.25];
    rate numeric;
    blended_savings numeric;
BEGIN
    -- Create Org for Benchmark
    INSERT INTO public.organizations (name, slug) VALUES ('LCM Rigorous Bench', 'lcm-rigorous-' || gen_random_uuid()) RETURNING id INTO org_id;
    
    SET LOCAL app.current_org_id = org_id;
    
    -- Generate 100 representative events
    FOR i IN 1..100 LOOP
        IF i % 2 = 0 THEN
            receipt_type := 'tool_execution';
            simulated_payload := ('{"tool": "database_query", "query_context": "' || repeat('C', 5000) || '"}')::jsonb;
        ELSE
            receipt_type := 'privacy_redaction';
            simulated_payload := ('{"redacted_fields": ["ssn", "email"], "original_text": "' || repeat('D', 4000) || '"}')::jsonb;
        END IF;
        
        payload_hash := md5(simulated_payload::text);
        
        -- Insert receipt (Hot Pool)
        INSERT INTO public.receipts (organization_id, content_hash, signature, receipt_type, event_timestamp, payload)
        VALUES (org_id, payload_hash, '\x00', receipt_type, now(), '{"status": "recorded"}'::jsonb)
        RETURNING * INTO receipt_row;
        
        -- Measure EXACT receipt size
        receipt_total_bytes := receipt_total_bytes + pg_column_size(receipt_row);
        
        -- Insert capsule (Materialized Evidence)
        INSERT INTO public.evidence_objects (organization_id, content_hash, object_type, payload)
        VALUES (org_id, payload_hash, receipt_type, simulated_payload)
        RETURNING * INTO capsule_row;
        
        -- Measure EXACT capsule size
        capsule_total_bytes := capsule_total_bytes + pg_column_size(capsule_row);

    END LOOP;

    avg_receipt_size := receipt_total_bytes / 100.0;
    avg_capsule_size := capsule_total_bytes / 100.0;
    
    RAISE NOTICE '================================================================================';
    RAISE NOTICE 'LCM STORAGE SAVINGS MODEL (Rigorous `pg_column_size` Test)';
    RAISE NOTICE 'NOTE: Materialization rate is an assumed input, not observed production data.';
    RAISE NOTICE '================================================================================';
    
    RAISE NOTICE 'Avg Receipt Size (Hot):    % bytes', round(avg_receipt_size, 2);
    RAISE NOTICE 'Avg Capsule Size (Mat.):   % bytes', round(avg_capsule_size, 2);
    RAISE NOTICE 'Ratio (Receipt / Capsule): % %%', round((avg_receipt_size / avg_capsule_size) * 100, 2);
    
    RAISE NOTICE '--------------------------------------------------------------------------------';
    RAISE NOTICE 'Sensitivity Table: Blended Storage Savings by Materialization Rate';
    RAISE NOTICE 'Formula: 1 - [(Rate × Capsule_Size + (1 - Rate) × Receipt_Size) / Capsule_Size]';
    RAISE NOTICE '--------------------------------------------------------------------------------';
    
    FOREACH rate IN ARRAY rates
    LOOP
        -- Calculate blended savings
        blended_savings := 1.0 - ((rate * avg_capsule_size + (1.0 - rate) * avg_receipt_size) / avg_capsule_size);
        RAISE NOTICE 'Materialization Rate % %%  |  Blended Relational Storage Savings: % %%', rate * 100, round(blended_savings * 100, 2);
    END LOOP;
    
    RAISE NOTICE '================================================================================';

END $$;
