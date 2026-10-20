# AureaOps — Arquitetura

## Visão geral

```mermaid
flowchart LR
    subgraph Cliente["Navegador do usuário"]
        F1P["chamado.html<br/>(F1)"]
        F2P["lead.html<br/>(F2)"]
    end

    subgraph Automacao["Camada de automação"]
        N8N["n8n (local via npm)<br/>f1-sac · f2-leads · f3-relatorios<br/>error-workflow"]
        GAS["Google Apps Script<br/>(doPost F2 + triggers)"]
    end

    subgraph Google["Google Workspace"]
        SHEETS["Google Sheets<br/>(planilha AureaOps)"]
        DRIVE["Drive (payloads)"]
        GMAIL["Gmail (SMTP)"]
    end

    subgraph Dados["Dados e app interno"]
        B44["Base44<br/>(app AureaOps + API)"]
        SQLITE["SQLite (schema do projeto)"]
    end

    META["WhatsApp Cloud API<br/>(MODO=simulado por padrão)"]

    F1P -->|"POST JSON + X-Api-Key"| N8N
    F2P -->|"POST JSON + api_key"| GAS
    N8N <-->|"OAuth2"| SHEETS
    N8N -->|"X-API-Key"| B44
    N8N --> META
    N8N --> GMAIL
    GAS --> SHEETS
    GAS --> DRIVE
    GAS -->|"UrlFetchApp + retry"| B44
    GAS --> GMAIL
    SQLITE -.->|"exporta CSVs p/ BI"| BI["bi-excel/gerar_bi.py<br/>→ aureaops_bi.xlsx"]
```

## Responsabilidades por componente

| Componente | Responsabilidade | Por quê essa escolha |
|---|---|---|
| `frontend/` (HTML+CSS+JS puro) | Coleta com validação client-side, UUID (`request_id`), honeypot, estados de envio | Sem build/dependências — formulário precisa apenas ser servido |
| **n8n** (F1, sync F2, F3) | Webhook público com validação, gravação dupla (Sheets+Base44), SLA horário, relatórios, error workflow global | Motor principal da vaga; JSON exportável versionável no Git |
| **Apps Script** (F2) | doPost do lead, idempotência, round-robin, Drive, follow-up D+1/D+3 | Faz parte do requisito da vaga e mora dentro do Google Workspace |
| **Google Sheets** | Registro operacional (abas leads/chamados/logs/consentimentos/pedidos) | Planilha é a "fonte da verdade operacional" num MVP sem servidor |
| **Base44** | App interno com entidades, papéis e painéis (SLA, leads) + API REST | Diferencial low-code citado na vaga |
| **SQLite** | Modelo relacional canônico, views de BI e queries de exemplo | Comprova SQL/modelagem sem infraestrutura |
| **bi-excel/** | Gera pasta de trabalho com fórmulas, tabela dinâmica, gráficos + CSVs p/ Power Query | Excel avançado exigido pela vaga, calculado (não colado) |

## Decisões técnicas (resumo executável)

1. **Quem grava o quê** — F1 grava no Sheets (OAuth2 do n8n) e no Base44 (API Key);
   F2 grava no Sheets/Drive pelo Apps Script e espelha no Base44 com retry próprio;
   o workflow `f2-leads` do n8n é a rede de segurança (lote de 15 min para
   `base44_sync=0`). Evita duplicar a escrita principal e cria resiliência.
2. **Idempotência na borda** — `request_id` gerado no navegador é a chave única
   em chamados/leads; reenvio devolve a resposta original em vez de duplicar.
3. **Contrato único de resposta** — `{sucesso, codigo, mensagem, dados, request_id}`.
   Nuance: Apps Script responde sempre HTTP 200; o front do F2 decide pelo corpo.
4. **WhatsApp com chave `MODO=simulado|real`** — mesmo fluxo, entrega por
   e-mail+log no modo simulado; Cloud API com template e checagem de opt-out no real.
5. **Logs mascarados** — e-mail/telefone nunca aparecem inteiros em logs
   (`m***@e***.com`, `***0101`); LGPD por padrão.
6. **Falha nunca é silenciosa** — error workflow global (n8n) + registro em
   `logs_integracao` + alerta imediato ao gestor.

## Variáveis de ambiente (resumo)

Ver `.env.example` — nenhuma credencial real no repositório. No n8n self-hosted,
defina as variáveis na inicialização (`N8N_...`/custom) ou em Settings → Variables;
no Apps Script, use **Script Properties** (equivalente server-side do .env).
