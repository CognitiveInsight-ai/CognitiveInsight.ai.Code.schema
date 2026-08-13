-- Family 1: Tenant, Identity, and API Access
-- Establishes tenant isolation, principals, API keys, and request telemetry.

CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,
    settings JSONB DEFAULT '{}'::jsonb,
    status VARCHAR(50) DEFAULT 'active',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE public.principals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    principal_type VARCHAR(50) NOT NULL,
    external_id VARCHAR(255),
    email VARCHAR(255),
    display_name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    last_login_at TIMESTAMPTZ,
    auth_provider VARCHAR(100),
    mfa_enabled BOOLEAN DEFAULT false,
    security_stamp VARCHAR(255)
);

CREATE TABLE public.organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.principals(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    invited_by UUID,
    invited_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ,
    permissions JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    UNIQUE(organization_id, user_id)
);

CREATE TABLE public.api_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    principal_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    client_key VARCHAR(255) NOT NULL UNIQUE,
    status VARCHAR(50) DEFAULT 'active',
    client_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    allowed_ips JSONB DEFAULT '[]'::jsonb,
    rate_limit INTEGER,
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    creator_id UUID,
    environment VARCHAR(50) DEFAULT 'production',
    client_type VARCHAR(50)
);

CREATE TABLE public.api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    api_client_id UUID NOT NULL REFERENCES public.api_clients(id) ON DELETE CASCADE,
    key_prefix VARCHAR(32) NOT NULL,
    hashed_secret VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    revoked_by UUID,
    revocation_reason TEXT,
    allowed_domains JSONB DEFAULT '[]'::jsonb,
    allowed_ips JSONB DEFAULT '[]'::jsonb,
    creator_id UUID,
    rotation_id UUID,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    scopes JSONB DEFAULT '[]'::jsonb,
    environment VARCHAR(50) DEFAULT 'production'
);

CREATE TABLE public.ciaf_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_key VARCHAR(100) NOT NULL UNIQUE,
    service_name VARCHAR(255) NOT NULL,
    service_family VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    status VARCHAR(50) DEFAULT 'active',
    version VARCHAR(50),
    endpoint_url VARCHAR(255),
    auth_type VARCHAR(50),
    sla_tier VARCHAR(50),
    owner_team VARCHAR(100),
    documentation_url VARCHAR(255),
    risk_level VARCHAR(50)
);

CREATE TABLE public.api_key_service_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    api_key_id UUID NOT NULL REFERENCES public.api_keys(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES public.ciaf_services(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT true,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    granted_by UUID,
    expires_at TIMESTAMPTZ,
    quota_limit INTEGER,
    quota_used INTEGER DEFAULT 0,
    permissions JSONB DEFAULT '[]'::jsonb,
    environment VARCHAR(50) DEFAULT 'production',
    notes TEXT,
    UNIQUE(api_key_id, service_id)
);

CREATE TABLE public.organization_service_entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES public.ciaf_services(id) ON DELETE CASCADE,
    policy_version_id UUID, -- Will reference policy_versions once created
    quota_limit INTEGER,
    is_active BOOLEAN DEFAULT true,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    quota_used INTEGER DEFAULT 0,
    quota_reset_period VARCHAR(50),
    next_reset_at TIMESTAMPTZ,
    tier VARCHAR(50),
    granted_by UUID,
    notes TEXT,
    UNIQUE(organization_id, service_id)
);

CREATE TABLE public.api_request_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    api_key_id UUID REFERENCES public.api_keys(id) ON DELETE SET NULL,
    service_id UUID REFERENCES public.ciaf_services(id) ON DELETE SET NULL,
    gate_evaluation_id UUID, -- Will reference gate_evaluations
    receipt_id UUID, -- Will reference receipts
    evidence_object_id UUID, -- Will reference evidence_objects
    vault_object_id UUID, -- Will reference vault_objects
    audit_pack_id UUID, -- Will reference audit_packs
    request_id VARCHAR(255) NOT NULL,
    method VARCHAR(10),
    endpoint VARCHAR(500),
    status_code INTEGER,
    duration_ms INTEGER,
    client_ip VARCHAR(45),
    user_agent TEXT,
    request_payload_hash VARCHAR(64),
    response_payload_hash VARCHAR(64),
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    error_message TEXT,
    error_code VARCHAR(50),
    correlation_id VARCHAR(255),
    actor_id UUID,
    environment VARCHAR(50),
    request_size INTEGER,
    response_size INTEGER,
    is_idempotent BOOLEAN,
    idempotency_key VARCHAR(255)
);

CREATE TABLE public.api_usage_daily (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES public.ciaf_services(id) ON DELETE CASCADE,
    api_key_id UUID REFERENCES public.api_keys(id) ON DELETE CASCADE,
    usage_count INTEGER DEFAULT 0 NOT NULL,
    date_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    error_count INTEGER DEFAULT 0,
    total_duration_ms BIGINT DEFAULT 0,
    avg_duration_ms INTEGER DEFAULT 0,
    bytes_in BIGINT DEFAULT 0,
    bytes_out BIGINT DEFAULT 0,
    p95_duration_ms INTEGER,
    p99_duration_ms INTEGER,
    max_duration_ms INTEGER,
    min_duration_ms INTEGER,
    environment VARCHAR(50),
    UNIQUE(organization_id, service_id, api_key_id, date_date)
);

CREATE TABLE public.service_output_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    request_log_id UUID NOT NULL REFERENCES public.api_request_logs(id) ON DELETE CASCADE,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256' NOT NULL,
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1' NOT NULL,
    output_hash VARCHAR(64) NOT NULL,
    output_type VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    target_entity_type VARCHAR(100),
    target_entity_id UUID,
    signature BYTEA
);

CREATE TABLE public.webhook_endpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    target_url VARCHAR(1000) NOT NULL,
    secret_hash VARCHAR(255),
    is_active BOOLEAN DEFAULT true NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    events JSONB DEFAULT '[]'::jsonb
);

CREATE TABLE public.webhook_delivery_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    webhook_endpoint_id UUID NOT NULL REFERENCES public.webhook_endpoints(id) ON DELETE CASCADE,
    receipt_id UUID, -- Will reference receipts
    payload_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    status VARCHAR(50) NOT NULL,
    status_code INTEGER,
    response_body TEXT,
    duration_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    attempt_number INTEGER DEFAULT 1,
    next_retry_at TIMESTAMPTZ,
    event_type VARCHAR(100),
    signature VARCHAR(255),
    error_message TEXT,
    correlation_id VARCHAR(255)
);

-- Indexes for performance
CREATE INDEX idx_principals_external_id ON public.principals(external_id);
CREATE INDEX idx_api_clients_org ON public.api_clients(organization_id);
CREATE INDEX idx_api_keys_org ON public.api_keys(organization_id);
CREATE INDEX idx_api_request_logs_org ON public.api_request_logs(organization_id);
CREATE INDEX idx_api_usage_daily_org_date ON public.api_usage_daily(organization_id, date_date);
