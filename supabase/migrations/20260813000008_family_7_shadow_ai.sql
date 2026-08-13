-- Family 7: Shadow AI Governance
-- Discovers and manages unapproved AI usage and risk classifications.

CREATE TABLE public.shadow_ai_tool_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    tool_key VARCHAR(100) NOT NULL,
    tool_posture VARCHAR(50) NOT NULL,
    risk_level VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    vendor VARCHAR(255),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT true,
    website_url VARCHAR(1000),
    privacy_policy_url VARCHAR(1000),
    data_retention_policy VARCHAR(255),
    compliance_certifications JSONB DEFAULT '[]'::jsonb,
    reviewed_by UUID REFERENCES public.principals(id) ON DELETE SET NULL
);

CREATE TABLE public.shadow_ai_discovery_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    evidence_object_id UUID REFERENCES public.evidence_objects(id) ON DELETE SET NULL,
    signal_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    status VARCHAR(50) DEFAULT 'detected',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    tool_registry_id UUID REFERENCES public.shadow_ai_tool_registry(id) ON DELETE SET NULL,
    user_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    ip_address VARCHAR(45),
    device_id VARCHAR(255),
    source_system VARCHAR(100),
    event_count INTEGER DEFAULT 1,
    first_seen_at TIMESTAMPTZ NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL,
    payload_size_bytes BIGINT,
    risk_score NUMERIC(5, 2),
    is_blocked BOOLEAN DEFAULT false,
    raw_signal_data JSONB
);

CREATE TABLE public.shadow_ai_classifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    policy_version_id UUID REFERENCES public.policy_versions(id) ON DELETE SET NULL,
    gate_evaluation_id UUID REFERENCES public.gate_evaluations(id) ON DELETE SET NULL,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    discovery_record_id UUID NOT NULL REFERENCES public.shadow_ai_discovery_records(id) ON DELETE CASCADE,
    classification_result VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    classified_by UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    confidence_score NUMERIC(5, 4),
    reasoning TEXT,
    automated BOOLEAN DEFAULT true
);

CREATE TABLE public.shadow_ai_governance_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    response_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    discovery_record_id UUID REFERENCES public.shadow_ai_discovery_records(id) ON DELETE CASCADE,
    tool_registry_id UUID REFERENCES public.shadow_ai_tool_registry(id) ON DELETE CASCADE,
    assigned_to UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    action_taken TEXT,
    completed_at TIMESTAMPTZ,
    effectiveness_score NUMERIC(5, 2),
    notes TEXT
);

CREATE INDEX idx_shadow_registry_org ON public.shadow_ai_tool_registry(organization_id);
CREATE INDEX idx_shadow_discovery_org ON public.shadow_ai_discovery_records(organization_id);
