# AureaOps — Matriz de rastreabilidade (requisito da vaga → evidência no projeto)

| Requisito da vaga | Onde está comprovado |
|---|---|
| Low-Code (**Base44** como diferencial) | `base44/prompt-construcao.md`, `base44/entidades.md`, `base44/permissoes.md` (app interno com entidades, papéis e painéis) |
| Lógica de programação | `apps-script/Code.gs` (validação, round-robin, retry), `n8n/*.json` (Code nodes de SLA/KPI), `database/queries.sql` |
| JavaScript | `frontend/chamado.html` e `frontend/lead.html` (fetch, UUID, estados, backoff), `Code.gs` (V8), Code nodes do n8n |
| Google Apps Script | `apps-script/Code.gs` + `appsscript.json`: doPost/doGet, triggers por horário, UrlFetchApp, deploy Web App (README) |
| HTML5/CSS3 | `frontend/*.html` — semântica, responsivo, acessibilidade (labels, aria-live, focus-visible, contraste) |
| JSON | `docs/schemas/*.json`, `tests/payloads/`, payloads em todos os fluxos |
| APIs REST | `openapi/openapi.yaml`, integrações Base44 no n8n/Apps Script |
| Webhooks | `n8n/f1-sac.json` (webhook node + resposta 200/400/401), `doPost` do Apps Script |
| Postman | `postman/colecao.json` (v2.1, testes `pm.test`, variáveis) + 2 ambientes |
| OAuth2 e API Key | `docs/seguranca.md` (quando usar, authorization code, access/refresh, escopos, rotação); OAuth2 no node Google Sheets; API Key nos webhooks |
| SQL e modelagem | `database/schema.sql` (7 tabelas, PK/FK/índices/CHECKs), `views.sql`, `queries.sql`, ER em `docs/processos.md` |
| Excel avançado | `bi-excel/gerar_bi.py` (XLOOKUP/CONT.SES/SOMARPRODUTO, tabela dinâmica, gráficos, validação, formatação condicional), `bi-excel/formulas.md`, `bi-excel/powerquery.m`, `admin-ti/cotacao.xlsx` |
| n8n / Make / Power Automate | Workflows: `n8n/f1-sac.json`, `n8n/f2-leads.json`, `n8n/f3-relatorios.json`, `n8n/error-workflow.json`; comparativo + F2 no Make: `docs/comparativo-ferramentas.md` |
| Automações de WhatsApp | MODO simulado/real nos workflows (Cloud API + templates + opt-in/opt-out), explicação oficial x não oficial em `docs/comparativo-ferramentas.md` |
| Notificações e alertas | Avisos de chamado, escalonamento de SLA, follow-up D+1/D+3, relatórios F3 e error workflow global |
| Mapeamento de processos | `docs/processos.md` (AS-IS x TO-BE de F1/F2/F3 em Mermaid) |
| Documentação | `README.md`, `docs/` (arquitetura, api, seguranca, runbook, dicionário) |
| Gestão de acessos | `base44/permissoes.md` (RBAC), `admin-ti/matriz-acessos.xlsx` (onboarding/offboarding) |
| Apoio administrativo de TI | `admin-ti/licencas.xlsx` (custo/renovação/alerta), `admin-ti/cotacao.xlsx` (3 fornecedores, pontuação ponderada) |
