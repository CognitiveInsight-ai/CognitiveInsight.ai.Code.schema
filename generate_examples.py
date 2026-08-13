import os
import sqlite3
import json
import zipfile

# Define directories
dirs = [
    "01_Architecture",
    "02_Contribute",
    "03_Governance_Domains/Model_Governance",
    "03_Governance_Domains/Agent_Governance",
    "03_Governance_Domains/Human_in_the_Loop",
    "03_Governance_Domains/Policy_and_Authority",
    "03_Governance_Domains/Evidence_and_Assurance",
    "03_Governance_Domains/Evidence_Vault",
    "03_Governance_Domains/Provenance_and_Transparency",
    "03_Governance_Domains/Shadow_AI",
    "03_Governance_Domains/Privacy_and_Data_Governance",
    "04_Open_Schema",
    "05_Interoperability",
    "06_Canonicalization",
    "07_Quantum_Readiness"
]

base_path = "ci_examples"
os.makedirs(base_path, exist_ok=True)
for d in dirs:
    os.makedirs(os.path.join(base_path, os.path.normpath(d)), exist_ok=True)

# 1. Architecture Layer Manifest
arch_manifest = {
    "framework": "AI Governance Evidence Infrastructure (AGEI)",
    "version": "1.0.0",
    "layers": [
        {"layer": 1, "name": "Policy Intent", "tables": ["policy_sets", "policy_versions", "policy_rules"]},
        {"layer": 2, "name": "Rule Evaluation", "tables": ["policy_evaluations"]},
        {"layer": 3, "name": "Gate Enforcement", "tables": ["gate_definitions", "gate_evaluations"]},
        {"layer": 4, "name": "Lifecycle Registry", "tables": ["ai_lifecycle_objects", "ai_lifecycle_object_links"]},
        {"layer": 5, "name": "Receipts", "tables": ["receipts", "receipt_links"]},
        {"layer": 6, "name": "Evidence Payloads", "tables": ["evidence_objects"]},
        {"layer": 7, "name": "Vault Custody", "tables": ["vault_objects", "receipt_batches"]},
        {"layer": 8, "name": "Audit Export", "tables": ["audit_packs", "verification_jobs"]}
    ]
}
with open(os.path.join(base_path, os.path.normpath("01_Architecture/architecture_layers_manifest.json")), "w") as f:
    json.dump(arch_manifest, f, indent=2)

# 2. Contributing script
onboarding_sh = """#!/bin/bash
echo "=== CognitiveInsight.ai Developer Onboarding ==="
echo "[+] Checking environment..."
python3 --version || { echo "[-] Python3 required"; exit 1; }
echo "[+] Creating virtual environment..."
python3 -m venv venv && source venv/bin/activate
echo "[+] Installing JCS library..."
pip install jcs cryptography PyYAML
echo "[+] Running local canonicalization test..."
python3 06_Canonicalization/canonicalize_and_hash.py
echo "[+] Onboarding complete!"
"""
with open(os.path.join(base_path, os.path.normpath("02_Contribute/contributing_onboarding.sh")), "w") as f:
    f.write(onboarding_sh)

# 3. Model Gate Check
model_gate = {
    "artifact_id": "model_risk_valuation_v4",
    "gate_definition_id": "production_release_gate",
    "status": "APPROVED",
    "evaluations": [
        {"rule": "bias_detection_check", "status": "PASS", "score": 0.98},
        {"rule": "accuracy_threshold_check", "status": "PASS", "score": 0.94}
    ]
}
with open(os.path.join(base_path, os.path.normpath("03_Governance_Domains/Model_Governance/model_gate_check.json")), "w") as f:
    json.dump(model_gate, f, indent=2)

# 4. Agent Delegation Session
agent_delegation = {
    "session_id": "session_883a_992f",
    "parent_agent_id": "orchestrator_agent_01",
    "child_agent_id": "db_writer_agent_05",
    "delegated_tools": ["write_record", "query_table"],
    "access_token_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "valid_until": "2026-08-12T14:00:00Z"
}
with open(os.path.join(base_path, os.path.normpath("03_Governance_Domains/Agent_Governance/agent_delegation_session.json")), "w") as f:
    json.dump(agent_delegation, f, indent=2)

