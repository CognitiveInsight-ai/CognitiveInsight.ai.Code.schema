# Storage Claim Decision Log
## Section 7 Addendum: Final Resolution on Storage Savings, Atomicity, and Canonicalization

This addendum formalizes the architectural decisions made following the rigorous empirical testing detailed in `architectural_validation_report.md` and `AGEI-BENCH-012-revision2`.

### 1. The Canonicalization Storage Claim is Dropped
**Decision:** We explicitly abandon the claim that RFC 8785 canonicalization (whitespace-stripping) provides meaningful cold storage savings.
**Rationale:** Empirical testing (`test_corpus_compression.py`) proved that while uncompressed JSON shrinks by ~5-8%, the standard `gzip` DEFLATE algorithm natively eliminates whitespace redundancy. The post-gzip savings of canonicalization is <3%, which falls below the significance threshold to justify architectural complexity.
**New Posture:** Canonicalization is retained strictly as a cryptographic constraint for non-repudiation and hash stability, not as a storage optimization tactic.

### 2. The S3-First Dual-Write Atomicity Pattern is Mandatory
**Decision:** The system must strictly enforce an "S3-First" write order (Cold Storage write completes before Hot Database insert is attempted).
**Rationale:** Database inserts can fail independently of S3 writes. Testing (`test_storage_completeness.py`) proved that if S3 writes happen first, a DB failure results in an "orphaned blob" in cold storage, but the raw evidence is durably preserved. The reverse (DB first) risks an "orphaned receipt," which is a fatal compliance flaw (a receipt claiming evidence exists that does not). We accept orphaned blobs as the necessary cost of ensuring 100% evidentiary completeness.

### 3. Orphan Cleanup Requires a 60-Minute Grace Period
**Decision:** The reconciliation script designed to delete orphaned S3 blobs must include a mandatory 60-minute Grace Period based on `LastModified` time.
**Rationale:** Without a grace period, the cleanup job will race against valid in-flight database inserts. Deleting a blob whose corresponding receipt is merely delayed by network/queue latency actively destroys valid evidence.
**Residual Risk Acceptance:** We formally acknowledge that if PostgreSQL commit latency (or message queue backups) exceeds 60 minutes, the cleanup job may incorrectly sweep a valid in-flight blob. This risk is bounded by the 60-minute configuration and must be managed via queue-depth monitoring.

### 4. Deterministic Idempotency and Content-Addressing
**Decision:** The client must enforce strict payload determinism, utilizing a stable `idempotency_key` and rejecting request-time timestamps.
**Rationale:** If retries generate new timestamps, the hash changes, resulting in duplicate blobs (storage bloat). By embracing determinism and content-addressing (`content_hash` as the S3 key), S3 natively overwrites retried payloads. We explicitly accept many-to-one deduplication (multiple receipts pointing to a single S3 blob if the payloads are semantically identical).
