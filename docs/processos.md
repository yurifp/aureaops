# AureaOps — Mapeamento de Processos (AS-IS x TO-BE) e Modelo de Dados

Empresa fictícia: **Aurea Home**, e-commerce D2C de casa e decoração.
Escopo do MVP: apenas os fluxos **F1 (SAC pós-venda)**, **F2 (Captação de leads)** e **F3 (Relatórios e alertas)**.

## Premissas e decisões declaradas

| # | Premissa/Decisão | Justificativa (1 linha) |
|---|---|---|
| 1 | Prioridade deriva do motivo: `defeito→alta(4h)`, `troca→media(24h)`, `atraso→media(24h)`, `duvida→baixa(72h)` | Remove decisão humana do passo crítico e torna o SLA determinístico. |
| 2 | SLA conta **horas corridas** (não úteis) | Horas úteis exigem calendário/feriados — fora do MVP; declarado como limitação. |
| 3 | Fuso único `America/Sao_Paulo` (n8n, Apps Script, Sheets) | D2C nacional com uma equipe de atendimento; evita conversões. |
| 4 | Chamado sem pedido localizado é **aceito** com `vinculo_pedido_ok=0` | Não perder contato do cliente por erro de digitação; atraso tratado depois. |
| 5 | WhatsApp nasce em **MODO=simulado** (log + e-mail) | Fluxo testável de ponta a ponta sem conta Meta; troca por 1 variável de ambiente. |
| 6 | `request_id` (UUID v4) gerado no front-end e único no banco | Idempotência: reenvio/clique duplo não duplica chamado nem lead. |

---

## F1 — Atendimento pós-venda (SAC)

### AS-IS (manual)

```mermaid
flowchart TD
    A["Cliente com problema<br/>(troca, atraso, defeito, dúvida)"] --> B["Envia e-mail ou liga para o SAC"]
    B --> C["Atendente copia dados para planilha"]
    C --> D["Busca pedido manualmente no sistema"]
    D --> E["Responde por e-mail"]
    E --> F["Gestor descobre atraso só no relatório mensal"]
    style F fill:#f2c4c4
```

Dores: dado digitado várias vezes, sem vínculo garantido pedido×chamado, sem SLA observável, escalonamento reativo.

### TO-BE (automatizado)

```mermaid
flowchart TD
    A["Formulário web (chamado.html)"] -->|"POST JSON + X-Api-Key + request_id"| B["Webhook n8n (f1-chamado)"]
    B --> C{"API Key válida?"}
    C -->|não| R401["401 ERRO_AUTENTICACAO"]
    C -->|sim| D{"Validação de campos<br/>e consentimento LGPD"}
    D -->|inválido|R400["400 ERRO_VALIDACAO"]
    D -->|válido| E{"request_id já existe?<br/>(idempotência)"}
    E -->|sim| R200d["200 resposta original<br/>(duplicado)"]
    E -->|não| F["Deriva prioridade/SLA do motivo"]
    F --> G["Vincula pedido<br/>(lookup por numero_pedido)"]
    G --> H["Grava no Google Sheets (OAuth2)"]
    G --> I["Grava no Base44 (API Key)"]
    H --> J["Avisa atendente<br/>WhatsApp (MODO) + e-mail"]
    I --> J
    J --> R200["200 protocolo SAC-AAAAMMDD-NNNN"]
    K["Schedule n8n<br/>(a cada 1h)"] --> L["Avalia SLA dos chamados abertos"]
    L -->|"venceu e não escalado"| M["Escalona gestor<br/>WhatsApp + e-mail + marca escalado=1"]
    L --> O["Registra tudo em logs_integracao"]
    style R401 fill:#f2c4c4
    style R400 fill:#f2c4c4
    style R200 fill:#c8e6c9
```

---

## F2 — Captação de leads (Comercial + Marketing)

### AS-IS (manual)

```mermaid
flowchart TD
    A["Visitante clica em campanha<br/>(UTM ignorado)"] --> B["Preenche formulário do site"]
    B --> C["Lead chega por e-mail solto"]
    C --> D["Gerente lê e repassa 'na mão'<br/>para o vendedor do dia"]
    D --> E["Follow-up depende da memória do vendedor"]
    E --> F["Sem origem rastreável = verba de mídia às cegas"]
    style F fill:#f2c4c4
```

### TO-BE (automatizado)

