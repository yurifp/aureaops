# Base44 — Matriz de permissões (RBAC)

Legenda: **C** criar · **R** ler · **U** atualizar · **D** excluir · **M** dados de contato mascarados

| Entidade / tela | admin | gestor | atendente | leitura |
|---|---|---|---|---|
| Cliente | CRUD | RUD | R | R (M) |
| Pedido | CRUD | RUD | R | R (M) |
| Chamado | CRUD | CRUD | CRU (sem excluir) | R (M) |
| Interacao | CRUD | CRUD | CRU | R |
| Campanha | CRUD | CRUD | R | — |
| Lead | CRUD | CRUD | RU (atende e movimenta funil) | R (M) |
| LogIntegracao | CRUD | R | — | — |
| Painel de SLA / Leads | sim | sim | sim | sim |
| Configurações / API keys | sim | — | — | — |

Decisões declaradas:
1. Atendente não exclui nada — correção de dados é tarefa do gestor (rastreável).
2. Papel **leitura** existe para demonstrar LGPD na prática: vê o processo, não o
   dado pessoal cru.
3. `request_id` é visível para admin/gestor (depuração de idempotência).

## Processo de onboarding / offboarding (resumo operacional)

**Onboarding:** pessoa criada no provedor de identidade → gestor adiciona no
Base44 com o papel mínimo necessário → e-mail de boas-vindas com link do
runbook → conferência em 7 dias (acesso adequado ao que a pessoa faz?).
**Offboarding:** aviso de RH/saída → remoção do Base44 no mesmo dia → revogação
de API Keys pessoais → conferência na matriz abaixo (admin-ti/matriz-acessos.xlsx).

A versão completa, por sistema (Sheets, n8n, Base44, Gmail), está na planilha
`admin-ti/matriz-acessos.xlsx` gerada por `admin-ti/gerar_admin.py`.
