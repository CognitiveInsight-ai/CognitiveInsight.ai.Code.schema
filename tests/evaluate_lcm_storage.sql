-- tests/evaluate_lcm_storage.sql

-- Benchmark script to measure exact bytes for Real, Hot, Cold, and Materialized data sizes.

DO $$
DECLARE
    org_id uuid;
    i integer;
    
    -- Size tracking variables
    real_data_total_bytes bigint := 0;
    hot_data_total_bytes bigint := 0;
    cold_data_total_bytes bigint := 0;
    materialized_data_total_bytes bigint := 0;
    
    simulated_payload jsonb;
    payload_hash text;
    receipt_type text;
BEGIN
    CREATE TEMP TABLE temp_cold_blob (payload jsonb);

    -- Create Org for Benchmark
    INSERT INTO public.organizations (name, slug) VALUES ('LCM Bench Org', 'lcm-bench-' || gen_random_uuid()) RETURNING id INTO org_id;
    
    SET LOCAL app.current_org_id = org_id;

    -- Generate 1000 events
    FOR i IN 1..1000 LOOP
        -- Simulate various AI events based on schema
        IF i % 5 = 0 THEN
            receipt_type := 'gate_evaluation';
            simulated_payload := ('{"gate_id": "gate_123", "policy": "no_pii", "context": "' || repeat('B', 1000) || '"}')::jsonb;
        ELSIF i % 5 = 1 THEN
            receipt_type := 'tool_execution';
            simulated_payload := ('{"tool": "database_query", "query_context": "' || repeat('C', 5000) || '"}')::jsonb;
        ELSIF i % 5 = 2 THEN
            receipt_type := 'privacy_redaction';
            simulated_payload := ('{"redacted_fields": ["ssn", "email"], "original_text": "' || repeat('D', 4000) || '"}')::jsonb;
        ELSIF i % 5 = 3 THEN
            receipt_type := 'shadow_ai_discovery';
            simulated_payload := '{"model": "unauthorized-llm", "endpoint": "api.shadow.com"}'::jsonb;
        ELSE
            receipt_type := 'agent_action';
            simulated_payload := ('{"agent_id": "agent_x", "thought_process": "' || repeat('E', 2000) || '"}')::jsonb;
        END IF;
        
        -- Use a dummy hash representing SHA-256 for the benchmark
        payload_hash := md5(simulated_payload::text);
        
        -- 1. Real Data Size (What it costs if we just store the raw JSON directly)
        real_data_total_bytes := real_data_total_bytes + pg_column_size(simulated_payload);

        -- 2. Hot Data Size (The micro-receipt in AGEI)
        -- Insert receipt (Hot Pool)
        INSERT INTO public.receipts (organization_id, content_hash, signature, receipt_type, event_timestamp, payload)
        VALUES (org_id, payload_hash, '\x00', receipt_type, now(), '{"status": "recorded"}'::jsonb);
        
        -- We estimate the hot size as the size of the receipt row. 
        -- In a real table, pg_relation_size is better, but we are aggregating.
        -- We'll query relation size at the end.

        -- 3. Cold Data Size
        -- Insert into a temp table to represent the cold blob storage
        INSERT INTO temp_cold_blob (payload) VALUES (simulated_payload);

        -- 4. Materialized Data Size
        -- Only ~5% of events trigger an audit/materialization.
        IF i % 20 = 0 THEN
            INSERT INTO public.evidence_objects (organization_id, content_hash, object_type, payload)
            VALUES (org_id, payload_hash, 'materialized_audit', simulated_payload);
        END IF;

    END LOOP;

    -- Calculate total table sizes (including indexes and overhead)
    hot_data_total_bytes := pg_total_relation_size('public.receipts');
    cold_data_total_bytes := pg_total_relation_size('temp_cold_blob');
    materialized_data_total_bytes := pg_total_relation_size('public.evidence_objects');

    RAISE NOTICE '--- LCM Storage Benchmark Results (1,000 Events) ---';
    RAISE NOTICE '1. Real Data Size (Raw Payload Bytes): % bytes (~% MB)', real_data_total_bytes, round(real_data_total_bytes / 1048576.0, 2);
    RAISE NOTICE '2. Hot Data Size (Receipts Table + Indexes): % bytes (~% MB)', hot_data_total_bytes, round(hot_data_total_bytes / 1048576.0, 2);
    RAISE NOTICE '3. Cold Data Size (Vault Table + Indexes): % bytes (~% MB)', cold_data_total_bytes, round(cold_data_total_bytes / 1048576.0, 2);
    RAISE NOTICE '4. Materialized Data Size (5%% Audited - Evidence Table): % bytes (~% MB)', materialized_data_total_bytes, round(materialized_data_total_bytes / 1048576.0, 2);
    
    RAISE NOTICE '--- Savings Analysis ---';
    RAISE NOTICE 'Hot vs Real: % %% reduction in active database memory pressure.', round((1.0 - (hot_data_total_bytes::numeric / real_data_total_bytes::numeric)) * 100, 2);
    RAISE NOTICE 'Materialized vs Real: % %% reduction in permanent evidence storage.', round((1.0 - (materialized_data_total_bytes::numeric / real_data_total_bytes::numeric)) * 100, 2);

END $$;
