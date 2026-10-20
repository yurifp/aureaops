# Comparativo: n8n x Make x Power Automate

Contexto de decisão: AureaOps é um MVP de automação para um e-commerce D2C fictício,
com Google Workspace, WhatsApp e uma API interna (Base44) no centro. Preços de out/2026,
sujeitos a alteração — confira antes de decidir.

## Tabela comparativa

| Critério | n8n (escolhido) | Make (Integromat) | Power Automate |
|---|---|---|---|
| **Modelo de hospedagem** | Cloud OU self-hosted (Docker/npm) — código aberto (fair-code) | Somente cloud | Somente cloud (Microsoft 365/Azure) |
| **Custo inicial** | Self-hosted: R$ 0 (roda no seu computador); Cloud: plano starter pago com execução limitada e trial | Plano free restrito; planos pagos por operações/mês | Incluído em várias licenças M365; premium por usuário/mês |
| **Curva de aprendizado** | Média: conceito de nodes/expressões JS | Média: visual em "bolhas" com cenários | Baixa para quem já usa Excel/Teams/SharePoint; alta fora do ecossistema Microsoft |
| **Linguagem/expressões** | JavaScript nativo (Code node) — igual ao resto do projeto | Fórmulas próprias (funções Make) | Expressões WDL/Excel-like; Azure Functions para código |
| **Limites práticos** | Self-hosted: sem limite de execuções (sua máquina é o limite) | Cobrança por operações; cenários com intervalo mínimo por plano | Depende do plano (ex.: intervalos mínimos de recorrência, conectores premium) |
| **Controle de versão/auditoria** | Workflows são JSON exportáveis (versionáveis no Git — este repo faz isso) | Exportação de blueprint (blueprint.json), menos difundido | Soluções/ALM via Power Platform; mais burocrático |
| **Ecossistema** | 400+ integrações + HTTP genérico (cobre qualquer API REST) | 1.500+ apps | Fortíssimo em Microsoft; REST genérico via HTTP connector |
| **Tratamento de erro** | Error Workflow global + retry por node + `onError` por node | Rotas de error handler por cenário | Escopos configure run-after; menos granular |
| **Quando escolher** | Time com alguém técnico, necessidade de self-hosting/JSON no Git, APIs customizadas | Time sem código, volume previsível, muitos apps SaaS prontos | Empresa já toda no Microsoft 365, automações internas de escritório |

## Por que o AureaOps escolheu n8n

1. **JSON exportável versionado no Git** — o repositório prova exatamente o que roda (reprodutibilidade).
2. **Code node em JavaScript** — mesma linguagem do front-end e do Apps Script; uma só stack para explicar.
3. **Self-hosted via npm** — custo zero para o portfólio e sem limite de execuções durante testes.
4. **Error Workflow global** — requisito F3 (alerta imediato em qualquer falha) resolvido com um artefato só.

## WhatsApp: API oficial x soluções não oficiais

| Aspecto | WhatsApp Cloud API (oficial, Meta) | APIs não oficiais (bibliotecas que "robotizam" o app/QrCode) |
|---|---|---|
| Risco de bloqueio | Baixo (dentro das regras) | **Alto**: viola os termos de uso; número pode ser banido sem aviso |
| Estabilidade | SLA da Meta, webhooks oficiais | Quebra a cada mudança do app; sem garantia |
| Custo | Conversação cobrada por janela de 24h (categorias serviço/utilidade/marketing) | Aparece "grátis", mas o custo é o risco operacional |
| Conformidade (LGPD) | Dados processados sob contrato da Meta; opt-in/opt-out nativos do template | Dados passam por terceiro sem base legal clara |
| Templates | Obrigatórios fora da janela de 24h; aprovação prévia | Mensagem livre (e é exatamente por isso que vira spam) |

**Decisão do projeto:** a automação nasce com `MODO_WHATSAPP=simulado` (mensagem vai para
log + e-mail). O modo `real` já está implementado apontando para a Cloud API com templates
`chamado_aberto`, `resumo_periodo` e `alerta_falha`. Trocar é mudar UMA variável de ambiente
— o resto do fluxo é idêntico. **Opt-in:** registrado na aba `consentimentos` pelo formulário
(LGPD). **Opt-out:** qualquer envio real checa essa aba antes; o atendente também pode marcar
`opt_out_em` manualmente (limite declarado do MVP: não há listener de resposta "PARAR" —
precisaria de um webhook de mensagens recebidas, fora do escopo).

## Mini-design textual: F2 no Make

Cenário **"AureaOps F2 — leads"** (equivalente ao que o Apps Script + n8n fazem hoje):

1. **Trigger — Webhooks**: hook customizado `f2-lead` (Make valida um "inline API key" no header igual ao IF do n8n).
2. **Router** com 2 rotas:
   - Rota A (filtro: `map([];request_id)` não existe no Data Store) → continua.
   - Rota B (duplicado) → **Webhook Response** 200 com `duplicado: true` e fim.
3. **Google Sheets — Add a Row** (planilha AureaOps, aba leads).
4. **Data Store — "round_robin"**: incrementa `ponteiro` com `modulo(qtd_vendedores)` e lê o vendedor da posição (o Data Store faz o papel das Script Properties do Apps Script).
5. **HTTP — POST Base44** com retry nativo (Make permite definir número de tentativas com intervalo) + rota de error handler que grava **Add a Row** na aba logs com `status=erro`.
6. **Email — Send** para o vendedor.
7. Agendamento paralelo (**Schedule**, diário 09:00) + **Google Sheets — Search Rows** (`status=distribuido` e `primeiro_contato_em` vazio) + **filter** por data → **Email** de follow-up D+1/D+3.

Diferenças práticas que eu citaria numa entrevista: no Make o round-robin precisa de um
Data Store externo (não há "estado global" no cenário), o retry é configurado por módulo
(mais simples que escrever backoff) e o tratamento de erro é por rota de handler — dá,
mas o resultado final não é versionável em Git com a mesma naturalidade do JSON do n8n.
