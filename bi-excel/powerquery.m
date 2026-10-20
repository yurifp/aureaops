// ============================================================================
// AureaOps — Power Query (linguagem M)
// Objetivo: carregar os CSVs exportados por gerar_bi.py (bi-excel/dados/),
// tipar as colunas e criar uma consulta combinada "bi_chamados_leads" pronta
// para tabela dinâmica e Power Pivot.
//
// Como aplicar (TODO(manual) — Excel desktop M365):
//   1. Dados → Obter Dados → De Outras Fontes → Consulta em Branco.
//   2. Editor do Power Query → Editor Avançado → cole o bloco correspondente.
//   3. Ajuste CAMINHO para a pasta dados/ do seu clone do repositório.
//   4. Fechar e Carregar — os dados atualizam com um clique em "Atualizar Tudo"
//      (basta rodar `python bi-excel/gerar_bi.py` antes para regenerar os CSVs).
// ============================================================================

// ---------------------------------------------------------------- Consulta 1
// "pq_chamados" — carga e tipagem dos chamados
let
    CAMINHO = "C:\aureaops\bi-excel\dados",
    Fonte = Csv.Document(File.Contents(CAMINHO & "\chamados.csv"),
        [Delimiter = ",", Encoding = 65001]), // UTF-8 com BOM
    Cabecalho = Table.PromoteHeaders(Fonte, [PromoteAllScalars = true]),
    Tipado = Table.TransformColumnTypes(Cabecalho, {
        {"protocolo", type text},
        {"aberto_em", type datetime},
        {"cliente", type text},
        {"numero_pedido", type text},
        {"motivo", type text},
        {"prioridade", type text},
        {"sla_horas", Int64.Type},
        {"status", type text},
        {"escalado", Int64.Type},
        {"resolvido_em", type datetime nullable},
        {"horas_resolucao", type number nullable},
        {"cumpriu_sla", Int64.Type}
    }),
    // Coluna calculada: classificação do SLA (mesma regra do painel Base44)
    ComClassificacao = Table.AddColumn(Tipado, "classificacao_sla", each
        if [status] = "resolvido" then
            (if [cumpriu_sla] = 1 then "no_prazo" else "atrasado")
        else if [escalado] = 1 then "escalado" else "aguardando",
        type text)
in
    ComClassificacao

// ---------------------------------------------------------------- Consulta 2
// "pq_leads" — carga e tipagem dos leads
let
    CAMINHO = "C:\aureaops\bi-excel\dados",
    Fonte = Csv.Document(File.Contents(CAMINHO & "\leads.csv"),
        [Delimiter = ",", Encoding = 65001]),
    Cabecalho = Table.PromoteHeaders(Fonte, [PromoteAllScalars = true]),
    Tipado = Table.TransformColumnTypes(Cabecalho, {
        {"protocolo", type text},
        {"created_at", type datetime},
        {"origem", type text},
        {"status", type text},
        {"vendedor", type text},
        {"primeiro_contato_em", type datetime nullable},
        {"convertido_em", type datetime nullable},
        {"horas_ate_contato", type number nullable},
        {"convertido", Int64.Type}
    })
in
    Tipado

// ---------------------------------------------------------------- Consulta 3
// "bi_resumo_diario" — agregação estilo BI (volumes por dia e tipo) para
// alimentar o resumo do F3 com um "Atualizar Tudo" no Excel, se desejado.
let
    Chamados = pq_chamados,
    ComData = Table.AddColumn(Chamados, "data", each Date.From([aberto_em]), type date),
    PorDia = Table.Group(ComData, {"data"}, {
        {"chamados", each Table.RowCount(_), Int64.Type},
        {"resolvidos_no_prazo", each List.Sum([cumpriu_sla]), Int64.Type}
    })
in
    PorDia
