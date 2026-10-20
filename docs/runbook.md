# AureaOps — Runbook de suporte

Objetivo: diagnóstico rápido dos problemas mais prováveis, na ordem em que se
investiga. Regra de ouro: **todo incidente termina com registro em
`logs_integracao`** (se o fluxo não gravou, o error workflow do n8n gravou).

## Sinais vitais (comece por aqui)

| Checagem | Como | Saudável |
|---|---|---|
| F2 no ar | `curl ".../exec?action=status"` | `sucesso: true` |
| n8n no ar | `http://localhost:5678` abre e F1 workflow **Active** | badge ativa |
| Planilha acessível | Abrir aba `leads`/`chamados` — última linha recente | gravação corrente |
| Logs | Aba `logs` com `status=erro` nas últimas 24h | nenhum erro |

## Problemas comuns

### 1. Formulário F1 responde "sem conexão" / timeout
1. n8n está rodando? (`npx n8n`; porta 5678 livre?)
2. Workflow **AureaOps F1** está **Active** (toggle)? Webhook inativo devolve 404.
3. URL no `chamado.html` bate com o path `f1-chamado` (sem `/webhook-test/`
   — esse path é só do botão "Test workflow").
4. Ver `logs_integracao` → se nem `webhook_recebido` existe, a requisição
   nunca chegou (rede/URL). Se existe com `api_key_invalida`, a chave do front
   difere da `API_KEY_F1`.

### 2. F1 responde 401
- Header `X-Api-Key` ausente ou diferente de `API_KEY_F1` (n8n env/Variables).
- Rotacionou a chave e esqueceu o front? Sincronize os dois lados (docs/seguranca.md).

### 3. F1 responde 400 com lista de erros
- Comportamento ESPERADO para payload inválido. Confirme o domínio de
  `motivo`, o formato `PED-AAAA-NNNN` e `consentimento_lgpd: true`.

### 4. Chamado não aparece no Base44 (mas aparece no Sheets)
- Node `Criar no Base44`: abre a execução e veja o status HTTP (503/401).
- 401: `BASE44_API_KEY` inválida → TODO(manual) regenerar no painel do app.
- 503/timeout: o fluxo segue por design (aviso em logs); o sync do F2/n8n ou
  reexecução manual do workflow corrige depois. Se persistir: confirme
  `BASE44_API_URL` na documentação do seu app (path de resources).

### 5. Lead não recebe vendedor (`vendedor` vazio)
- Script Property `VENDEDORES` malformada — deve ser JSON array
  `[{"nome":"...","email":"..."}]`. Corrija e reenvie o payload de teste.

### 6. Follow-up D+1/D+3 não dispara
- Apps Script → Triggers: `followUpLeads` diária 09:00 existe? (rodar `setup_()`
  recria). Execuções com erro aparecem em "Executions".

### 7. SLA não escala chamado vencido
1. O trigger horário exige o workflow F1 **ativo** (não basta "Test workflow").
2. Linha do chamado tem `escalado=0` e status não final? `resolvido/cancelado`
   não escalam.
3. `aberto_em` no formato ISO? O Code node ignora datas não parseáveis.
4. Depois de escalar, `escalado` vira 1 — reescalonamento só após reset manual.

### 8. WhatsApp não sai (modo real)
- `MODO_WHATSAPP=real`? Templates `chamado_aberto`, `resumo_periodo`,
  `alerta_falha` APROVADOS na Meta? Token/phonenumber-id válidos?
- Destinatário com `opt_out_em` preenchido na aba consentimentos? (não envia —
  por design).
- No modo simulado a "entrega" é o e-mail do atendente/gestor — confira a caixa.

### 9. E-mails não chegam
- Credencial SMTP (senha de app Gmail, 2FA obrigatório) selecionada no node?
- Gmail limita ~500/dia em contas comuns — para volume maior, domínio próprio.

### 10. Apps Script responde 200 mas `codigo=ERRO_INTERNO`
- Aba `logs`, evento `erro_interno`: a mensagem está no `detalhe`.
- Causas frequentes: `SPREADSHEET_ID` errado; aba renomeada; cota do UrlFetchApp.

## Escalonamento

| Situação | Escalar para | Prazo |
|---|---|---|
| Erro em `logs_integracao` sem resolução em 1h | Gestor (alerta já automático) | 1h |
| Webhook fora do ar > 30min em horário comercial | TI (admin do n8n) | imediato |
| Dados pessoais em exposição indevida (incidente LGPD) | Gestor + encarregado | **imediato** — runbook de exclusão abaixo |

### Exclusão de dados a pedido do titular (LGPD)
1. Localizar linhas por e-mail nas abas `leads`/`chamados` (Ctrl+F).
2. Remover as linhas e apagar o payload do mês correspondente no Drive.
3. Zerar o registro no Base44 (entidade Lead/Chamado) e anexar nota no chamado
   de atendimento do pedido.
4. Registrar evento `lgpd_exclusao` em `logs_integracao` (sem dados pessoais no
   `detalhe` — só o `request_id`).
