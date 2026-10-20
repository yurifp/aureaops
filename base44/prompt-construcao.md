# Base44 — Prompt de construção do app "AureaOps"

> **Como usar:** crie um app novo no Base44 e cole o prompt abaixo inteiro no
> assistente de construção. Depois, confira as entidades/validações com
> `entidades.md` e os papéis com `permissoes.md`.
> **TODO(manual):** ao finalizar, gere uma API Key do app em Settings → API e
> preencha `BASE44_API_URL` / `BASE44_API_KEY` no `.env` do n8n e nas Script
> Properties do Apps Script. Valide criando um chamado pelo formulário e vendo
> o registro aparecer na tela de chamados.

---

## PROMPT (copie daqui para baixo)

Crie um aplicativo interno chamado **AureaOps** — central de atendimento, leads
e relatórios da Aurea Home, loja virtual fictícia de casa e decoração. Interface
em português do Brasil, visual sóbrio (tons areia/dourado escuro), identificadores
de campos em inglês com snake_case.

### Entidades e relacionamentos

1. **Cliente** — campos: nome (texto, obrigatório, mínimo 3), email (email,
   obrigatório, único), telefone (texto, obrigatório), created_at (data/hora,
   preenchida automaticamente).
2. **Pedido** — campos: cliente (relacionamento N:1 com Cliente, obrigatório),
   numero_pedido (texto, obrigatório, único, formato PED-9999-9999), data_pedido
   (data), valor_total (moeda, maior que zero), status (seleção: pendente, pago,
   enviado, entregue, cancelado; padrão pago).
3. **Chamado** — campos: cliente (N:1 com Cliente, obrigatório), pedido (N:1 com
   Pedido, opcional), protocolo (texto, obrigatório, único, formato
   SAC-AAAAMMDD-9999), motivo (seleção: troca, atraso, defeito, duvida),
   prioridade (seleção: alta, media, baixa), sla_horas (número: 4, 24 ou 72),
   status (seleção: aberto, em_atendimento, aguardando_cliente, resolvido,
   cancelado; padrão aberto), descricao (texto longo, mínimo 10 caracteres),
   vinculo_pedido_ok (booleano), escalado (booleano, padrão falso), request_id
   (texto, único), aberto_em / primeira_resposta_em / resolvido_em (data/hora).
   Regra de validação exibida: prioridade e SLA derivam do motivo — defeito →
   alta/4h; troca e atraso → media/24h; duvida → baixa/72h.
4. **Interacao** — campos: chamado (N:1 com Chamado, obrigatório, excluir em
   cascata), autor (seleção: cliente, atendente, sistema), canal (seleção: web,
   whatsapp, email, interno), mensagem (texto longo, obrigatório), created_at
   (data/hora automática).
5. **Campanha** — campos: nome (texto, obrigatório), utm_source, utm_medium,
   utm_campaign (textos, obrigatórios; a tríade deve ser única), ativa (booleano,
   padrão verdadeiro).
6. **Lead** — campos: nome, email, telefone (obrigatórios; email válido),
   interesse e mensagem (texto, opcionais), campanha (N:1 com Campanha,
   opcional), utm_term e utm_content (texto, opcionais), consentimento_lgpd
   (booleano, obrigatório, deve ser verdadeiro para salvar via API), status
   (seleção: novo, distribuido, contatado, convertido, perdido, nao_respondeu;
   padrão distribuido), vendedor (texto), distribuido_em, primeiro_contato_em,
   convertido_em (data/hora), base44_sync (booleano), request_id (texto, único).
7. **LogIntegracao** — campos: fluxo (seleção: F1, F2, F3), evento (texto),
   status (seleção: sucesso, aviso, erro), request_id (texto), http_status
   (número), detalhe (texto longo, JSON), criado_em (data/hora automática).

### Papéis e permissões

- **admin**: acesso total a todas as entidades e configurações.
- **gestor**: vê e edita tudo, exceto configurações do app; vê dashboards de SLA
  e funil de leads.
- **atendente**: vê e edita Chamados e Interacoes; vê Clientes e Pedidos
  (somente leitura); não vê Logs nem configurações.
- **leitura** (estagiário/auditoria): somente leitura de Chamados, Leads e
  dashboards; não vê dados brutos de contato (telefone/e-mail) — exibir
  mascarados (ex.: `m***@e***.com`, `***0101`).

### Telas

1. **Chamados (lista)** — filtros por status, prioridade e motivo; colunas:
   protocolo, cliente, motivo, prioridade, SLA restante (calculado: aberto_em +
   sla_horas − agora, em vermelho quando negativo), status, escalado. Ação
   rápida: "Registrar interação".
2. **Chamado (detalhe)** — dados do cliente e do pedido vinculado, linha do
   tempo de Interações (cronológica), botões de mudança de status e flag
   "escalado". Mostrar alerta quando o SLA estourar.
3. **Painel de Leads** — lista com filtros por status, vendedor e utm_source;
   cards de KPI: leads novos (24h), sem primeiro contato, taxa de conversão.
   Ação: "Marcar primeiro contato" (grava primeiro_contato_em).
4. **Painel de SLA** — indicadores por prioridade: total, resolvidos,
   % dentro do SLA, tempo médio de resolução; tabela de chamados vencidos em
   aberto.
5. **Logs de integração** (somente admin/gestor) — lista com filtro por fluxo e
   status, detalhe em JSON.

### Integração

Habilite o acesso por API (REST) a Chamado e Lead para criação externa: os
webhooks do n8n (F1) e o Google Apps Script (F2) gravarão registros via
`X-API-Key`, com o campo `request_id` servindo de chave de idempotência
(não criar duplicado se o request_id já existir — responder o registro
existente).
