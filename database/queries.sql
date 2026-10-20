-- ============================================================================
-- AureaOps — queries.sql (6 consultas que respondem perguntas reais)
-- Execute após schema.sql + seed.sql (ou contra as views).
-- ============================================================================

-- Q1 (SELECT + WHERE + ORDER BY + LIMIT)
-- Pergunta SAC: "quais chamados urgentes devo olhar AGORA?"
-- Chamados não finalizados, prioridade alta, abertos nos últimos 7 dias.
SELECT protocolo, motivo, status, escalado, aberto_em
FROM chamados
WHERE prioridade = 'alta'
  AND status NOT IN ('resolvido', 'cancelado')
  AND aberto_em >= datetime('now', '-7 days')
ORDER BY aberto_em ASC;
-- SLA mais antigo primeiro: o topo da lista é o maior risco.

-- Q2 (JOIN)
-- Pergunta SAC: "mostre o contexto completo dos últimos chamados".
-- Chamado + cliente + pedido na mesma linha (LEFT JOIN: chamado sem
-- pedido vinculado também aparece).
SELECT c.protocolo, cli.nome AS cliente, p.numero_pedido, p.valor_total,
       c.motivo, c.prioridade, c.status, c.aberto_em
FROM chamados c
JOIN clientes cli       ON cli.id = c.cliente_id
LEFT JOIN pedidos p     ON p.id  = c.pedido_id
ORDER BY c.aberto_em DESC
LIMIT 20;

-- Q3 (GROUP BY)
-- Pergunta BI: "onde o SAC gasta mais esforço?"
-- Volume de chamados por motivo e status.
SELECT motivo, status, COUNT(*) AS qtd
FROM chamados
GROUP BY motivo, status
ORDER BY qtd DESC;

-- Q4 (GROUP BY + HAVING)
-- Pergunta Comercial: "quais vendedores têm carteira relevante e como está
-- a taxa de contato?" — só entra na lista quem recebeu 3+ leads.
SELECT vendedor,
       COUNT(*)                                              AS leads_recebidos,
       SUM(CASE WHEN primeiro_contato_em IS NOT NULL
                THEN 1 ELSE 0 END)                           AS leads_contatados,
       ROUND(100.0 * SUM(CASE WHEN primeiro_contato_em IS NOT NULL
                THEN 1 ELSE 0 END) / COUNT(*), 1)            AS pct_contatado
FROM leads
WHERE vendedor IS NOT NULL
GROUP BY vendedor
HAVING COUNT(*) >= 3
ORDER BY pct_contatado DESC;

-- Q5 (subquery correlacionada / NOT EXISTS)
-- Pergunta Comercial: "quais leads distribuídos estão sem NENHUM contato
-- há mais de 24h?" — é a insumo do follow-up D+1/D+3.
SELECT l.id, l.nome, l.vendedor, l.distribuido_em,
       ROUND((julianday('now') - julianday(l.distribuido_em)) * 24, 1) AS horas_sem_contato
FROM leads l
WHERE l.primeiro_contato_em IS NULL
  AND l.status = 'distribuido'
  AND NOT EXISTS (
        SELECT 1 FROM logs_integracao lg
        WHERE lg.fluxo = 'F2'
          AND lg.evento = 'followup_enviado'
          AND lg.request_id = l.request_id
          AND lg.criado_em >= datetime('now', '-1 day')
      )
  AND l.distribuido_em <= datetime('now', '-1 day')
ORDER BY l.distribuido_em ASC;

-- Q6 (função de janela)
-- Pergunta BI/Comercial: "ranking de vendedores por conversão e quanto cada
-- um está acima/abaixo da média geral" — RANK() + AVG() OVER ().
WITH conversao_vendedores AS (
  SELECT vendedor,
         COUNT(*) AS leads,
         SUM(CASE WHEN status = 'convertido' THEN 1 ELSE 0 END) AS convertidos,
         ROUND(100.0 * SUM(CASE WHEN status = 'convertido' THEN 1 ELSE 0 END)
               / COUNT(*), 1) AS pct_conversao
  FROM leads
  WHERE vendedor IS NOT NULL
  GROUP BY vendedor
)
SELECT vendedor, leads, convertidos, pct_conversao,
       RANK() OVER (ORDER BY pct_conversao DESC)                AS ranking,
       ROUND(AVG(pct_conversao) OVER (), 1)                     AS media_geral,
       ROUND(pct_conversao - AVG(pct_conversao) OVER (), 1)     AS desvio_vs_media
FROM conversao_vendedores
ORDER BY ranking;
