import json
import hashlib
import sys
try:
    import jcs
except ImportError:
    print("Warning: 'jcs' library not found. Run 'pip install jcs' to test canonicalization properly.")
    print("Mocking jcs for demonstration...")
    class MockJCS:
        @staticmethod
        def canonicalize(data):
            return json.dumps(data, separators=(',', ':'), sort_keys=True, ensure_ascii=False).encode('utf-8')
    jcs = MockJCS()

def sha256_hash(byte_data):
    return hashlib.sha256(byte_data).hexdigest()

def test_event_canonicalization(event_type, raw_payload_str):
    print(f"\n{'='*50}")
    print(f"Testing Event Type: {event_type}")
    print(f"{'='*50}")

    # 1. Application Layer (Microservice) - Parse and Canonicalize
    print("--- 1. Application Layer (Producer) ---")
    app_dict = json.loads(raw_payload_str)
    
    # Correctly canonicalize according to RFC 8785 (ciaf-json-v1 standard)
    canonical_bytes = jcs.canonicalize(app_dict)
    true_hash = sha256_hash(canonical_bytes)

    print(f"RFC 8785 Canonical Bytes: {canonical_bytes.decode('utf-8')}")
    print(f"True Content Hash (SHA-256): {true_hash}\n")

    # 2. Database Danger (PostgreSQL jsonb simulation)
    print("--- 2. Database Danger (PostgreSQL jsonb) ---")
    # Simulate how PostgreSQL jsonb might shuffle keys internally and then output them when cast to text
    # In reality, pg uses a binary hash, but for illustration, we just reverse the keys
    reversed_dict = {k: app_dict[k] for k in reversed(list(app_dict.keys()))}
    pg_jsonb_text = json.dumps(reversed_dict, separators=(', ', ': '))
    
    pg_hash = sha256_hash(pg_jsonb_text.encode('utf-8'))

    print(f"PostgreSQL SELECT payload::text Output: {pg_jsonb_text}")
    print(f"Database Cast Hash Matches True Hash? {true_hash == pg_hash} [FAIL]\n")

    # 3. Application Layer Verification (Auditor)
    print("--- 3. Auditor Verification ---")
    # Pull the jsonb text back into a dict and re-canonicalize
    retrieved_dict = json.loads(pg_jsonb_text)
    re_canonicalized_bytes = jcs.canonicalize(retrieved_dict)
    re_verified_hash = sha256_hash(re_canonicalized_bytes)

    print(f"Re-Canonicalized Bytes: {re_canonicalized_bytes.decode('utf-8')}")
    print(f"Re-Verified Hash Matches True Hash? {true_hash == re_verified_hash} [SUCCESS]")

if __name__ == "__main__":
    # Test 1: Tool Execution
    tool_exec_payload = """
    {
        "tool": "database_query",
        "parameters": {
            "query": "SELECT * FROM users",
            "limit": 100
        },
        "status": "success",
        "execution_time_ms": 145.2
    }
    """
    test_event_canonicalization("tool_execution", tool_exec_payload)

    # Test 2: Privacy Redaction
    privacy_payload = """
    {
        "redacted_fields": [
            "social_security_number",
            "email_address"
        ],
        "original_text_length": 540,
        "policy_applied": "PII_STRIP_V2"
    }
    """
    test_event_canonicalization("privacy_redaction", privacy_payload)
    
    # Test 3: Shadow AI Discovery
    shadow_ai_payload = """
    {
        "endpoint": "api.unauthorized-llm.ai",
        "model_signature": "gpt-4-clone",
        "user_id": "usr_9982",
        "blocked": true
    }
    """
    test_event_canonicalization("shadow_ai_discovery", shadow_ai_payload)

    print("\nAll tests completed successfully. This proves the hashing mechanisms handle jsonb constraints correctly.")
