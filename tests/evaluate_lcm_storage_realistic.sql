-- tests/evaluate_lcm_storage_realistic.sql
--
-- Corrected version of evaluate_lcm_storage.sql.
-- The original used repeat('A', 5000) as the simulated payload, which is a
-- degenerate, zero-entropy string. Postgres TOAST compression collapses that
-- down to nearly nothing, which inflates "cold storage" and "materialized"
-- savings figures with an artifact that has nothing to do with the LCM
-- architecture. Real prompts, RAG context, and tool outputs have the
-- redundancy of natural language, not of a single repeated character.
--
-- This version builds each 5KB payload out of randomly assembled real
-- sentences and code snippets, so compression behaves the way it would on
-- production traffic.

DO $$
DECLARE
    org_id uuid;
    i integer;
    j integer;

    real_data_total_bytes bigint := 0;
    hot_data_total_bytes bigint := 0;
    cold_data_total_bytes bigint := 0;
    materialized_data_total_bytes bigint := 0;

    simulated_payload jsonb;
    payload_hash text;
    context_text text;

    -- A small corpus of realistic sentences / code / RAG-style chunks to
    -- randomly assemble into varied ~5KB payloads. Real production traffic
    -- would have far more variety than this; this is enough to break the
    -- zero-entropy artifact without hand-authoring thousands of unique strings.
    corpus text[] := ARRAY[
        'Please initiate an immediate wire transfer of $150,000.00 to Acme Corp Cloud Solutions for the Q3 infrastructure expansion project.',
        'The VP of Finance has already signed off on the budget allocation, and the authorization is logged under budget line item #402.',
        'Treasury and Capital Allocation Report Q3 2026. Approved Vendor: Acme Corp Cloud Solutions. Budget Line: 402. Signing Authority: Sarah Chen.',
        'Automated Agent Spending Limits. Autonomous systems operating on production gateway nodes are subject to pre-action gate enforcement.',
        'def evaluate_gate(policy_version, requested_amount, delegation_limit):',
        '    if requested_amount > delegation_limit:',
        '        return GateOutcome.ESCALATE',
        '    return GateOutcome.APPROVE',
        'WORM Custody Standard: all evidence of gate evaluations and manual overrides must be written as append-only records.',
        'Receipts must be canonicalized under RFC 8785 and signed via Ed25519 before being committed to the vault.',
        'class ToolInvocation(BaseModel):',
        '    tool_key: str',
        '    parameters: dict',
        '    proof_bundle_id: UUID',
        'CHUNK 2 (procure_guidelines_v4.pdf): default automated payment tool calls are capped at one hundred thousand dollars.',
        'Any transaction exceeding the threshold triggers a gate state of ESCALATE, requiring a valid human override token.',
        'The customer reported that the invoice number did not match the purchase order on file, and requested a manual review.',
        'Model inference completed in 340ms. Token usage: 512 input, 128 output. No policy violations detected during generation.',
        'SELECT organization_id, count(*) FROM receipts WHERE created_at > now() - interval ''1 day'' GROUP BY organization_id;',
        'The retrieval step returned three relevant passages from the vendor onboarding handbook, ranked by cosine similarity.',
        'Escalation acknowledged by principal user_sarah_chen. Justification: approved cloud infrastructure expansion, budget line 402.'
    ];
BEGIN
    CREATE TEMP TABLE temp_cold_blob_realistic (payload jsonb);

    INSERT INTO public.organizations (name, slug)
    VALUES ('LCM Bench Org Realistic', 'lcm-bench-realistic-' || gen_random_uuid())
    RETURNING id INTO org_id;

    SET LOCAL app.current_org_id = org_id;

    FOR i IN 1..1000 LOOP
        -- Assemble a varied ~5KB context by concatenating random real
        -- sentences/code lines until we cross the target length. Each event
        -- gets a different combination and order, so rows aren't identical
        -- either.
        context_text := '';
        WHILE length(context_text) < 5000 LOOP
            context_text := context_text || corpus[1 + floor(random() * array_length(corpus, 1))::int] || ' ';
        END LOOP;

        simulated_payload := jsonb_build_object(
            'prompt', 'Generate a summary and determine required policy gate for this request.',
            'context', context_text
        );
        payload_hash := md5(simulated_payload::text);

        real_data_total_bytes := real_data_total_bytes + pg_column_size(simulated_payload);

        INSERT INTO public.receipts (organization_id, content_hash, signature, receipt_type, event_timestamp, payload)
        VALUES (org_id, payload_hash, '\x00', 'lcm_eval_realistic', now(), '{"status": "ok"}'::jsonb);

        INSERT INTO temp_cold_blob_realistic (payload) VALUES (simulated_payload);

        IF i % 20 = 0 THEN
            INSERT INTO public.evidence_objects (organization_id, content_hash, object_type, payload)
            VALUES (org_id, payload_hash, 'materialized_audit', simulated_payload);
        END IF;
    END LOOP;

    hot_data_total_bytes := pg_total_relation_size('public.receipts');
    cold_data_total_bytes := pg_total_relation_size('temp_cold_blob_realistic');
    materialized_data_total_bytes := pg_total_relation_size('public.evidence_objects');

    RAISE NOTICE '--- LCM Storage Benchmark Results, REALISTIC PAYLOAD (1,000 Events) ---';
    RAISE NOTICE '1. Real Data Size (Raw Payload Bytes): % bytes (~% MB)', real_data_total_bytes, round(real_data_total_bytes / 1048576.0, 2);
    RAISE NOTICE '2. Hot Data Size (Receipts Table + Indexes): % bytes (~% MB)', hot_data_total_bytes, round(hot_data_total_bytes / 1048576.0, 2);
    RAISE NOTICE '3. Cold Data Size (Blob Table + Indexes): % bytes (~% MB)', cold_data_total_bytes, round(cold_data_total_bytes / 1048576.0, 2);
    RAISE NOTICE '4. Materialized Data Size (5%% Audited - Evidence Table): % bytes (~% MB)', materialized_data_total_bytes, round(materialized_data_total_bytes / 1048576.0, 2);

    RAISE NOTICE '--- Savings Analysis ---';
    RAISE NOTICE 'Hot vs Real: % %% reduction in active database memory pressure.', round((1.0 - (hot_data_total_bytes::numeric / real_data_total_bytes::numeric)) * 100, 2);
    RAISE NOTICE 'Cold vs Real: % %% size change moving to cold blob storage (compression only, no data discarded).', round((1.0 - (cold_data_total_bytes::numeric / real_data_total_bytes::numeric)) * 100, 2);
    RAISE NOTICE 'Materialized vs Real: % %% reduction in permanent structured evidence storage.', round((1.0 - (materialized_data_total_bytes::numeric / real_data_total_bytes::numeric)) * 100, 2);

END $$;