```mermaid
flowchart TD
    A["Formulário web (lead.html)<br/>captura UTMs da URL"] -->|"POST JSON + X-Api-Key + request_id"| B["Apps Script doPost (web app)"]
    B --> C{"API Key válida?"}
    C -->|não| R401["401 ERRO_AUTENTICACAO"]
    C -->|sim| D{"Validação + LGPD +<br/>idempotência (request_id)"}
    D -->|erro|R400["400 ERRO_VALIDACAO"]
    D -->|ok| E["Grava aba 'leads' no Sheets"]
    E --> F["Salva payload original no Drive<br/>(pasta por mês)"]
    F --> G["Round-robin entre vendedores<br/>(ponteiro em Script Properties)"]
    G --> H["Espelha no Base44<br/>(UrlFetchApp + retry/backoff)"]
    H --> I["200 protocolo LED-AAAAMMDD-NNNN"]
    J["Trigger diária 09:00<br/>(Apps Script)"] --> K{"Lead sem 1º contato?"}
    K -->|"D+1"| L["E-mail de lembrete ao vendedor"]
    K -->|"D+3"| M["Escala ao gestor + status nao_respondeu"]
    L --> N["Registra em logs_integracao"]
    M --> N
    style R401 fill:#f2c4c4
    style R400 fill:#f2c4c4
    style I fill:#c8e6c9
```

Observação: o espelho no Base44 usa `UrlFetchApp` com retry exponencial; o workflow **n8n `f2-leads.json`** roda uma sincronização em lote a cada 15 min como rede de segurança (leads com `base44_sync=0`).

---

## F3 — Relatórios e alertas (BI)

### AS-IS (manual)

```mermaid
flowchart TD
    A["Segunda-feira"] --> B["Analista abre 3 planilhas"]
    B --> C["Copia/cola em e-mail com números da semana"]
    C --> D["Falha de automação ninguém fica sabendo"]
    style D fill:#f2c4c4
```

### TO-BE (automatizado)

```mermaid
flowchart TD
    S1["Schedule diário 07:00"] --> P1["Lê Sheets: chamados e leads 24h"]
    S2["Schedule semanal seg 07:30"] --> P2["Lê Sheets: janela de 7 dias"]
    P1 --> K["Code node calcula KPIs<br/>(SLA, volumes, conversão)"]
    P2 --> K
    K --> E["E-mail HTML para gestor"]
    K --> W["WhatsApp (MODO simulado/real)"]
    K --> L["Registra em logs_integracao"]
    X["Error Workflow global do n8n"] -->|"qualquer workflow falha"| Y["E-mail + WhatsApp imediato<br/>ao gestor + log erro"]
    style Y fill:#ffe0b2
```

---

## Modelo relacional — Diagrama ER

```mermaid
erDiagram
    clientes ||--o{ pedidos : "realiza"
    clientes ||--o{ chamados : "abre"
    pedidos  |o--o{ chamados : "referencia (0..1)"
    chamados ||--o{ interacoes_chamado : "registra"
    campanhas |o--o{ leads : "atribui (via UTM)"
    clientes {
        integer id PK
        text nome
        text email UK
        text telefone
        text created_at
    }
    pedidos {
        integer id PK
        integer cliente_id FK
        text numero_pedido UK
        text data_pedido
        real valor_total
        text status
    }
    chamados {
        integer id PK
        integer cliente_id FK
        integer pedido_id FK "nullable"
        text protocolo UK
        text motivo
        text prioridade
        integer sla_horas
        text status
        integer escalado
        text request_id UK
        text aberto_em
    }
    interacoes_chamado {
        integer id PK
        integer chamado_id FK
        text autor
        text canal
        text mensagem
    }
    campanhas {
        integer id PK
        text nome
        text utm_source
        text utm_medium
        text utm_campaign
        integer ativa
    }
    leads {
        integer id PK
        integer campanha_id FK "nullable"
        text request_id UK
        integer consentimento_lgpd
        text status
        text vendedor
        text primeiro_contato_em
    }
    logs_integracao {
        integer id PK
        text fluxo "F1|F2|F3"
        text evento
        text status
        text request_id
        integer http_status
        text detalhe "JSON mascarado"
    }
```

`logs_integracao` é propositalmente **isolada** (sem FK): auditoria precisa sobreviver mesmo quando a linha de negócio é apagada, e o log nunca deve quebrar o fluxo principal.

## Como testar (banco)

```bash
cd database
sqlite3 aureaops.db < schema.sql && sqlite3 aureaops.db < seed.sql && sqlite3 aureaops.db < views.sql
sqlite3 aureaops.db < queries.sql
```

(ou `python database/validar_sql.py`, que executa tudo em memória e imprime as respostas)
