import json
import hashlib

def jcs_canonicalize(obj):
    # Extremely basic RFC 8785 compliance: sort keys, remove whitespace
    return json.dumps(obj, sort_keys=True, separators=(',', ':')).encode('utf-8')

# Two semantically identical objects with different formatting
obj_a = {"name": "Audit Vault", "status": "active", "id": 105}
obj_b = {"id": 105, "status": "active", "name": "Audit Vault"}

canonical_a = jcs_canonicalize(obj_a)
canonical_b = jcs_canonicalize(obj_b)

hash_a = hashlib.sha256(canonical_a).hexdigest()
hash_b = hashlib.sha256(canonical_b).hexdigest()

print("Object A bytes:", canonical_a.decode())
print("Object B bytes:", canonical_b.decode())
print("Hash A:", hash_a)
print("Hash B:", hash_b)
print("Hashes match:", hash_a == hash_b)
