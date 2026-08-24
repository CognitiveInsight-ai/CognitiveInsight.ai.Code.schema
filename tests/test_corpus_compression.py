import json
import gzip
import random
import string
try:
    import jcs
except ImportError:
    class MockJCS:
        @staticmethod
        def canonicalize(data):
            return json.dumps(data, separators=(',', ':'), sort_keys=True, ensure_ascii=False).encode('utf-8')
    jcs = MockJCS()

# PRE-REGISTERED HYPOTHESIS:
# If the post-gzip difference between pretty-printed JSON and canonicalized JSON
# is under 3%, we will drop the claim that canonicalization saves meaningful space
# in Cold Storage, as compression makes the whitespace penalty negligible.

def generate_random_string(length):
    return ''.join(random.choices(string.ascii_letters + string.digits + " ", k=length))

def generate_realistic_payload(event_type):
    if event_type == "tool_execution":
        return {
            "type": event_type,
            "tool_name": "database_query_agent",
            "parameters": {
                "sql": "SELECT * FROM users WHERE active = true AND created_at > '2025-01-01'",
                "limit": 1000,
                "timeout_ms": 5000,
                "filters": [generate_random_string(20) for _ in range(5)]
            },
            "output_sample": generate_random_string(1500), # simulate heavy output
            "status": "success",
            "metadata": {
                "latency": random.uniform(10.0, 500.0),
                "retries": 0
            }
        }
    elif event_type == "privacy_redaction":
        return {
            "type": event_type,
            "redacted_fields": ["ssn", "email", "phone_number"],
            "original_text_snippet": generate_random_string(800),
            "policy_applied": "PII_STRIP_V2",
            "confidence_score": random.uniform(0.8, 1.0),
            "model_version": "v3.1.4"
        }
    else:
        return {
            "type": "generic_event",
            "context": generate_random_string(500),
            "tags": ["prod", "compliance", generate_random_string(10)]
        }

def run_test():
    event_types = ["tool_execution", "privacy_redaction", "generic_event"]
    corpus = [generate_realistic_payload(random.choice(event_types)) for _ in range(500)]
    
    total_pretty2 = 0
    total_pretty4 = 0
    total_canonical = 0
    
    total_pretty2_gz = 0
    total_pretty4_gz = 0
    total_canonical_gz = 0

    for payload in corpus:
        # Generate Uncompressed Byte Strings
        pretty2_bytes = json.dumps(payload, indent=2).encode('utf-8')
        pretty4_bytes = json.dumps(payload, indent=4).encode('utf-8')
        canonical_bytes = jcs.canonicalize(payload)
        
        # Accumulate Uncompressed Sizes
        total_pretty2 += len(pretty2_bytes)
        total_pretty4 += len(pretty4_bytes)
        total_canonical += len(canonical_bytes)
        
        # Accumulate Compressed Sizes
        total_pretty2_gz += len(gzip.compress(pretty2_bytes))
        total_pretty4_gz += len(gzip.compress(pretty4_bytes))
        total_canonical_gz += len(gzip.compress(canonical_bytes))

    # Calculate Savings
    saved_2_raw = (1 - total_canonical / total_pretty2) * 100
    saved_4_raw = (1 - total_canonical / total_pretty4) * 100
    
    saved_2_gz = (1 - total_canonical_gz / total_pretty2_gz) * 100
    saved_4_gz = (1 - total_canonical_gz / total_pretty4_gz) * 100

    print("="*80)
    print("CORPUS-BASED CANONICALIZATION & COMPRESSION TEST (500 Payloads)")
    print("="*80)
    print(f"{'Metric':<30} | {'Uncompressed':<20} | {'GZIP Compressed':<20}")
    print("-" * 80)
    print(f"{'Indent=2 Payload Size':<30} | {total_pretty2:<15,d} bytes | {total_pretty2_gz:<15,d} bytes")
    print(f"{'Indent=4 Payload Size':<30} | {total_pretty4:<15,d} bytes | {total_pretty4_gz:<15,d} bytes")
    print(f"{'RFC 8785 Canonical Size':<30} | {total_canonical:<15,d} bytes | {total_canonical_gz:<15,d} bytes")
    print("-" * 80)
    print(f"{'Canonical vs Indent=2 Savings':<30} | {saved_2_raw:<14.2f} %      | {saved_2_gz:<14.2f} %")
    print(f"{'Canonical vs Indent=4 Savings':<30} | {saved_4_raw:<14.2f} %      | {saved_4_gz:<14.2f} %")
    print("="*80)
    
    if saved_2_gz < 3.0 and saved_4_gz < 3.0:
        print("\n[CONCLUSION]: The post-gzip savings are under 3%. We will DROP the claim that canonicalization saves meaningful space in Cold Storage.")
    else:
        print("\n[CONCLUSION]: The post-gzip savings are significant. The claim holds.")

if __name__ == "__main__":
    run_test()
