-- Family 3: Receipts, Evidence, Vault, Verification, and Audit Packs
-- The core cryptographic custody layer.

CREATE TABLE public.receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    policy_version_id UUID REFERENCES public.policy_versions(id) ON DELETE SET NULL,
    gate_evaluation_id UUID REFERENCES public.gate_evaluations(id) ON DELETE SET NULL,
    content_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    signature BYTEA NOT NULL,
    signature_algorithm VARCHAR(32) DEFAULT 'Ed25519',
    receipt_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'issued',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    actor_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    evidence_object_id UUID, -- Will reference evidence_objects
    vault_object_id UUID, -- Will reference vault_objects
    event_timestamp TIMESTAMPTZ NOT NULL,
    correlation_id VARCHAR(255),
    source_system VARCHAR(100),
    subject_id UUID,
    subject_type VARCHAR(100),
    expiration_date TIMESTAMPTZ,
    is_revoked BOOLEAN DEFAULT false,
    revocation_reason TEXT,
    revoked_at TIMESTAMPTZ,
    revoked_by UUID,
    payload JSONB NOT NULL
);

CREATE TABLE public.receipt_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    source_receipt_id UUID NOT NULL REFERENCES public.receipts(id) ON DELETE CASCADE,
    target_receipt_id UUID NOT NULL REFERENCES public.receipts(id) ON DELETE CASCADE,
    link_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_by UUID,
    notes TEXT,
    UNIQUE(source_receipt_id, target_receipt_id, link_type)
);

CREATE TABLE public.receipt_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    merkle_root VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    total_receipts INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'sealed',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    sealed_at TIMESTAMPTZ NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    signature BYTEA,
    signature_algorithm VARCHAR(32) DEFAULT 'Ed25519',
    batch_period_start TIMESTAMPTZ,
    batch_period_end TIMESTAMPTZ
);

CREATE TABLE public.receipt_batch_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    receipt_batch_id UUID NOT NULL REFERENCES public.receipt_batches(id) ON DELETE CASCADE,
    receipt_id UUID NOT NULL REFERENCES public.receipts(id) ON DELETE CASCADE,
    merkle_proof JSONB NOT NULL,
    leaf_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    UNIQUE(receipt_batch_id, receipt_id)
);

CREATE TABLE public.evidence_objects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    content_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    object_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    storage_path VARCHAR(1000),
    storage_provider VARCHAR(50),
    size_bytes BIGINT,
    mime_type VARCHAR(100),
    encryption_status VARCHAR(50),
    kms_key_id VARCHAR(255),
    retention_date TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT false,
    deleted_at TIMESTAMPTZ,
    owner_id UUID,
    classification_level VARCHAR(50),
    payload JSONB
);

CREATE TABLE public.vault_objects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    evidence_object_id UUID REFERENCES public.evidence_objects(id) ON DELETE SET NULL,
    content_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    signature BYTEA NOT NULL,
    signature_algorithm VARCHAR(32) DEFAULT 'Ed25519',
    status VARCHAR(50) DEFAULT 'sealed',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    sealed_by UUID,
    retention_period VARCHAR(50),
    expires_at TIMESTAMPTZ,
    legal_hold BOOLEAN DEFAULT false,
    storage_tier VARCHAR(50),
    archive_id VARCHAR(255),
    custody_chain JSONB DEFAULT '[]'::jsonb
);

CREATE TABLE public.verification_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    status VARCHAR(50) DEFAULT 'pending',
    checked_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    completed_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    job_type VARCHAR(50) NOT NULL,
    target_batch_id UUID REFERENCES public.receipt_batches(id) ON DELETE SET NULL,
    target_receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    target_vault_id UUID REFERENCES public.vault_objects(id) ON DELETE SET NULL,
    initiated_by UUID,
    report_url VARCHAR(1000),
    error_log TEXT,
    signature BYTEA,
    signature_algorithm VARCHAR(32),
    verification_hash VARCHAR(64),
    hash_algorithm VARCHAR(16),
    environment VARCHAR(50),
    parameters JSONB,
    findings JSONB DEFAULT '[]'::jsonb,
    is_compliant BOOLEAN,
    reviewer_id UUID,
    reviewed_at TIMESTAMPTZ
);

CREATE TABLE public.schema_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schema_key VARCHAR(100) NOT NULL,
    semantic_version VARCHAR(50) NOT NULL,
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    description TEXT,
    json_schema JSONB NOT NULL,
    author VARCHAR(100),
    status VARCHAR(50) DEFAULT 'published',
    UNIQUE(schema_key, semantic_version)
);

CREATE TABLE public.audit_packs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    pack_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    status VARCHAR(50) DEFAULT 'building',
    export_url VARCHAR(1000),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    sealed_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_by UUID,
    sealed_by UUID,
    signature BYTEA,
    signature_algorithm VARCHAR(32) DEFAULT 'Ed25519',
    period_start TIMESTAMPTZ,
    period_end TIMESTAMPTZ,
    total_items INTEGER DEFAULT 0,
    size_bytes BIGINT,
    compliance_framework VARCHAR(100),
    auditor_name VARCHAR(255),
    auditor_reference VARCHAR(255),
    expires_at TIMESTAMPTZ,
    is_downloaded BOOLEAN DEFAULT false,
    last_downloaded_at TIMESTAMPTZ,
    download_count INTEGER DEFAULT 0
);

CREATE TABLE public.audit_pack_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    audit_pack_id UUID NOT NULL REFERENCES public.audit_packs(id) ON DELETE CASCADE,
    item_snapshot_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    item_type VARCHAR(50) NOT NULL,
    source_receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    source_evidence_id UUID REFERENCES public.evidence_objects(id) ON DELETE SET NULL,
    source_vault_id UUID REFERENCES public.vault_objects(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    snapshot_payload JSONB,
    sequence_number INTEGER,
    inclusion_proof JSONB
);

CREATE TABLE public.incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    gate_evaluation_id UUID REFERENCES public.gate_evaluations(id) ON DELETE SET NULL,
    audit_pack_id UUID REFERENCES public.audit_packs(id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'open',
    severity VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    resolved_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    reported_by UUID,
    assigned_to UUID,
    incident_type VARCHAR(100),
    root_cause TEXT,
    remediation_plan TEXT,
    is_regulatory_reportable BOOLEAN DEFAULT false,
    regulatory_deadline TIMESTAMPTZ,
    reported_to_regulator BOOLEAN DEFAULT false,
    report_date TIMESTAMPTZ,
    related_receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    related_policy_version_id UUID REFERENCES public.policy_versions(id) ON DELETE SET NULL,
    closure_reason TEXT,
    post_mortem_url VARCHAR(1000),
    tags JSONB DEFAULT '[]'::jsonb
);

CREATE INDEX idx_receipts_org ON public.receipts(organization_id);
CREATE INDEX idx_receipts_gate ON public.receipts(gate_evaluation_id);
CREATE INDEX idx_evidence_objects_org ON public.evidence_objects(organization_id);
CREATE INDEX idx_vault_objects_org ON public.vault_objects(organization_id);
CREATE INDEX idx_incidents_org ON public.incidents(organization_id);
