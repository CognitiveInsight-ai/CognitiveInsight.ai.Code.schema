# Cognitive Insight AI: AI Governance Evidence Infrastructure (AGEI)

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![PostgreSQL](https://img.shields.io/badge/Supabase-PostgreSQL-blue.svg)](https://supabase.com/)

**CognitiveInsight.ai** is the definitive open-source standard for AI accountability. This repository contains the concrete schema implementations of the **AI Governance Evidence Infrastructure (AGEI)**.

While existing tools focus on observability, MLOps, or static documentation (like model cards), AGEI is a new category: an architectural layer designed to **capture, seal, link, store, and retrieve verifiable governance evidence** across the entire AI lifecycle. It provides cryptographically verifiable proof of *what happened, why it happened, under what authority it happened, and whether governance controls were enforced.* 

**Our motto is "Proof, Not Logs."**

## 🏗️ The 6 Core AGEI Architecture Components

Based on the foundational paper *AI Governance Evidence Infrastructure: A Category Framework for Cryptographically Verifiable AI Lifecycle Accountability*, this repository implements the six core functional components of AGEI:

1. **CIAF-LCM (Lifecycle Evidence Model)**: Represents AI events as structured receipts across data, training, validation, deployment, and runtime. *Lazy Capsule Materialization (LCM)* ensures lightweight footprints are captured continuously, while heavy evidence capsules are materialized only when triggered by gates or audits.
2. **Governance Gates**: Explicit control points placed at consequential transitions (e.g., provenance gates before training, approval gates before deployment, pre-action gates before an agent executes a sensitive tool call).
3. **Tamper-Evident Evidence Vault**: The durable custody layer where evidence objects are canonicalized, hashed, signed, linked, and stored for later offline verification.
4. **Agent Governance Planes**: A 5-plane model governing autonomous agents: Identity, Policy, Privilege, Execution, and Evidence.
5. **Shadow AI Capture**: Extends the evidence perimeter to monitor and record unmanaged or unsanctioned AI SaaS usage.
6. **Downstream Provenance**: Mechanisms for tracing distributed artifacts, including watermarking, forensic fingerprinting, and dual-layer hashing.

---

## 🗄️ Supabase Schema Implementation

This repository materializes the AGEI framework into a production-grade relational database contract using **Supabase (PostgreSQL)**. 

The schema is divided into distinct "Families" that map directly to the 6 core components, located in `supabase/migrations/`:

- `...01_family_9_extension_vocabulary.sql`: Core vocabulary and extensions.
- `...02_family_1_tenant_identity.sql`: Multi-tenant identities, principals, and service accounts.
- `...03_family_2_policy_gate_enforcement.sql`: Implementation of **Governance Gates**, thresholds, and human-in-the-loop overrides.
- `...04_family_3_receipts_evidence_vault.sql`: The **Tamper-Evident Evidence Vault** for storing signed micro-receipts and canonicalized audit packs.
- `...05_family_4_lifecycle_objects.sql`: The **CIAF-LCM** tables mapping datasets, models, and environments.
- `...06_family_5_agentic_governance.sql`: The **Agent Governance Planes**, tracking tool delegations and autonomous actions.
- `...07_family_6_downstream_provenance.sql`: Tables for tracking **Downstream Provenance** and watermarked artifacts.
- `...08_family_7_shadow_ai.sql`: Schemas for **Shadow AI Capture** and SaaS discovery.
- `...09_family_8_privacy_data.sql`: Privacy overlays and cryptographic redaction (Right-to-be-Forgotten without breaking signatures).
- `...10_rls_and_triggers.sql`: Enforces **Write-Once-Read-Many (WORM)** compliance at the database engine level and binds Row-Level Security (RLS) to tenant boundaries.

---

## 🚀 Getting Started

This repository leverages Supabase for local development and schema management.

### Prerequisites
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- Docker Desktop (for local Supabase stack)

### Initialization

1. **Start the local Supabase instance:**
   ```bash
   supabase start
   ```
   *This will automatically apply all migrations in the `supabase/migrations/` directory, setting up the complete AGEI architecture locally.*

2. **Verify the Schema:**
   Navigate to the local Supabase Studio URL provided in your terminal to inspect the deployed tables, RLS policies, and WORM triggers.

## 🤝 How to Get Involved

This site is a living repository. We want to collaborate on building a verifiable future for AI.

## 📄 License

This project is licensed under the **Apache License 2.0**. See the [LICENSE](LICENSE) file for details. Contributions made to this repository must be licensed under the same Apache 2.0 terms.


