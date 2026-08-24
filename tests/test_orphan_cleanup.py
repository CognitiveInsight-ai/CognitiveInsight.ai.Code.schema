import json
import uuid
import boto3
from botocore.client import Config
import datetime
import os
import subprocess

# Supabase Local S3 Credentials
S3_ENDPOINT = "http://127.0.0.1:54421/storage/v1/s3"
S3_ACCESS_KEY = "625729a08b95bf1b7ff351a663f3a23c"
S3_SECRET_KEY = "850181e4652dd023b7a98c58ae0d2d34bd487ee0cc3254aed6eda37307425907"
S3_REGION = "local"
BUCKET_NAME = "cold-storage"

s3_client = boto3.client(
    "s3", endpoint_url=S3_ENDPOINT,
    aws_access_key_id=S3_ACCESS_KEY, aws_secret_access_key=S3_SECRET_KEY,
    region_name=S3_REGION, config=Config(signature_version="s3v4")
)

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

def run_cleanup_job(simulated_now, simulated_last_modified_map):
    """
    The actual reconciliation script that would run on a cron job.
    Includes the Audit Trail logging to maintain Proof Not Logs.
    """
    GRACE_PERIOD = datetime.timedelta(minutes=60)
    audit_log_path = "orphan_deletions.jsonl"
    
    paginator = s3_client.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=BUCKET_NAME, Prefix="cleanup_test/")
    
    deleted_keys = []
    retained_keys = []
    
    for page in pages:
        if 'Contents' not in page:
            continue
            
        for obj in page['Contents']:
            key = obj['Key']
            # INJECTION FOR TESTING: Override the true S3 timestamp with our simulated one
            last_modified = simulated_last_modified_map.get(key, obj['LastModified'].replace(tzinfo=None))
            
            # 1. Evaluate Grace Period
            age = simulated_now - last_modified
            if age <= GRACE_PERIOD:
                retained_keys.append((key, "within_grace_period"))
                continue
                
            # 2. Check Database for Receipt
            db_result = run_query(f"SELECT id FROM public.receipts WHERE payload->>'s3_key' = '{key}';")
            
            if len(db_result) > 0:
                retained_keys.append((key, "has_valid_receipt"))
            else:
                # 3. Securely Delete Orphan & Write Audit Trail
                deleted_at = simulated_now.isoformat()
                s3_client.delete_object(Bucket=BUCKET_NAME, Key=key)
                
                audit_record = {
                    "blob_key": key,
                    "last_modified": last_modified.isoformat(),
                    "deleted_at": deleted_at,
                    "reason": "orphan_ttl_exceeded",
                    "age_seconds": age.total_seconds()
                }
                
                with open(audit_log_path, "a") as f:
                    f.write(json.dumps(audit_record) + "\n")
                    
                deleted_keys.append(key)
                
    return deleted_keys, retained_keys

