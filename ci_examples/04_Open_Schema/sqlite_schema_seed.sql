
CREATE TABLE IF NOT EXISTS ai_lifecycle_objects (
    object_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_sessions (
    session_id TEXT PRIMARY KEY,
    agent_principal_id TEXT NOT NULL,
    delegating_principal_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_delegations (
    delegation_id TEXT PRIMARY KEY,
    delegating_principal TEXT NOT NULL,
    agent_principal TEXT NOT NULL,
    authority_scope TEXT NOT NULL,
    token_hash TEXT NOT NULL,
    valid_until TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS shadow_ai_discovery_records (
    discovery_id TEXT PRIMARY KEY,
    destination_endpoint TEXT NOT NULL,
    payload_hash TEXT,
    risk_score INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed Data
INSERT OR IGNORE INTO ai_lifecycle_objects (object_id, name, type, hash) 
VALUES ('model_risk_valuation_v4', 'Risk Valuation Model', 'model', '8ab9f302b1c402a5e98bbcf7a0928e1008d5bbf0287ab6591024bc68e09f8723');

INSERT OR IGNORE INTO agent_sessions (session_id, agent_principal_id, delegating_principal_id) 
VALUES ('session_883a_992f', 'db_writer_agent_05', 'orchestrator_agent_01');

INSERT OR IGNORE INTO agent_delegations (delegation_id, delegating_principal, agent_principal, authority_scope, token_hash, valid_until) 
VALUES ('del_883a', 'orchestrator_agent_01', 'db_writer_agent_05', 'write_record,query_table', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', '2026-08-12 14:00:00');

INSERT OR IGNORE INTO shadow_ai_discovery_records (discovery_id, destination_endpoint, payload_hash, risk_score) 
VALUES ('disc_8829a', 'https://api.unapproved-llm.com/v1/chat', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b', 50);
