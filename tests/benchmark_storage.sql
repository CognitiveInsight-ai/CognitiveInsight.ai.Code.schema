-- tests/benchmark_storage.sql

-- Benchmark script to simulate high-volume insertion into hot/cold storage pools.
-- Due to execution time limits in standard tools, this uses a moderate volume to prove functionality.

DO $$
DECLARE
    org_id uuid;
    i integer;
    start_time timestamptz;
    end_time timestamptz;
BEGIN
    -- Create Org for Benchmark
    INSERT INTO public.organizations (name, slug) VALUES ('Benchmark Org', 'bench-org-' || gen_random_uuid()) RETURNING id INTO org_id;
    SET LOCAL app.current_org_id = org_id;

    start_time := clock_timestamp();

    -- Insert 1000 receipts (hot pool)
    FOR i IN 1..1000 LOOP
        INSERT INTO public.receipts (organization_id, content_hash, signature, receipt_type, event_timestamp, payload)
        VALUES (org_id, md5(random()::text), '\x00', 'benchmark', now(), '{}'::jsonb);
    END LOOP;
    
    end_time := clock_timestamp();
    RAISE NOTICE 'Inserted 1000 receipts (Hot Pool) in % ms', extract(milliseconds from (end_time - start_time));

    start_time := clock_timestamp();

    -- Insert 1000 vault objects (cold pool equivalent in schema)
    FOR i IN 1..1000 LOOP
        INSERT INTO public.vault_objects (organization_id, content_hash, signature)
        VALUES (org_id, md5(random()::text), '\x00');
    END LOOP;

    end_time := clock_timestamp();
    RAISE NOTICE 'Inserted 1000 vault objects (Cold Pool) in % ms', extract(milliseconds from (end_time - start_time));

END $$;

RESET ROLE;
