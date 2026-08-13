-- Family 6: Downstream Provenance and Watermarking
-- Handles downstream tracing, release registrations, and forensic fingerprints.

CREATE TABLE public.artifact_release_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    policy_version_id UUID REFERENCES public.policy_versions(id) ON DELETE SET NULL,
    gate_evaluation_id UUID REFERENCES public.gate_evaluations(id) ON DELETE SET NULL,
    pre_watermark_hash VARCHAR(64) NOT NULL,
    post_watermark_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    status VARCHAR(50) DEFAULT 'released',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    artifact_type VARCHAR(100) NOT NULL,
    destination_url VARCHAR(1000),
    released_by UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    release_channel VARCHAR(100),
    signature BYTEA,
    signature_algorithm VARCHAR(32),
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    evidence_object_id UUID REFERENCES public.evidence_objects(id) ON DELETE SET NULL,
    vault_object_id UUID REFERENCES public.vault_objects(id) ON DELETE SET NULL,
    version VARCHAR(50),
    notes TEXT,
    is_revoked BOOLEAN DEFAULT false
);

CREATE TABLE public.watermark_descriptors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    evidence_object_id UUID REFERENCES public.evidence_objects(id) ON DELETE SET NULL,
    content_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    watermark_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    algorithm_name VARCHAR(100),
    parameters JSONB,
    payload_schema VARCHAR(100),
    applied_by UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    release_record_id UUID REFERENCES public.artifact_release_records(id) ON DELETE SET NULL,
    is_visible BOOLEAN DEFAULT false,
    verification_key_id VARCHAR(255)
);

CREATE TABLE public.forensic_fingerprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    evidence_object_id UUID REFERENCES public.evidence_objects(id) ON DELETE SET NULL,
    fingerprint_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    fingerprint_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    release_record_id UUID REFERENCES public.artifact_release_records(id) ON DELETE CASCADE,
    shingle_size INTEGER,
    anchor_points JSONB DEFAULT '[]'::jsonb,
    model_version VARCHAR(50),
    generator_id UUID,
    confidence_threshold NUMERIC(5, 4),
    features JSONB,
    is_active BOOLEAN DEFAULT true,
    created_by UUID,
    notes TEXT
);

CREATE TABLE public.provenance_verification_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    evidence_object_id UUID REFERENCES public.evidence_objects(id) ON DELETE SET NULL,
    matched_release_record_id UUID REFERENCES public.artifact_release_records(id) ON DELETE SET NULL,
    confidence_score NUMERIC(5, 4) NOT NULL,
    status VARCHAR(50) DEFAULT 'completed',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    investigator_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    verification_method VARCHAR(100),
    matched_fingerprints JSONB DEFAULT '[]'::jsonb,
    watermark_payload JSONB,
    findings TEXT,
    is_confirmed BOOLEAN,
    report_url VARCHAR(1000),
    correlation_id VARCHAR(255),
    signature BYTEA,
    signature_algorithm VARCHAR(32)
);

CREATE INDEX idx_artifact_releases_org ON public.artifact_release_records(organization_id);
CREATE INDEX idx_watermarks_org ON public.watermark_descriptors(organization_id);
CREATE INDEX idx_forensic_org ON public.forensic_fingerprints(organization_id);
