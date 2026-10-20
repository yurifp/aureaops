# Base44 — Especificação de entidades (checklist de conferência)

Use este arquivo para conferir o app gerado a partir de `prompt-construcao.md`.
Espelha o modelo relacional de `database/schema.sql` (mesmos nomes e domínios).

| Entidade | Campos obrigatórios | Único | Seleções (domínio fechado) | Relacionamentos |
|---|---|---|---|---|
| Cliente | nome (≥3), email, telefone | email | — | — |
| Pedido | cliente, numero_pedido (PED-9999-9999), valor_total (>0) | numero_pedido | status: pendente, pago, enviado, entregue, cancelado | cliente (N:1) |
| Chamado | cliente, protocolo (SAC-AAAAMMDD-9999), motivo, descricao (≥10), request_id | protocolo, request_id | motivo: troca, atraso, defeito, duvida · prioridade: alta, media, baixa · sla_horas: 4/24/72 · status: aberto, em_atendimento, aguardando_cliente, resolvido, cancelado | cliente (N:1) · pedido (N:1, opcional) |
| Interacao | chamado, mensagem | — | autor: cliente, atendente, sistema · canal: web, whatsapp, email, interno | chamado (N:1, cascata) |
| Campanha | nome, utm_source, utm_medium, utm_campaign | tríade UTM | ativa: booleano | — |
| Lead | nome, email, telefone, consentimento_lgpd (=verdadeiro) | request_id | status: novo, distribuido, contatado, convertido, perdido, nao_respondeu | campanha (N:1, opcional) |
| LogIntegracao | fluxo, evento, status | — | fluxo: F1, F2, F3 · status: sucesso, aviso, erro | — (isolada por decisão de arquitetura) |

## Regras derivadas (validação de negócio)

- `prioridade` e `sla_horas` derivam de `motivo` (defeito→alta/4h, troca→media/24h,
  atraso→media/24h, duvida→baixa/72h). Quem grava via API já envia calculado;
  o app deve recalcular e rejeitar divergência.
- `Chamado.pedido` opcional com `vinculo_pedido_ok=false` quando o pedido não
  localizar — nunca bloquear a abertura por isso.
- `Lead.consentimento_lgpd` falso → a API não cria o registro (erro 400
  `ERRO_VALIDACAO`), alinhado ao JSON Schema de `docs/schemas/`.
- Mascaramento em telas do papel **leitura**: `m***@e***.com` e `***` + 4 últimos
  dígitos do telefone (mesma função usada nos logs de integração).