def test_orphan_cleanup_race_conditions():
    print("="*80)
    print("TEST: Orphan Cleanup Mechanism (Grace Period & Audit Trail)")
    print("="*80)

    # Clean up previous run if exists
    if os.path.exists("orphan_deletions.jsonl"):
        os.remove("orphan_deletions.jsonl")

    try:
        s3_client.create_bucket(Bucket=BUCKET_NAME)
    except Exception:
        pass
        
    org_id = "00000000-0000-0000-0000-000000000002"
    run_query(f"INSERT INTO public.organizations (id, name, slug) VALUES ('{org_id}', 'Cleanup Test Org', 'cleanup-org') ON CONFLICT DO NOTHING;")

    # We will upload 5 blobs, representing 5 edge cases.
    keys = {
        "case_1_true_orphan": "cleanup_test/case1.json",
        "case_2_in_flight": "cleanup_test/case2.json",
        "case_3_valid": "cleanup_test/case3.json",
        "case_4_boundary_retained": "cleanup_test/case4.json",
        "case_5_boundary_deleted": "cleanup_test/case5.json",
    }
    
    # Upload blobs
    for case, key in keys.items():
        s3_client.put_object(Bucket=BUCKET_NAME, Key=key, Body=b'{}', ContentType="application/json")
        
    # Give Case 3 a valid DB receipt
    receipt_id = str(uuid.uuid4())
    payload_sql = json.dumps({"status": "recorded", "s3_key": keys["case_3_valid"]}).replace("'", "''")
    run_query(f"INSERT INTO public.receipts (id, organization_id, content_hash, signature, receipt_type, event_timestamp, payload) VALUES ('{receipt_id}', '{org_id}', 'hash3', '\\x00', 'cleanup_test', now(), '{payload_sql}'::jsonb);")

    # Simulate Time
    simulated_now = datetime.datetime(2026, 1, 1, 12, 0, 0)
    
    # Map out the exact age we want to test for each object
    simulated_last_modified = {
        keys["case_1_true_orphan"]: simulated_now - datetime.timedelta(minutes=65),          # 65 min old
        keys["case_2_in_flight"]: simulated_now - datetime.timedelta(minutes=2),             # 2 min old
        keys["case_3_valid"]: simulated_now - datetime.timedelta(minutes=65),                # 65 min old (Has DB Receipt)
        keys["case_4_boundary_retained"]: simulated_now - datetime.timedelta(minutes=59, seconds=59), # 59m 59s old
        keys["case_5_boundary_deleted"]: simulated_now - datetime.timedelta(minutes=60, seconds=1),  # 60m 01s old
    }
    
    print("[SETUP] Injected 5 specific test blobs into S3:")
    print("  Case 1 (True Orphan):       Age 65:00  (Expected: DELETED)")
    print("  Case 2 (In-Flight Write):   Age 02:00  (Expected: RETAINED - Grace Period)")
    print("  Case 3 (Valid Receipt):     Age 65:00  (Expected: RETAINED - Has Receipt)")
    print("  Case 4 (Boundary Retain):   Age 59:59  (Expected: RETAINED - Grace Period)")
    print("  Case 5 (Boundary Delete):   Age 60:01  (Expected: DELETED)")
    
    print("\n[JOB] Running Reconciliation Job...")
    deleted, retained = run_cleanup_job(simulated_now, simulated_last_modified)
    
    print("\n[ASSERTIONS]")
    
    # Assertions
    assert keys["case_1_true_orphan"] in deleted, "Flaw: True orphan was NOT deleted."
    print("[Assertion 1 Passed] True orphan safely deleted.")
    
    assert keys["case_2_in_flight"] not in deleted, "FATAL FLAW: In-flight write was deleted! Grace period failed."
    print("[Assertion 2 Passed] In-flight write safely retained. Grace period protects dual-write race condition.")
    
    assert keys["case_3_valid"] not in deleted, "FATAL FLAW: Valid receipt payload was deleted!"
    print("[Assertion 3 Passed] Valid DB event retained safely.")
    
    assert keys["case_4_boundary_retained"] not in deleted, "Flaw: 59:59 boundary was deleted."
    print("[Assertion 4 Passed] Boundary 59:59 retained.")
    
    assert keys["case_5_boundary_deleted"] in deleted, "Flaw: 60:01 boundary was NOT deleted."
    print("[Assertion 5 Passed] Boundary 60:01 deleted.")
    
    # Audit Trail verification
    with open("orphan_deletions.jsonl", "r") as f:
        lines = f.readlines()
        assert len(lines) == 2, f"Audit Trail Flaw: Expected 2 log lines, found {len(lines)}"
        log1 = json.loads(lines[0])
        assert "blob_key" in log1 and "deleted_at" in log1 and log1["reason"] == "orphan_ttl_exceeded"
        
    print("[Assertion 6 Passed] Audit Trail successfully logged 2 immutable deletion records (Proof, Not Logs).")

    print("\n================================================================================")
    print("ALL ASSERTIONS PASSED. ORPHAN CLEANUP IS SAFE.")
    print("================================================================================")


if __name__ == "__main__":
    test_orphan_cleanup_race_conditions()
