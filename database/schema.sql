-- ============================================================================
-- AureaOps — schema.sql (SQLite 3.25+, padrão SQL portável para PostgreSQL)
-- Empresa fictícia: Aurea Home (e-commerce D2C de casa e decoração)
--
-- Convenções:
--   * identificadores em snake_case; timestamps em TEXTO ISO-8601 UTC
--     ("YYYY-MM-DD HH:MM:SS") — decisão: simplifica exportação/importação
--     entre SQLite, Google Sheets e JSON sem lossy conversions.
--   * CHECKs garantem domínio fechado de enumerações (evita status inválido
--     vindo de integração).
--   * request_id (UUID v4 gerado no front-end) único em chamados/leads:
--     idempotência — reenvio do mesmo payload não duplica registro.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------- clientes --
CREATE TABLE clientes (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  nome        TEXT    NOT NULL CHECK (length(trim(nome)) >= 3),
  email       TEXT    NOT NULL UNIQUE CHECK (email LIKE '%_@_%._%'),
  telefone    TEXT    NOT NULL CHECK (length(telefone) BETWEEN 8 AND 20),
  created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT
);
CREATE INDEX idx_clientes_email ON clientes(email);

-- ----------------------------------------------------------------- pedidos --
CREATE TABLE pedidos (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  cliente_id     INTEGER NOT NULL REFERENCES clientes(id),
  numero_pedido  TEXT    NOT NULL UNIQUE CHECK (length(numero_pedido) >= 5),
  data_pedido    TEXT    NOT NULL,
  valor_total    REAL    NOT NULL CHECK (valor_total > 0),
  status         TEXT    NOT NULL DEFAULT 'pago'
                  CHECK (status IN ('pendente','pago','enviado','entregue','cancelado')),
  created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_pedidos_cliente ON pedidos(cliente_id);
CREATE INDEX idx_pedidos_numero  ON pedidos(numero_pedido);

-- ---------------------------------------------------------------- chamados --
-- Prioridade e SLA derivados do motivo (regra declarada no docs/processos.md):
--   defeito -> alta (4h) | troca/atraso -> media (24h) | duvida -> baixa (72h)
CREATE TABLE chamados (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  cliente_id            INTEGER NOT NULL REFERENCES clientes(id),
  pedido_id             INTEGER REFERENCES pedidos(id),          -- NULL se pedido não localizado
  protocolo             TEXT    NOT NULL UNIQUE,                 -- SAC-AAAAMMDD-NNNN
  motivo                TEXT    NOT NULL CHECK (motivo IN ('troca','atraso','defeito','duvida')),
  prioridade            TEXT    NOT NULL CHECK (prioridade IN ('alta','media','baixa')),
  sla_horas             INTEGER NOT NULL CHECK (sla_horas IN (4, 24, 72)),
  status                TEXT    NOT NULL DEFAULT 'aberto'
                          CHECK (status IN ('aberto','em_atendimento','aguardando_cliente',
                                            'resolvido','cancelado')),
  descricao             TEXT    NOT NULL CHECK (length(descricao) >= 10),
  vinculo_pedido_ok     INTEGER NOT NULL DEFAULT 1 CHECK (vinculo_pedido_ok IN (0,1)),
  escalado              INTEGER NOT NULL DEFAULT 0 CHECK (escalado IN (0,1)),
  request_id            TEXT    NOT NULL UNIQUE,
  aberto_em             TEXT    NOT NULL,
  primeira_resposta_em  TEXT,
  resolvido_em          TEXT,
  created_at            TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_chamados_status     ON chamados(status);
CREATE INDEX idx_chamados_aberto_em  ON chamados(aberto_em);
CREATE INDEX idx_chamados_prioridade ON chamados(prioridade);

-- ------------------------------------------------------ interacoes_chamado --
CREATE TABLE interacoes_chamado (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  chamado_id  INTEGER NOT NULL REFERENCES chamados(id) ON DELETE CASCADE,
  autor       TEXT    NOT NULL CHECK (autor IN ('cliente','atendente','sistema')),
  canal       TEXT    NOT NULL CHECK (canal IN ('web','whatsapp','email','interno')),
  mensagem    TEXT    NOT NULL,
  created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_interacoes_chamado ON interacoes_chamado(chamado_id);

-- --------------------------------------------------------------- campanhas --
-- A tupla UTM (source, medium, campaign) identifica unicamente uma campanha.
CREATE TABLE campanhas (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  nome          TEXT    NOT NULL,
  utm_source    TEXT    NOT NULL,
  utm_medium    TEXT    NOT NULL,
  utm_campaign  TEXT    NOT NULL,
  ativa         INTEGER NOT NULL DEFAULT 1 CHECK (ativa IN (0,1)),
  created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
  UNIQUE (utm_source, utm_medium, utm_campaign)
);

-- ------------------------------------------------------------------- leads --
CREATE TABLE leads (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  nome                 TEXT    NOT NULL CHECK (length(trim(nome)) >= 3),
  email                TEXT    NOT NULL CHECK (email LIKE '%_@_%._%'),
  telefone             TEXT    NOT NULL CHECK (length(telefone) BETWEEN 8 AND 20),
  interesse            TEXT,                            -- ex.: "Sofá retrátil"
  mensagem             TEXT,
  campanha_id          INTEGER REFERENCES campanhas(id),
  utm_term             TEXT,
  utm_content          TEXT,
  consentimento_lgpd   INTEGER NOT NULL CHECK (consentimento_lgpd IN (0,1)),
  status               TEXT    NOT NULL DEFAULT 'novo'
                         CHECK (status IN ('novo','distribuido','contatado',
                                           'convertido','perdido','nao_respondeu')),
  vendedor             TEXT,
  distribuido_em       TEXT,
  primeiro_contato_em  TEXT,
  convertido_em        TEXT,
  base44_sync          INTEGER NOT NULL DEFAULT 0 CHECK (base44_sync IN (0,1)),
  request_id           TEXT    NOT NULL UNIQUE,
  created_at           TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_leads_status          ON leads(status);
CREATE INDEX idx_leads_campanha        ON leads(campanha_id);
CREATE INDEX idx_leads_primeiro_contato ON leads(primeiro_contato_em);

-- --------------------------------------------------------- logs_integracao --
-- Auditoria de TODA integração (webhook recebido, gravação, envio, erro).
-- "detalhe" é JSON serializado SEM dados sensíveis (e-mail/telefone mascarados).
CREATE TABLE logs_integracao (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  fluxo        TEXT    NOT NULL CHECK (fluxo IN ('F1','F2','F3')),
  evento       TEXT    NOT NULL,   -- ex.: webhook_recebido, gravacao_sheets, erro_base44
  status       TEXT    NOT NULL CHECK (status IN ('sucesso','erro','aviso')),
  request_id   TEXT,
  http_status  INTEGER,
  detalhe      TEXT,               -- JSON string com dados mascarados
  criado_em    TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_logs_fluxo_criado ON logs_integracao(fluxo, criado_em);
CREATE INDEX idx_logs_request      ON logs_integracao(request_id);
CREATE INDEX idx_logs_status       ON logs_integracao(status);
