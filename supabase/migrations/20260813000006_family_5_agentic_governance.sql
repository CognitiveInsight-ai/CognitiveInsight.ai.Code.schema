-- Family 5: Agentic Governance and Pre-Action Proof
-- Governs autonomous agents at runtime.

CREATE TABLE public.agent_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    policy_version_id UUID REFERENCES public.policy_versions(id) ON DELETE SET NULL,
    context_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    status VARCHAR(50) DEFAULT 'active',
    session_name VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    ended_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    principal_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    agent_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    session_parameters JSONB DEFAULT '{}'::jsonb,
    termination_reason TEXT,
    max_steps INTEGER
);

CREATE TABLE public.agent_delegations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    delegating_principal_id UUID NOT NULL REFERENCES public.principals(id) ON DELETE CASCADE,
    agent_principal_id UUID NOT NULL REFERENCES public.principals(id) ON DELETE CASCADE,
    delegation_token_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    scopes JSONB DEFAULT '[]'::jsonb,
    max_budget NUMERIC(10, 2),
    is_revoked BOOLEAN DEFAULT false,
    revoked_at TIMESTAMPTZ
);

CREATE TABLE public.agent_tool_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    tool_key VARCHAR(100) NOT NULL,
    risk_class VARCHAR(50) NOT NULL,
    required_gate_definition_id UUID REFERENCES public.gate_definitions(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    parameters_schema JSONB NOT NULL,
    endpoint_url VARCHAR(1000),
    owner_team VARCHAR(100),
    version VARCHAR(50)
);

CREATE TABLE public.pre_action_proof_bundles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    gate_evaluation_id UUID REFERENCES public.gate_evaluations(id) ON DELETE SET NULL,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    delegation_id UUID REFERENCES public.agent_delegations(id) ON DELETE SET NULL,
    proof_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    status VARCHAR(50) DEFAULT 'valid',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    tool_definition_id UUID REFERENCES public.agent_tool_definitions(id) ON DELETE SET NULL,
    proposed_parameters JSONB,
    signature BYTEA,
    signature_algorithm VARCHAR(32),
    session_id UUID REFERENCES public.agent_sessions(id) ON DELETE SET NULL,
    is_consumed BOOLEAN DEFAULT false
);

CREATE TABLE public.agent_tool_invocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    pre_action_proof_id UUID REFERENCES public.pre_action_proof_bundles(id) ON DELETE SET NULL,
    evidence_object_id UUID REFERENCES public.evidence_objects(id) ON DELETE SET NULL,
    gate_outcome VARCHAR(50) NOT NULL,
    tool_definition_id UUID REFERENCES public.agent_tool_definitions(id) ON DELETE SET NULL,
    session_id UUID REFERENCES public.agent_sessions(id) ON DELETE SET NULL,
    invocation_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    status VARCHAR(50) DEFAULT 'completed',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    completed_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    parameters JSONB,
    result_payload JSONB,
    duration_ms INTEGER,
    error_message TEXT,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    correlation_id VARCHAR(255),
    actor_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    environment VARCHAR(50)
);

CREATE INDEX idx_agent_sessions_org ON public.agent_sessions(organization_id);
CREATE INDEX idx_agent_invocations_org ON public.agent_tool_invocations(organization_id);
