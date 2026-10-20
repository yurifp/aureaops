# AureaOps — Dicionário de Dados

Tipos na notação SQLite (equivalência PostgreSQL direta). Timestamps em texto ISO-8601 UTC.
Todos os dados de pessoa são **fictícios** (domínios `@example.com` / `@aureahome.example`, DDD 00).

## Tabela `clientes`

| Coluna | Tipo | Regra | Descrição |
|---|---|---|---|
| id | INTEGER PK | autoincrement | Identificador do cliente |
| nome | TEXT NOT NULL | ≥ 3 caracteres | Nome completo |
| email | TEXT NOT NULL UNIQUE | formato e-mail (CHECK LIKE) | Login de contato |
| telefone | TEXT NOT NULL | 8–20 caracteres | Formato livre; mascarado em logs |
| created_at | TEXT | default now | Criação do registro |
| updated_at | TEXT | nullable | Última atualização |

## Tabela `pedidos`

| Coluna | Tipo | Regra | Descrição |
|---|---|---|---|
| id | INTEGER PK | autoincrement | Identificador do pedido |
| cliente_id | INTEGER FK → clientes | NOT NULL | Dono do pedido |
| numero_pedido | TEXT UNIQUE | ≥ 5 caracteres | Código exibido ao cliente (`PED-2026-1001`) |
| data_pedido | TEXT | NOT NULL | Data da compra |
| valor_total | REAL | > 0 | Valor em reais |
| status | TEXT | enum `pendente, pago, enviado, entregue, cancelado` | Situação logística |
| created_at | TEXT | default now | Criação |

## Tabela `chamados`

| Coluna | Tipo | Regra | Descrição |
|---|---|---|---|
| id | INTEGER PK | autoincrement | Identificador do chamado |
| cliente_id | INTEGER FK → clientes | NOT NULL | Solicitante |
| pedido_id | INTEGER FK → pedidos | nullable | NULL quando o pedido não localiza |
| protocolo | TEXT UNIQUE | `SAC-AAAAMMDD-NNNN` | Código devolvido ao cliente |
| motivo | TEXT | enum `troca, atraso, defeito, duvida` | Motivo declarado no formulário |
| prioridade | TEXT | enum `alta, media, baixa` | Derivada do motivo (premissa 1) |
| sla_horas | INTEGER | CHECK IN (4,24,72) | Prazo alvo de resolução |
| status | TEXT | enum `aberto, em_atendimento, aguardando_cliente, resolvido, cancelado` | Ciclo de vida |
| descricao | TEXT | ≥ 10 caracteres | Relato do cliente |
| vinculo_pedido_ok | INTEGER | 0/1 | 1 = pedido encontrado no lookup |
| escalado | INTEGER | 0/1 | 1 = gestor já avisado por estouro de SLA |
| request_id | TEXT UNIQUE | UUID v4 | Idempotência (gerado no front) |
| aberto_em / primeira_resposta_em / resolvido_em | TEXT | ISO-8601 | Marcos do SLA |
| created_at | TEXT | default now | Criação |

## Tabela `interacoes_chamado`

| Coluna | Tipo | Regra | Descrição |
|---|---|---|---|
| id | INTEGER PK | autoincrement | Identificador |
| chamado_id | INTEGER FK → chamados | ON DELETE CASCADE | Chamado pai |
| autor | TEXT | enum `cliente, atendente, sistema` | Quem produziu |
| canal | TEXT | enum `web, whatsapp, email, interno` | Por onde chegou |
| mensagem | TEXT | NOT NULL | Conteúdo |
| created_at | TEXT | default now | Momento |

## Tabela `campanhas`

| Coluna | Tipo | Regra | Descrição |
|---|---|---|---|
| id | INTEGER PK | autoincrement | Identificador |
| nome | TEXT | NOT NULL | Nome de exibição |
| utm_source / utm_medium / utm_campaign | TEXT | UNIQUE(3 juntos) | Chave UTM da campanha |
| ativa | INTEGER | 0/1 | Liga/desliga captação |
| created_at | TEXT | default now | Criação |

## Tabela `leads`

| Coluna | Tipo | Regra | Descrição |
|---|---|---|---|
| id | INTEGER PK | autoincrement | Identificador |
| nome / email / telefone | TEXT | mesmas regras de clientes | Contato do lead |
| interesse / mensagem | TEXT | nullable | Intenção declarada |
| campanha_id | INTEGER FK → campanhas | nullable | Atribuição UTM |
| utm_term / utm_content | TEXT | nullable | Granularidade extra |
| consentimento_lgpd | INTEGER | 0/1, NOT NULL | Aceite no formulário (obrigatório =1) |
| status | TEXT | enum `novo, distribuido, contatado, convertido, perdido, nao_respondeu` | Funil |
| vendedor | TEXT | nullable | Escolhido no round-robin |
| distribuido_em / primeiro_contato_em / convertido_em | TEXT | nullable | Marcos do funil |
| base44_sync | INTEGER | 0/1 | 1 = espelhado no Base44 |
| request_id | TEXT UNIQUE | UUID v4 | Idempotência |
| created_at | TEXT | default now | Criação |

## Tabela `logs_integracao` (isolada, sem FK)

| Coluna | Tipo | Regra | Descrição |
|---|---|---|---|
| id | INTEGER PK | autoincrement | Identificador |
| fluxo | TEXT | enum `F1, F2, F3` | Fluxo de origem |
| evento | TEXT | livre (`webhook_recebido`, `gravacao_sheets`, `erro_base44`…) | O que aconteceu |
| status | TEXT | enum `sucesso, erro, aviso` | Natureza |
| request_id | TEXT | nullable | Amarra ao payload |
| http_status | INTEGER | nullable | Código HTTP da integração |
| detalhe | TEXT | JSON **mascarado** | Contexto sem dado sensível |
| criado_em | TEXT | default now | Momento |

## Contrato de resposta padronizado (todas as APIs do projeto)

```json
{
  "sucesso": true,
  "codigo": "OK",
  "mensagem": "Chamado registrado.",
  "dados": { "protocolo": "SAC-20261020-0007" },
  "request_id": "uuid-v4"
}
```

| código | HTTP | Quando |
|---|---|---|
| OK | 200 | Processado (ou reprocesso idempotente, `dados.duplicado=true`) |
| ERRO_AUTENTICACAO | 401 | API Key ausente/incorreta |
| ERRO_VALIDACAO | 400 | Campo inválido ou consentimento ausente |
| ERRO_DUPLICADO | 409 | Conflito real de unicidade (não idempotente) |
| ERRO_INTERNO | 500 | Exceção inesperada (registrada em log) |

O front-end trata também **429** (retentativa com backoff) mesmo que os MVPs locais não o emitam — o comportamento faz parte do contrato defensivo.

## Schemas dos payloads

- F1 (chamado): [`docs/schemas/f1-chamado.schema.json`](schemas/f1-chamado.schema.json)
- F2 (lead): [`docs/schemas/f2-lead.schema.json`](schemas/f2-lead.schema.json)
