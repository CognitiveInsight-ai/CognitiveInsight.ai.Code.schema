# CIAF-LCM Implementation & Validation Master Report

**Date:** August 23, 2026
**Subject:** Master consolidation of the Cognitive Insight Audit Framework - Lazy Capsule Materialization (CIAF-LCM) architecture and empirical test results.

---

## 1. Executive Summary

The CIAF-LCM architecture is designed to decouple execution data from database storage. Instead of synchronously writing full JSON payloads into a structured relational database (Supabase/PostgreSQL), the system is configured to write the raw bytes to cold storage (S3) and record a cryptographic receipt in the active database. Full evidence payloads are moved into the database only when materialized.

This document bridges the theoretical process models with the concrete Supabase SQL and Python implementations, summarizing the engineering configurations and the results of the empirical tests.

---

## 2. The Implementation Model (Supabase & Python)

The architecture is implemented across a dual-layer system:

### A. The Python Application Layer (The Orchestrator)
Python serves as the execution plane, configured to:
1. Generate event payloads using a static `idempotency_key`.
2. Hash the payload to generate a `content_hash`.
3. Execute the S3-First write sequence (writing the payload to cold storage before inserting the database receipt).
4. Run the background Orphan Cleanup job.

### B. The Supabase Database Layer (The Ledger)
Supabase (PostgreSQL 16) is split into two primary tables:
1. **The Hot Pool (`receipts`):** A table storing the `content_hash`, `tenant_id`, and metadata.
2. **The Materialized Pool (`evidence_objects`):** A table configured to store the raw payload.

---

## 3. Engineering Configurations

Empirical testing was conducted on the following configurations:

> [!CAUTION]
> **Configuration 1: "S3-First" Write Order**
> The system is configured to write raw bytes to S3 before inserting the receipt into PostgreSQL. If the database insert fails, an "orphaned blob" remains in S3. If the database were written to first and S3 failed, the database would record a receipt for an object that does not exist in storage.

> [!IMPORTANT]
> **Configuration 2: Idempotency Keys**
> Event payloads are configured to use a static `idempotency_key` and exclude request-time variables. This configuration aims to produce identical byte strings and `content_hash` values on retried requests, overwriting the same S3 key.

> [!WARNING]
> **Configuration 3: 60-Minute Grace Period**
> The Orphan Cleanup background job evaluates blobs based on `LastModified` time. A 60-minute interval is set before deleting S3 blobs that lack a corresponding database receipt, intended to avoid deleting in-flight database inserts.

> [!NOTE]
> **Configuration 4: Application-Layer Hashing**
> PostgreSQL `jsonb` alters lexical structure upon extraction. Hashes are generated at the application layer prior to database insertion.

---

## 4. Empirical Test Results

The following sections detail the tests executed on the architecture and the observed factual outcomes.

### Test 1: Relational Storage Footprint
* **Script:** `evaluate_lcm_storage_rigorous.sql` and `AGEI-BENCH-012-revision2`
* **Methodology:** Measured the storage consumption of the `receipts` table versus the `evidence_objects` table using PostgreSQL relation sizing functions.
* **Results:** The live-measured test (`AGEI-BENCH-012-revision2`) observed a **96.67%** reduction in relational database footprint when operating at a 5% materialization rate compared to storing 100% of payloads in the database.

### Test 2: Compression Analysis
* **Script:** `test_corpus_compression.py`
* **Methodology:** Generated a synthetic corpus of 500 AI event payloads. Measured the uncompressed and `gzip` compressed sizes of standard Indent=2 JSON versus RFC 8785 Canonicalized JSON.
* **Results:** Canonicalized JSON was 4.95% smaller than Indent=2 JSON before compression. After `gzip` compression, the canonicalized data was 2.03% smaller than the compressed Indent=2 data.

### Test 3: Write Atomicity and Completeness
* **Script:** `test_storage_completeness.py`
* **Methodology:** Processed 50 payloads using an "S3-First" write order. Injected a simulated database insertion failure on 5 events immediately after the S3 write completed.
* **Results:** The test resulted in 45 database receipts and 50 S3 blobs. All 45 database receipts mapped to verifiable payloads in cold storage. 5 S3 blobs existed without corresponding database receipts. 0 database receipts existed without corresponding S3 blobs.

### Test 4: Retry Behavior
* **Script:** `test_retry_idempotency.py`
* **Methodology:** Generated a payload with a static `idempotency_key` and no request-time variables. Simulated an S3 write, followed by a database failure. Simulated a retry of the same event, followed by a successful database insert.
* **Results:** Attempt 1 and Attempt 2 produced byte-identical payloads and identical S3 keys. The final state of the S3 bucket contained exactly 1 version of the object.

### Test 5: Orphan Cleanup Race Condition
* **Script:** `test_orphan_cleanup.py`
* **Methodology:** Uploaded 5 test blobs into S3 to test cleanup boundaries against a 60-minute limit.
* **Results:** The cleanup script deleted blobs older than 60 minutes lacking a database receipt (Cases 1 and 5). It retained blobs younger than 60 minutes lacking a receipt (Cases 2 and 4), and retained blobs older than 60 minutes that possessed a receipt (Case 3).

---

## 5. Scope Boundaries & Open Items

This report documents the tests executed on the storage and atomicity configurations. It **does not** test or establish:
1. Performance benchmarks for LCM extraction speed.
2. Real-world network latency impacts of S3 synchronous writes.
3. Compliance or audit certifications.
4. **Migration Defects:** See `AGEI-BENCH-012-revision2` §6.1 for documented schema migration defects.
5. **ZeroTrust Vault:** See `docs/known_open_items.md` for ongoing investigations into threshold miscalibrations in the ZeroTrust Vault benchmark (managed in a separate repository).
