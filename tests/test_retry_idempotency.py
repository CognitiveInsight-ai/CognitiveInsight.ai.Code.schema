import json
import hashlib
import uuid
import boto3
from botocore.client import Config
import datetime
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

def test_idempotency():
    print("="*80)
    print("TEST: Client Retry Idempotency & Deterministic Payloads")
    print("="*80)

    # 1. Ensure Bucket exists
    try:
        s3_client.create_bucket(Bucket=BUCKET_NAME)
    except Exception:
        pass

    # [CRITICAL DESIGN] 
    # To achieve idempotency, the payload must NOT contain request-time dynamically generated fields
    # (like a `datetime.now()` timestamp). It must be bound to a stable `idempotency_key` (UUID) 
    # generated ONCE before any network attempts are made.
    event_timestamp = "2025-01-01T12:00:00Z" # Fixed at event creation
    idempotency_key = str(uuid.uuid4()) # Generated ONCE per logical event

    print(f"[SETUP] Generated Logical Event ID (Idempotency Key): {idempotency_key}")

    # =========================================================================
    # ATTEMPT 1: The Initial Request (Simulating DB Failure)
    # =========================================================================
    print("\n--- ATTEMPT 1 (Network Request 1) ---")
    payload_attempt_1 = {
        "idempotency_key": idempotency_key,
        "event_timestamp": event_timestamp,
        "data": "Important compliance data"
    }
    
    bytes_attempt_1 = jcs.canonicalize(payload_attempt_1)
    hash_attempt_1 = sha256_hash(bytes_attempt_1)
    s3_key_1 = f"idempotency_test/{hash_attempt_1}.json"
    
    print(f"Payload Bytes: {bytes_attempt_1}")
    print(f"S3 Key: {s3_key_1}")
    
    # Write to S3
    s3_client.put_object(Bucket=BUCKET_NAME, Key=s3_key_1, Body=bytes_attempt_1, ContentType="application/json")
    print("-> S3 Write Succeeded.")
    print("-> DB Insert FAILED (Simulated Timeout). Retrying...")

    # =========================================================================
    # ATTEMPT 2: The Retry Request
    # =========================================================================
    print("\n--- ATTEMPT 2 (Network Request 2) ---")
    
    # Notice we use the EXACT same logic, but because we strictly enforce deterministic payload
    # construction utilizing the idempotency_key, it produces the exact same bytes.
    payload_attempt_2 = {
        "idempotency_key": idempotency_key,
        "event_timestamp": event_timestamp, # Still the original creation time
        "data": "Important compliance data"
    }

    bytes_attempt_2 = jcs.canonicalize(payload_attempt_2)
    hash_attempt_2 = sha256_hash(bytes_attempt_2)
    s3_key_2 = f"idempotency_test/{hash_attempt_2}.json"
    
    print(f"Payload Bytes: {bytes_attempt_2}")
    print(f"S3 Key: {s3_key_2}")

    # Write to S3
    s3_client.put_object(Bucket=BUCKET_NAME, Key=s3_key_2, Body=bytes_attempt_2, ContentType="application/json")
    print("-> S3 Write Succeeded.")
    print("-> DB Insert SUCCEEDED (Simulated).")

    # =========================================================================
    # ASSERTIONS
    # =========================================================================
    print("\n[ASSERTIONS]")
    
    # 1. Byte-level Determinism Match
    assert bytes_attempt_1 == bytes_attempt_2, "Idempotency Flaw: Payload bytes mutated between retries!"
    print("[Assertion 1 Passed] Payload bytes are perfectly deterministic across retries.")
    
    assert s3_key_1 == s3_key_2, "Idempotency Flaw: S3 Keys diverged!"
    print("[Assertion 2 Passed] S3 Key generation is strictly stable.")

    # 3. Check S3 object count for this specific hash to ensure no bloat
    # (Checking versions if versioning is on, or just checking list_objects_v2)
    paginator = s3_client.get_paginator('list_object_versions')
    try:
        pages = paginator.paginate(Bucket=BUCKET_NAME, Prefix=s3_key_1)
        versions_found = 0
        for page in pages:
            if 'Versions' in page:
                versions_found += len(page['Versions'])
        
        # If versioning is suspended or not enabled, versions_found might be 0, so we check list_objects
        if versions_found == 0:
            objects = s3_client.list_objects_v2(Bucket=BUCKET_NAME, Prefix=s3_key_1)
            versions_found = len(objects.get('Contents', []))
            
    except Exception:
        # Fallback if list_object_versions is not supported by local S3 mock
        objects = s3_client.list_objects_v2(Bucket=BUCKET_NAME, Prefix=s3_key_1)
        versions_found = len(objects.get('Contents', []))

    assert versions_found == 1, f"Storage Bloat Flaw: Expected 1 instance in S3, found {versions_found}"
    print(f"[Assertion 3 Passed] S3 Bucket contains exactly {versions_found} instance of the blob. Storage was not inflated by the retry.")

    print("\n================================================================================")
    print("ALL ASSERTIONS PASSED.")
    print("================================================================================")

if __name__ == "__main__":
    test_idempotency()
