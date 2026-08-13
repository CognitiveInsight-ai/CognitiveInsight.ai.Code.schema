-- Family 2: Policy and Gate Enforcement
-- Translates human policies into versioned, machine-evaluable database objects.

CREATE TABLE public.policy_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    current_version_id UUID, -- Will be self-referencing to policy_versions
    name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    owner_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    policy_family VARCHAR(100),
    tags JSONB DEFAULT '[]'::jsonb
);

CREATE TABLE public.policy_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    policy_set_id UUID NOT NULL REFERENCES public.policy_sets(id) ON DELETE CASCADE,
    payload_hash VARCHAR(64) NOT NULL,
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1' NOT NULL,
    version_number VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    published_at TIMESTAMPTZ,
    deprecated_at TIMESTAMPTZ,
    author_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    approver_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    raw_payload JSONB NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    signature BYTEA,
    signature_algorithm VARCHAR(32) DEFAULT 'Ed25519',
    changelog TEXT
);

-- Update the self-reference on policy_sets
ALTER TABLE public.policy_sets ADD CONSTRAINT fk_policy_sets_current_version FOREIGN KEY (current_version_id) REFERENCES public.policy_versions(id) ON DELETE SET NULL;

CREATE TABLE public.policy_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    policy_version_id UUID NOT NULL REFERENCES public.policy_versions(id) ON DELETE CASCADE,
    rule_key VARCHAR(100) NOT NULL,
    severity VARCHAR(50) DEFAULT 'medium',
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rule_type VARCHAR(50) NOT NULL,
    parameters JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    remediation_action TEXT,
    tags JSONB DEFAULT '[]'::jsonb,
    condition_logic TEXT
);

CREATE TABLE public.policy_evaluations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    policy_version_id UUID NOT NULL REFERENCES public.policy_versions(id) ON DELETE CASCADE,
    gate_evaluation_id UUID, -- Will reference gate_evaluations
    evaluation_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    rule_key VARCHAR(100) NOT NULL,
    outcome VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    evaluated_by UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    context_data JSONB DEFAULT '{}'::jsonb,
    duration_ms INTEGER,
    error_message TEXT,
    signature BYTEA,
    signature_algorithm VARCHAR(32) DEFAULT 'Ed25519',
    evidence_object_id UUID -- Will reference evidence_objects
);

CREATE TABLE public.gate_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    policy_version_id UUID NOT NULL REFERENCES public.policy_versions(id) ON DELETE CASCADE,
    gate_type VARCHAR(100) NOT NULL,
    failure_action VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    required_rules JSONB DEFAULT '[]'::jsonb,
    override_allowed BOOLEAN DEFAULT false,
    override_roles JSONB DEFAULT '[]'::jsonb,
    timeout_ms INTEGER,
    escalation_path JSONB DEFAULT '[]'::jsonb,
    tags JSONB DEFAULT '[]'::jsonb,
    owner_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    version VARCHAR(50),
    status VARCHAR(50) DEFAULT 'active'
);

CREATE TABLE public.gate_evaluations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    policy_version_id UUID NOT NULL REFERENCES public.policy_versions(id) ON DELETE CASCADE,
    gate_definition_id UUID NOT NULL REFERENCES public.gate_definitions(id) ON DELETE CASCADE,
    gate_outcome VARCHAR(50) NOT NULL,
    is_overridden BOOLEAN DEFAULT false,
    evaluation_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    actor_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    override_reason TEXT,
    overridden_by UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    context_data JSONB DEFAULT '{}'::jsonb,
    duration_ms INTEGER,
    error_message TEXT,
    signature BYTEA,
    signature_algorithm VARCHAR(32) DEFAULT 'Ed25519',
    receipt_id UUID, -- Will reference receipts
    evidence_object_id UUID, -- Will reference evidence_objects
    request_log_id UUID REFERENCES public.api_request_logs(id) ON DELETE SET NULL,
    escalated_to UUID,
    escalation_status VARCHAR(50),
    resolved_at TIMESTAMPTZ,
    environment VARCHAR(50),
    correlation_id VARCHAR(255),
    client_ip VARCHAR(45)
);

-- Add foreign key constraint to policy_evaluations now that gate_evaluations is created
ALTER TABLE public.policy_evaluations ADD CONSTRAINT fk_policy_eval_gate FOREIGN KEY (gate_evaluation_id) REFERENCES public.gate_evaluations(id) ON DELETE CASCADE;

CREATE INDEX idx_policy_versions_set ON public.policy_versions(policy_set_id);
CREATE INDEX idx_gate_evaluations_org ON public.gate_evaluations(organization_id);
CREATE INDEX idx_gate_evaluations_outcome ON public.gate_evaluations(gate_outcome);
