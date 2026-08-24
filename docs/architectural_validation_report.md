# Architectural Validation Report: AI Event Schema & LCM Storage
**Date:** August 23, 2026

## Version & Supersession Note

**Document:** architectural_validation_report.md
**Date generated:** 2026-08-23
**Scripts executed this run:**
- `test_true_db_roundtrip.py` — `tests/test_true_db_roundtrip.py` 
- `test_canonicalization_db.py` — `tests/test_canonicalization_db.py`
- `test_corpus_compression.py` — `tests/test_corpus_compression.py`
- `evaluate_lcm_storage_rigorous.sql` — `tests/evaluate_lcm_storage_rigorous.sql`
- `test_storage_completeness.py` — `tests/test_storage_completeness.py`
- `test_retry_idempotency.py` — `tests/test_retry_idempotency.py`
- `test_orphan_cleanup.py` — `tests/test_orphan_cleanup.py`

**Known older/sibling scripts NOT run, and why:**
- `evaluate_lcm_storage.sql` — superseded by `evaluate_lcm_storage_rigorous.sql` because used degenerate synthetic payload causing TOAST compression artifact

**Relationship to prior documents:**
- [x] This document supersedes: `lcm_storage_evaluation.md` — reason: Replaces flawed TOAST artifact methodology with rigorous `pg_column_size` benchmarking for all LCM storage claims.
- [x] This document is superseded by: `AGEI-BENCH-012-revision2`, Section 3 (LCM claim only) — reason: The 90.82% modeled metric is superseded by the 96.67% live-measured metric using `pg_total_relation_size()`. Sections 1, 2, 4, 5, and 6 of this document are unaffected and remain current.
- [ ] This document is standalone / does not conflict with prior documents
- [ ] UNRESOLVED CONFLICT — flagged for human review, not yet reconciled: [describe the conflicting claim and both source numbers]
- **Note:** Refer to `AGEI-BENCH-012-revision2` §6.1 for documentation on the migration defect (not tested in this scope).

**Claims in this document, by evidentiary status:**
| Claim | Status (MEASURED / MODELED) | Source |
|---|---|---|
| LCM Storage Savings at 5% rate | MODELED (SUPERSEDED) | `evaluate_lcm_storage_rigorous.sql` |
| Canonicalization gzip savings < 3% | MEASURED | `test_corpus_compression.py` |
| S3-First prevents orphaned receipts | MEASURED | `test_storage_completeness.py` |
| Idempotency prevents storage bloat | MEASURED | `test_retry_idempotency.py` |
| Grace period protects in-flight writes| MEASURED | `test_orphan_cleanup.py` |

**Scope boundary:** This document does not establish: Performance benchmarks of LCM extraction, DB index performance at massive scale, or network latency implications.

This document records the empirical data generated from the testing of the AI Event Schema, Lazy Capsule Materialization (LCM) storage footprint, and RFC 8785 Canonicalization. It contains the raw methodology and execution results of six isolated integration tests run locally.

---

## 1. True DB Roundtrip & Canonicalization Test
**Script:** `test_true_db_roundtrip.py` & `test_canonicalization_db.py`

**Methodology:**
- A raw JSON payload was hashed using SHA-256.
- The payload was inserted into a PostgreSQL `jsonb` column.
- The payload was extracted from the database using a direct text cast (`payload::text`), and hashed again.
- The payload was extracted as JSON, re-canonicalized in Python, and hashed again.

**Empirical Results:**
- Original Hash (App Layer): `b5667cb29f0d706b6eec156028319e2a8b8887648c1921b849b7d4605db43023`
- Database Cast (`payload::text`) Hash: `[FAIL]` (Hashes did not match due to `{"execution_time_ms": 145.2, "status": "success", "parameters": {"query": "SELECT * FROM users", "limit": 100}, "tool": "database_query"}`)
- Re-Canonicalized Hash (Auditor Layer): `b5667cb29f0d706b6eec156028319e2a8b8887648c1921b849b7d4605db43023`

**Factual Conclusion:**
PostgreSQL `jsonb` natively alters lexical structure (whitespace injection and key reordering), causing a cryptographic hash to fail if performed on the direct database export. True cryptographic roundtrips require application-layer re-canonicalization.

---

## 2. Cold Storage Compression Test
**Script:** `test_corpus_compression.py`

**Methodology:**
- Generated a synthetic corpus of 500 AI event payloads.
- Measured the byte size of each payload under three formats: Pretty-Printed Indent=2, Pretty-Printed Indent=4, and RFC 8785 Canonicalized.
- Compressed all three datasets using the standard `gzip` DEFLATE algorithm.
- Measured the resulting byte sizes.

**Empirical Results:**
| Metric | Uncompressed Size | GZIP Compressed Size |
| :--- | :--- | :--- |
| Indent=2 Payload | 623,747 bytes | 487,257 bytes |
| Indent=4 Payload | 644,223 bytes | 490,093 bytes |
| RFC 8785 Canonical | 592,895 bytes | 477,352 bytes |

- Canonical vs Indent 2 Uncompressed: 4.95% reduction
- Canonical vs Indent 4 Uncompressed: 7.97% reduction
- Canonical vs Indent 2 Compressed (GZIP): 2.03% reduction
- Canonical vs Indent 4 Compressed (GZIP): 2.60% reduction

