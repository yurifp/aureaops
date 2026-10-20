# AureaOps — Plano de testes

Objetivo: provar que os contratos de F1 e F2 se sustentam no sucesso E na
falha, e que nada se perde ou duplica silenciosamente.

## 1. Testes de contrato (automatizados)

Script: `tests/scripts/testar_api.mjs` (Node 18+, sem dependências).
Payloads: `tests/payloads/*.json`. Coleção Postman equivalente:
`postman/colecao.json` (mesmos cenários com `pm.test`).

```bash
F1_URL=http://localhost:5678/webhook/f1-chamado \
F1_KEY=$(grep ^API_KEY_F1 .env | cut -d= -f2) \
F2_URL="https://script.google.com/macros/s/SEU_ID/exec" \
F2_KEY=$(grep ^API_KEY_LEADS .env | cut -d= -f2) \
node tests/scripts/testar_api.mjs
```

| # | Cenário | Entrada | Resultado esperado |
|---|---|---|---|
| T1 | F1 válido | `f1-valido.json` + `X-Api-Key` | HTTP 200, `sucesso=true`, `protocolo` `SAC-AAAAMMDD-NNNN`, linha nova na aba chamados, log `chamado_processado` |
| T2 | F1 idempotência | mesmo arquivo reenviado | HTTP 200 com `dados.duplicado=true` e o MESMO protocolo; nenhuma linha nova |
| T3 | F1 sem chave | payload válido sem header | HTTP 401, `codigo=ERRO_AUTENTICACAO` |
| T4 | F1 motivo inválido | `f1-invalido-motivo.json` | HTTP 400, `dados.erros.motivo` preenchido |
| T5 | F1 sem LGPD | `f1-invalido-consentimento.json` | HTTP 400, `dados.erros.consentimento_lgpd` |
| T6 | F2 healthcheck | `GET ?action=status` | `sucesso=true` com versão |
| T7 | F2 válido | `f2-valido.json` + `api_key` | HTTP 200 (sempre), `codigo=OK`, `protocolo` `LED-…`, vendedor atribuído, arquivo no Drive, linha na aba leads |
| T8 | F2 idempotência | reenvio do mesmo payload | `duplicado=true`, mesmo protocolo/vendedor |
| T9 | F2 e-mail inválido | `f2-invalido-email.json` | `codigo=ERRO_VALIDACAO` com `erros.email` |
| T10 | F2 chave errada | `api_key=chave-errada` | `codigo=ERRO_AUTENTICACAO` |

## 2. Testes de interface (manual, 15 min)

- [ ] `chamado.html`: enviar vazio → erros por campo, foco no primeiro inválido.
- [ ] Botão desabilita durante envio e mostra "Enviando…".
- [ ] Sem rede (DevTools → Offline) → 2 retentativas com backoff e mensagem final.
- [ ] Sucesso → painel verde com protocolo; `request_id` novo a cada envio.
- [ ] `lead.html` com `?utm_source=instagram&utm_campaign=primavera-2026` →
      valores chegam na aba leads (e sobrevivem à navegação via sessionStorage).
- [ ] Teclado apenas (Tab/Espaço) e leitor de tela: labels e `aria-live` ok.

## 3. Testes de automação (manual, n8n/Apps Script)

- [ ] SLA: crie um chamado `defeito` (4h) e retroaje `aberto_em` na planilha em
      -5h → na hora seguinte o workflow escala: e-mail do gestor + `escalado=1`
      + log `sla_escalonamento`. Reexecutar não reescala.
- [ ] Follow-up: lead com `distribuido_em` = ontem e sem contato → 09:00 envia
      e-mail ao vendedor (log `followup_d1`); com 3 dias → escala e status
      `nao_respondeu` (`followup_d3`).
- [ ] F3: executar manualmente o workflow → e-mail com KPIs + log
      `relatorio_diario`; conferir 2-3 números contra a aba.
- [ ] Error workflow: forçar erro (ex.: parar o n8n? não — desativar a
      credencial SMTP e rodar o F3) → alerta imediato + log `erro_workflow`.
- [ ] WhatsApp simulado: confirmar no e-mail do atendente o bloco "conteúdo que
      seria enviado".

## 4. Testes de dados/BI

- [ ] `python database/validar_sql.py` termina com "Tudo verde".
- [ ] `python bi-excel/gerar_bi.py` gera o xlsx; abrir KPIs e recalcular (F9):
      % SLA = resolvidos no prazo ÷ resolvidos (conferir contra `vw_sla_resumo`).
- [ ] `python admin-ti/gerar_admin.py` gera as 3 planilhas; dropdowns e
      formatação condicional presentes.

## 5. Checklist de aceite final

- [ ] T1–T10 verdes no script e/ou Postman
- [ ] Nenhum segredo no Git (`git grep -iE "api[_-]?key|token|senha" ` só aponta placeholders)
- [ ] `logs_integracao` registra TODOS os eventos de teste acima
- [ ] README executa do zero por outra pessoa (clone → validar_sql → gerar_bi)
