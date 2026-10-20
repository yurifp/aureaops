-- ============================================================================
-- AureaOps — views.sql (3 views de BI)
-- Portabilidade: funções usadas (julianday, strftime, round) existem no SQLite;
-- em PostgreSQL, trocar julianday(x) por EXTRACT(EPOCH FROM x)/86400.
-- ============================================================================

-- V1: chamados enriquecidos para qualquer painel/relatório.
--     Contatos mascarados por padrão (LGPD): a view é a "camada de exibição".
CREATE VIEW vw_chamados_detalhe AS
SELECT
  c.id                                AS chamado_id,
  c.protocolo,
  c.motivo,
  c.prioridade,
  c.status,
  c.escalado,
  c.sla_horas,
  c.aberto_em,
  c.primeira_resposta_em,
  c.resolvido_em,
  cli.nome                            AS cliente_nome,
  substr(cli.email, 1, instr(cli.email,'@')) || '***' AS cliente_email_mascarado,
  '***' || substr(cli.telefone, -4)   AS cliente_telefone_mascarado,
  p.numero_pedido,
  p.valor_total                       AS pedido_valor,
  ROUND((julianday(c.primeira_resposta_em) - julianday(c.aberto_em)) * 24, 1)
                                      AS horas_ate_primeira_resposta,
  ROUND((julianday(c.resolvido_em)    - julianday(c.aberto_em)) * 24, 1)
                                      AS horas_ate_resolucao,
  CASE
    WHEN c.resolvido_em IS NULL THEN NULL
    WHEN (julianday(c.resolvido_em) - julianday(c.aberto_em)) * 24 <= c.sla_horas
      THEN 1 ELSE 0
  END                                 AS cumpriu_sla
FROM chamados c
JOIN clientes cli ON cli.id = c.cliente_id
LEFT JOIN pedidos p ON p.id = c.pedido_id;

-- V2: resumo de SLA por prioridade (alimenta o painel de SLA do Base44 e o BI).
CREATE VIEW vw_sla_resumo AS
SELECT
  prioridade,
  sla_horas,
  COUNT(*)                                            AS total_chamados,
  SUM(CASE WHEN status = 'resolvido' THEN 1 ELSE 0 END) AS resolvidos,
  SUM(cumpriu_sla)                                    AS resolvidos_no_prazo,
  ROUND(100.0 * SUM(cumpriu_sla)
        / NULLIF(SUM(CASE WHEN status = 'resolvido' THEN 1 ELSE 0 END), 0), 1)
                                                      AS pct_sla_cumprido,
  ROUND(AVG(horas_ate_resolucao), 1)                  AS tempo_medio_resolucao_h
FROM vw_chamados_detalhe
GROUP BY prioridade, sla_horas;

-- V3: funil de leads por origem UTM (Comercial + Marketing).
CREATE VIEW vw_funil_leads AS
SELECT
  ca.utm_source,
  ca.utm_medium,
  ca.utm_campaign,
  COUNT(*)                                            AS total_leads,
  SUM(CASE WHEN l.status IN ('contatado','convertido','perdido','nao_respondeu')
           THEN 1 ELSE 0 END)                         AS contatados,
  SUM(CASE WHEN l.status = 'convertido' THEN 1 ELSE 0 END) AS convertidos,
  ROUND(100.0 * SUM(CASE WHEN l.status = 'convertido' THEN 1 ELSE 0 END)
        / COUNT(*), 1)                                AS pct_conversao,
  ROUND(AVG((julianday(l.primeiro_contato_em) - julianday(l.created_at)) * 24), 1)
                                                      AS horas_ate_primeiro_contato
FROM leads l
LEFT JOIN campanhas ca ON ca.id = l.campanha_id
GROUP BY ca.utm_source, ca.utm_medium, ca.utm_campaign;
