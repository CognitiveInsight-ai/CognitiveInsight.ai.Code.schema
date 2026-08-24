import json
import hashlib
import subprocess
import uuid

# A simple RFC 8785 compliant canonicalizer (or mockup if jcs is missing)
try:
    import jcs
except ImportError:
    class MockJCS:
        @staticmethod
        def canonicalize(data):
            return json.dumps(data, separators=(',', ':'), sort_keys=True, ensure_ascii=False).encode('utf-8')
    jcs = MockJCS()

def sha256_hash(byte_data):
    return hashlib.sha256(byte_data).hexdigest()

def run_query(sql):
    """Executes a SQL query against the local Supabase DB and returns the JSON output."""
    result = subprocess.run(
        ["supabase", "db", "query", sql, "--output", "json"], 
        capture_output=True, text=True, check=True
    )
    out = result.stdout.strip()
    # The CLI might print "Connecting to local database..." before the JSON. Find the start of JSON.
    start_idx = out.find('{')
    if start_idx == -1:
        start_idx = out.find('[')
        
    if start_idx != -1:
        out = out[start_idx:]
    
    if not out:
        return []
    try:
        parsed = json.loads(out)
        if isinstance(parsed, dict) and 'rows' in parsed:
            return parsed['rows']
        return parsed
    except json.JSONDecodeError:
        return out

def test_full_roundtrip():
    print("="*60)
    print("Testing Full DB Roundtrip (Edge -> Postgres jsonb -> Edge)")
    print("="*60)

    # 1. Edge/JS Client generates a payload
    org_id = "00000000-0000-0000-0000-000000000000" # Dummy UUID
    # Make sure an org exists for foreign keys, or just insert it (we will insert a dummy org first)
    run_query(f"INSERT INTO public.organizations (id, name, slug) VALUES ('{org_id}', 'Test Org', 'test-org-{uuid.uuid4()}') ON CONFLICT DO NOTHING;")

    # The Raw Edge Payload (Notice the unsorted keys and spacing)
    raw_payload = {
        "status": "APPROVED",
        "nested_data": {
            "z_key": 99,
            "a_key": 1
        },
        "id": "event_123"
    }

    # Canonicalize and hash at the Edge
    canonical_bytes_in = jcs.canonicalize(raw_payload)
    hash_in = sha256_hash(canonical_bytes_in)

    print(f"[Edge] Original Payload Bytes: {canonical_bytes_in.decode('utf-8')}")
    print(f"[Edge] True Content Hash: {hash_in}\n")

    # 2. Store in Database (jsonb column)
    # We serialize it to text just to send over SQL, PostgreSQL parses into jsonb
    json_string_for_sql = json.dumps(raw_payload).replace("'", "''")
    receipt_id = str(uuid.uuid4())
    
    insert_sql = f"""
    INSERT INTO public.receipts (id, organization_id, content_hash, signature, receipt_type, event_timestamp, payload)
    VALUES ('{receipt_id}', '{org_id}', '{hash_in}', '\\x00', 'test_roundtrip', now(), '{json_string_for_sql}'::jsonb);
    """
    run_query(insert_sql)
    print(f"[DB] Successfully inserted payload into 'public.receipts' (jsonb) with receipt_id {receipt_id}\n")

    # 3. Retrieve from Database
    # Fetch the jsonb payload back
    select_sql = f"SELECT payload FROM public.receipts WHERE id = '{receipt_id}';"
    db_result = run_query(select_sql)
    
    # db_result looks like: [{"payload": {"id": "event_123", "status": "APPROVED", ...}}]
    retrieved_payload = db_result[0]["payload"]
    
    # 4. Auditor Re-Canonicalization
    canonical_bytes_out = jcs.canonicalize(retrieved_payload)
    hash_out = sha256_hash(canonical_bytes_out)

    print(f"[Auditor] Retrieved Payload from DB: {json.dumps(retrieved_payload)}")
    print(f"[Auditor] Re-Canonicalized Bytes: {canonical_bytes_out.decode('utf-8')}")
    print(f"[Auditor] Computed Hash: {hash_out}\n")

    print(f"CONCLUSION: Data In Hash ({hash_in}) == Data Out Hash ({hash_out})? {'[SUCCESS]' if hash_in == hash_out else '[FAIL]'}")

if __name__ == "__main__":
    test_full_roundtrip()
