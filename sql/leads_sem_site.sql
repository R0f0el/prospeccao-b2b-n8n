CREATE TABLE IF NOT EXISTS leads_sem_site (
    id SERIAL PRIMARY KEY,
    osm_id BIGINT UNIQUE NOT NULL,
    nome VARCHAR(255) NOT NULL,
    categoria VARCHAR(100),
    cidade VARCHAR(120) NOT NULL,
    telefone VARCHAR(30) NOT NULL,
    whatsapp_link VARCHAR(100),
    is_mobile BOOLEAN DEFAULT FALSE,
    endereco TEXT,
    status_prospeccao VARCHAR(30) DEFAULT 'NOVO', -- NOVO, CONTATADO, NEGOCIANDO, DESCARTADO
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_leads_cidade ON leads_sem_site(cidade);
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads_sem_site(status_prospeccao);