# 5. HITL Override Escalation
hitl_override = {
    "escalation_id": "esc_9921_f92",
    "gate_evaluation_id": "gate_eval_331b",
    "is_overridden": True,
    "override_reason": "Emergency production database failover recovery sequence validation bypass",
    "override_by_principal": "user_principal_root_admin",
    "signature": "3045022100e47087e3845bbfef71c9db878cb123df7a76059d0fbbf9659b9ec885c7bb5e50022026..."
}
with open(os.path.join(base_path, os.path.normpath("03_Governance_Domains/Human_in_the_Loop/hitl_override_escalation.json")), "w") as f:
    json.dump(hitl_override, f, indent=2)

# 6. Policy Set Definition
policy_yaml = """
policy_set:
  id: enterprise_safety_policy_v2
  rules:
    - id: disparage_impact_check
      threshold: 0.80
      severity: BLOCK
    - id: accuracy_threshold_check
      threshold: 0.90
      severity: BLOCK
"""
with open(os.path.join(base_path, os.path.normpath("03_Governance_Domains/Policy_and_Authority/policy_set_definition.yaml")), "w") as f:
    f.write(policy_yaml)

# 7. Signed Evidence Receipt
evidence_receipt = {
    "receipt_id": "rec_01_8ab93f",
    "canonicalization_version": "ciaf-json-v1",
    "hash_algorithm": "SHA-256",
    "payload_hash": "f295a32f508a8a86756819fb6d8fb483e5812e9b068eb43e1d51a9e8b70f0322",
    "signature_algorithm": "Ed25519",
    "signature": "d38402f093bc821a81...[classical_signature]"
}
with open(os.path.join(base_path, os.path.normpath("03_Governance_Domains/Evidence_and_Assurance/signed_evidence_receipt.json")), "w") as f:
    json.dump(evidence_receipt, f, indent=2)

# 8. Merkle Proof Manifest
merkle_proof = {
    "batch_id": "batch_q3_2026_01",
    "merkle_root": "8ab9f302b1c402a5e98bbcf7a0928e1008d5bbf0287ab6591024bc68e09f8723",
    "target_receipt_id": "rec_01_8ab93f",
    "proof_path": [
        {"position": "left", "hash": "7f8832a5bf992e1"},
        {"position": "right", "hash": "e3b0c44298fc1c1"}
    ]
}
with open(os.path.join(base_path, os.path.normpath("03_Governance_Domains/Evidence_Vault/merkle_proof_manifest.json")), "w") as f:
    json.dump(merkle_proof, f, indent=2)

# 9. Dual State Provenance
provenance = {
    "artifact_id": "release_pdf_compliance_report_q2",
    "hashes": {
        "pre_watermark": "8ab9f302b1c402a5e98bbcf7a0928e1008d5bbf0287ab6591024bc68e09f8723",
        "post_watermark": "f295a32f508a8a86756819fb6d8fb483e5812e9b068eb43e1d51a9e8b70f0322"
    },
    "watermark": {
        "type": "C2PA_metadata_block",
        "embed_at": "2026-08-12T10:00:00Z"
    },
    "forensic_fingerprint": {
        "algorithm": "Distinctive-Anchor-Method",
        "shingles": ["the_quick_brown", "fox_jumps_over", "lazy_dog_compliance"]
    }
}
with open(os.path.join(base_path, os.path.normpath("03_Governance_Domains/Provenance_and_Transparency/dual_state_provenance.json")), "w") as f:
    json.dump(provenance, f, indent=2)

# 10. Shadow AI Telemetry
shadow_ai = {
    "discovery_id": "disc_8829a",
    "destination_endpoint": "https://api.unapproved-llm.com/v1/chat",
    "user_identity_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b",
    "risk_classification": "MEDIUM_RISK",
    "remediation_route": "MIGRATE_TO_SANCTIONED_PORTAL"
}
with open(os.path.join(base_path, os.path.normpath("03_Governance_Domains/Shadow_AI/shadow_ai_telemetry.json")), "w") as f:
    json.dump(shadow_ai, f, indent=2)

