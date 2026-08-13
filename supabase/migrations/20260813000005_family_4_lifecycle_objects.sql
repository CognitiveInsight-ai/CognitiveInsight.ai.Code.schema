-- Family 4: Lifecycle Object Registry and Lineage
-- Provides a registry of governed assets (datasets, weights, configs) and tracks lineage.

CREATE TABLE public.ai_lifecycle_objects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    receipt_id UUID REFERENCES public.receipts(id) ON DELETE SET NULL,
    evidence_object_id UUID REFERENCES public.evidence_objects(id) ON DELETE SET NULL,
    content_hash VARCHAR(64) NOT NULL,
    hash_algorithm VARCHAR(16) DEFAULT 'SHA-256',
    canonicalization_version VARCHAR(32) DEFAULT 'ciaf-json-v1',
    lifecycle_stage VARCHAR(50) NOT NULL,
    object_type VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    version VARCHAR(50),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    owner_id UUID REFERENCES public.principals(id) ON DELETE SET NULL,
    location_uri VARCHAR(1000),
    size_bytes BIGINT,
    is_approved BOOLEAN DEFAULT false,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    tags JSONB DEFAULT '[]'::jsonb
);

CREATE TABLE public.ai_lifecycle_object_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    source_object_id UUID NOT NULL REFERENCES public.ai_lifecycle_objects(id) ON DELETE CASCADE,
    target_object_id UUID NOT NULL REFERENCES public.ai_lifecycle_objects(id) ON DELETE CASCADE,
    link_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_by UUID,
    notes TEXT,
    UNIQUE(source_object_id, target_object_id, link_type)
);

CREATE INDEX idx_ai_objects_org ON public.ai_lifecycle_objects(organization_id);
CREATE INDEX idx_ai_object_links_org ON public.ai_lifecycle_object_links(organization_id);