**Factual Conclusion:**
After standard `gzip` compression is applied in cold storage, canonicalization reduces byte size by less than 3%.

---

## 3. LCM Database Storage Benchmark
**Script:** `evaluate_lcm_storage_rigorous.sql`

**Methodology:**
- Inserted 100 receipt records into the `receipts` table (Hot Pool).
- Inserted 100 full payload records into the `evidence_objects` table (Materialized Pool).
- Utilized the native PostgreSQL `pg_column_size()` function to measure the exact byte storage consumed per row.

**Empirical Results:**
- Average Receipt Row Size: 208.00 bytes
- Average Capsule Row Size: 4,731.50 bytes
- Ratio (Receipt / Capsule): 4.40%

Calculated Blended Relational Storage Savings (Formula: `1 - [(Rate × Capsule_Size + (1 - Rate) × Receipt_Size) / Capsule_Size]`):
- At 1% Materialization Rate: 94.65% reduction
- At 5% Materialization Rate: 90.82% reduction
- At 10% Materialization Rate: 86.04% reduction
- At 25% Materialization Rate: 71.70% reduction

**Factual Conclusion:**
Storing a cryptographic receipt consumes approximately 4.4% of the relational database space required to store the full capsule payload. 

---

## 4. Dual-Write Atomicity and Completeness Test
**Script:** `test_storage_completeness.py`

**Methodology:**
- Attempted to process 50 payloads using an "S3-First" write order (Write to S3, then Insert to DB).
- Injected a simulated database insertion failure on 5 of the 50 events immediately after the S3 write successfully completed.
- Queried the PostgreSQL `receipts` table for total successful events.
- Queried the S3 bucket for total stored objects.
- Downloaded the S3 objects referenced by the successful receipts and hashed them to verify against the database `content_hash`.

**Empirical Results:**
- Total DB Receipts Found: 45
- Total S3 Blobs Found: 50
- Number of Receipts lacking an S3 Blob: 0
- Cryptographic Hash Matches: 45 / 45

**Factual Conclusion:**
An "S3-First" write order results in orphaned blobs (5) when the database fails, but produces 0 orphaned database receipts. All successfully recorded database receipts point to intact, cryptographically verified blobs in cold storage.

---

## 5. Retry Idempotency Test
**Script:** `test_retry_idempotency.py`

**Methodology:**
- Generated a logical event bound to a static `idempotency_key` (UUID `4bf61913-b1b2-4c83-8ace-9da5b35a7de2`).
- Simulated Attempt 1: Generated the canonical bytes, wrote to S3, simulated DB failure.
- Simulated Attempt 2 (Retry): Re-serialized the payload for the same event, generated canonical bytes, wrote to S3, succeeded DB insertion.
- Asserted the canonical bytes across attempts.
- Counted the total instances/versions of the blob in S3.

**Empirical Results:**
- Payload Bytes (Attempt 1): `b'{"data":"Important compliance data","event_timestamp":"2025-01-01T12:00:00Z","idempotency_key":"4bf61913-b1b2-4c83-8ace-9da5b35a7de2"}'`
- Payload Bytes (Attempt 2): `b'{"data":"Important compliance data","event_timestamp":"2025-01-01T12:00:00Z","idempotency_key":"4bf61913-b1b2-4c83-8ace-9da5b35a7de2"}'`
- S3 Key Generated: `idempotency_test/92fc2a8ce0bd7ed69eda8348364597308f0ff428b11772e44ba6bee3103e9dce.json`
- Total versions of the object found in the S3 bucket: 1

**Factual Conclusion:**
When a payload relies on a static `idempotency_key` and contains no request-time variables (e.g., `datetime.now()`), retries generate byte-identical payloads and identical S3 keys. S3 overwrites the existing key, producing 1 final blob.

---

## 6. Orphan Cleanup and Race Condition Test
**Script:** `test_orphan_cleanup.py`

**Methodology:**
- Uploaded 5 specific test blobs into S3 to test cleanup boundaries against a 60-minute Grace Period.
- Case 1: 65 minutes old, no DB receipt (True Orphan)
- Case 2: 2 minutes old, no DB receipt (Simulating an In-Flight Write)
- Case 3: 65 minutes old, HAS DB receipt (Valid Event)
- Case 4: 59 minutes, 59 seconds old, no DB receipt
- Case 5: 60 minutes, 01 seconds old, no DB receipt
- Ran a cleanup job that evaluates `Now - LastModified > 60m`, checks the DB for a receipt, and deletes the S3 blob if none exists.
- The job appended a JSON record to an audit file (`orphan_deletions.jsonl`) for each deletion.

**Empirical Results:**
- Case 1 (65m True Orphan): Deleted
- Case 2 (2m In-Flight Write): Retained
- Case 3 (65m Valid Event): Retained
- Case 4 (59:59 Boundary): Retained
- Case 5 (60:01 Boundary): Deleted
- Number of log lines appended to the audit file: 2

**Factual Conclusion:**
A cleanup script utilizing a 60-minute Grace Period deletes orphaned blobs older than 60 minutes, while retaining blobs younger than 60 minutes (in-flight writes) and blobs of any age that possess a corresponding database receipt.