# 11. Privacy Redaction Receipt
privacy_redaction = {
    "redaction_id": "redact_991f8",
    "target_receipt_id": "rec_01_8ab93f",
    "erased_fields": ["customer_email", "customer_phone_number"],
    "salt_hash_replacement": "8ab9f302b1c402a5e98bbcf7a0928e1008d5bbf0287a",
    "integrity_verification": "VALID"
}
with open(os.path.join(base_path, os.path.normpath("03_Governance_Domains/Privacy_and_Data_Governance/privacy_redaction_receipt.json")), "w") as f:
    json.dump(privacy_redaction, f, indent=2)

# 12. SQLite Schema and DB Seed
sql_seed = """
CREATE TABLE IF NOT EXISTS ai_lifecycle_objects (
    object_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_sessions (
    session_id TEXT PRIMARY KEY,
    agent_principal_id TEXT NOT NULL,
    delegating_principal_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_delegations (
    delegation_id TEXT PRIMARY KEY,
    delegating_principal TEXT NOT NULL,
    agent_principal TEXT NOT NULL,
    authority_scope TEXT NOT NULL,
    token_hash TEXT NOT NULL,
    valid_until TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS shadow_ai_discovery_records (
    discovery_id TEXT PRIMARY KEY,
    destination_endpoint TEXT NOT NULL,
    payload_hash TEXT,
    risk_score INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed Data
INSERT OR IGNORE INTO ai_lifecycle_objects (object_id, name, type, hash) 
VALUES ('model_risk_valuation_v4', 'Risk Valuation Model', 'model', '8ab9f302b1c402a5e98bbcf7a0928e1008d5bbf0287ab6591024bc68e09f8723');

INSERT OR IGNORE INTO agent_sessions (session_id, agent_principal_id, delegating_principal_id) 
VALUES ('session_883a_992f', 'db_writer_agent_05', 'orchestrator_agent_01');

INSERT OR IGNORE INTO agent_delegations (delegation_id, delegating_principal, agent_principal, authority_scope, token_hash, valid_until) 
VALUES ('del_883a', 'orchestrator_agent_01', 'db_writer_agent_05', 'write_record,query_table', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', '2026-08-12 14:00:00');

INSERT OR IGNORE INTO shadow_ai_discovery_records (discovery_id, destination_endpoint, payload_hash, risk_score) 
VALUES ('disc_8829a', 'https://api.unapproved-llm.com/v1/chat', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b', 50);
"""
with open(os.path.join(base_path, os.path.normpath("04_Open_Schema/sqlite_schema_seed.sql")), "w") as f:
    f.write(sql_seed)

# Create active SQLite DB
db_path = os.path.join(base_path, os.path.normpath("04_Open_Schema/cognitiveinsight_sample.db"))
conn = sqlite3.connect(db_path)
conn.executescript(sql_seed)
conn.commit()
conn.close()

# 13. MLflow Bridge Webhook
mlflow_bridge = {
    "event": "model_version_promoted",
    "model_name": "Risk_Valuation_Model",
    "version": "4",
    "target_stage": "Production",
    "webhook_trigger_url": "https://cognitiveinsight.ai/api/v1/gate/evaluate"
}
with open(os.path.join(base_path, os.path.normpath("05_Interoperability/mlflow_bridge_webhook.json")), "w") as f:
    json.dump(mlflow_bridge, f, indent=2)

# 14. JCS script
jcs_script = """import json
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
"""
with open(os.path.join(base_path, os.path.normpath("06_Canonicalization/canonicalize_and_hash.py")), "w") as f:
    f.write(jcs_script)

# 15. Hybrid signatures
hybrid_quantum = {
    "receipt_id": "rec_01_8ab93f",
    "algorithms": {
        "classical": "Ed25519",
        "post_quantum": "ML-DSA-65"
    },
    "signatures": {
        "classical_sig": "d38402f093bc821a81...",
        "post_quantum_sig": "ml_dsa_65_signature_3300_bytes_of_lattice_parameters_..."
    }
}
with open(os.path.join(base_path, os.path.normpath("07_Quantum_Readiness/hybrid_quantum_signature.json")), "w") as f:
    json.dump(hybrid_quantum, f, indent=2)

# Build zip
zip_out_path = "cognitiveinsight-examples.zip"
with zipfile.ZipFile(zip_out_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk(base_path):
        for file in files:
            file_path = os.path.join(root, file)
            # preserve relative path structure in zip
            rel_path = os.path.relpath(file_path, base_path)
            zipf.write(file_path, rel_path)

print("[+] Done compiling and zipping")
