-- Family 9: Extension Vocabulary
-- This table stores controlled vocabularies and extension definitions of the platform.

CREATE TABLE public.ciaf_type_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_family VARCHAR(100) NOT NULL,
    type_key VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_ciaf_type_registry_family ON public.ciaf_type_registry(type_family);
