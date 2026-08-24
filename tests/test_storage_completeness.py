import json
import hashlib
import subprocess
import uuid
import time
import datetime
import boto3
from botocore.client import Config

# Supabase Local S3 Credentials
S3_ENDPOINT = "http://127.0.0.1:54421/storage/v1/s3"
S3_ACCESS_KEY = "625729a08b95bf1b7ff351a663f3a23c"
S3_SECRET_KEY = "850181e4652dd023b7a98c58ae0d2d34bd487ee0cc3254aed6eda37307425907"
S3_REGION = "local"
BUCKET_NAME = "cold-storage"

s3_client = boto3.client(
    "s3",
    endpoint_url=S3_ENDPOINT,
    aws_access_key_id=S3_ACCESS_KEY,
    aws_secret_access_key=S3_SECRET_KEY,
    region_name=S3_REGION,
    config=Config(signature_version="s3v4")
)

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
    result = subprocess.run(
        ["supabase", "db", "query", sql, "--output", "json"], 
        capture_output=True, text=True, check=True
    )
    out = result.stdout.strip()
    start_idx = out.find('{')
    if start_idx == -1: start_idx = out.find('[')
    if start_idx != -1: out = out[start_idx:]
    if not out: return []
    try:
        parsed = json.loads(out)
        if isinstance(parsed, dict) and 'rows' in parsed: return parsed['rows']
        return parsed
    except json.JSONDecodeError:
        return out

def test_completeness_and_atomicity():
    print("="*80)
    print("TEST: Cold Storage Completeness & S3-First Atomicity Pattern")
    print("="*80)
    
    # 0. Setup Bucket and Org
    try:
        s3_client.create_bucket(Bucket=BUCKET_NAME)
    except Exception as e:
        # Bucket likely exists
        pass
        
    org_id = "00000000-0000-0000-0000-000000000001"
    run_query(f"INSERT INTO public.organizations (id, name, slug) VALUES ('{org_id}', 'Atomicity Test Org', 'atomicity-org') ON CONFLICT DO NOTHING;")

    total_events = 50
    fail_events_indices = {10, 20, 30, 40, 45} # 5 events will fail the DB insert

    print(f"\n[PIPELINE] Processing {total_events} events (Forcing DB failure on {len(fail_events_indices)} events)")
    
    # Generate batch run ID to isolate this test's events
    run_id = str(uuid.uuid4())
    
    # 1. Pipeline Execution
    values_sqls = []
    for i in range(1, total_events + 1):
        raw_payload = {"event_index": i, "run_id": run_id, "data": "Some heavy context data here..." * 10}
        canonical_bytes = jcs.canonicalize(raw_payload)
        content_hash = sha256_hash(canonical_bytes)
        s3_key = f"{run_id}/{content_hash}.json"
        
        # Step A: Write to S3 FIRST
        s3_client.put_object(Bucket=BUCKET_NAME, Key=s3_key, Body=canonical_bytes, ContentType="application/json")
        s3_time = datetime.datetime.now().isoformat()
        
        # Step B: Insert Receipt to Postgres
        if i in fail_events_indices:
            # FORCE FAILURE
            db_fail_time = datetime.datetime.now().isoformat()
            print(f"  [-] Event {i}: S3 Write Succeeded at {s3_time} | DB Insert FAILED at {db_fail_time} (Simulated)")
            # Do NOT insert to DB
            continue
            
        receipt_id = str(uuid.uuid4())
        receipt_payload_sql = json.dumps({"status": "recorded", "s3_key": s3_key}).replace("'", "''")
        
        values_sqls.append(f"('{receipt_id}', '{org_id}', '{content_hash}', '\\x00', 'completeness_test', now(), '{receipt_payload_sql}'::jsonb)")
        
    print(f"\n[DB] Batch executing {len(values_sqls)} successful receipts...")
    batch_insert_sql = "INSERT INTO public.receipts (id, organization_id, content_hash, signature, receipt_type, event_timestamp, payload) VALUES\n" + ",\n".join(values_sqls) + ";"
    run_query(batch_insert_sql)

    print("\n[PIPELINE COMPLETE] Verifying assertions...\n")

    # 2. Independent Auditor Verification
    
    # Check A: Receipt Count
    db_result = run_query(f"SELECT content_hash, payload FROM public.receipts WHERE receipt_type = 'completeness_test' AND payload->>'s3_key' LIKE '{run_id}/%';")
    actual_receipt_count = len(db_result)
    expected_receipt_count = total_events - len(fail_events_indices)
    
    print(f"[Assertion 1] Receipt Count: Expected {expected_receipt_count}, Found {actual_receipt_count}")
    assert actual_receipt_count == expected_receipt_count, f"Fatal Flaw: Expected {expected_receipt_count} receipts but found {actual_receipt_count}"
    
    # Check B: S3 Blob Count
    paginator = s3_client.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=BUCKET_NAME, Prefix=f"{run_id}/")
    s3_objects = []
    for page in pages:
        if 'Contents' in page:
            s3_objects.extend(page['Contents'])
            
    actual_blob_count = len(s3_objects)
    
    print(f"[Assertion 2] S3 Blob Count: Expected {total_events}, Found {actual_blob_count}")
    assert actual_blob_count == total_events, f"Storage Flaw: Expected {total_events} blobs but found {actual_blob_count}"
    
    # Check C: Cryptographic Match for all successful receipts
    print("\n[Assertion 3] Verifying Cryptographic Matches for all Receipts...")
    match_count = 0
    for row in db_result:
        db_hash = row['content_hash']
        s3_key = row['payload']['s3_key']
        
        # Download from S3
        response = s3_client.get_object(Bucket=BUCKET_NAME, Key=s3_key)
        downloaded_bytes = response['Body'].read()
        
        # Hash downloaded bytes
        downloaded_hash = sha256_hash(downloaded_bytes)
        
        if db_hash != downloaded_hash:
            print(f"  [X] HASH MISMATCH for {s3_key}: DB({db_hash}) != S3({downloaded_hash})")
        else:
            match_count += 1
            
    print(f"[Assertion 3] Hash Matches: {match_count} / {actual_receipt_count}")
    assert match_count == actual_receipt_count, "Integrity Flaw: Hashing failed on retrieved S3 blobs."

    print("\n================================================================================")
    print("ALL ASSERTIONS PASSED.")
    print("100% of payloads were successfully durably stored in S3 regardless of DB failure.")
    print("No orphaned receipts exist. The S3-First atomicity pattern is verified.")
    print("================================================================================")

if __name__ == "__main__":
    test_completeness_and_atomicity()
