# AureaOps — Fórmulas do Excel usadas no BI

Os arquivos são gravados com nomes em **inglês** (padrão interno do Excel); o
Excel em português exibe e aceita os nomes locais automaticamente. A coluna
"pt-BR" é o que você digita numa instalação em português.

| Onde | En (como está no arquivo) | pt-BR (como se digita) | O que faz |
|---|---|---|---|
| KPIs!B4 | `=COUNTA(Chamados!A2:A11)` | `=CONT.VALORES(Chamados!A2:A11)` | Total de chamados (conta protocolos). |
| KPIs!B5 | `=COUNTIF(Chamados!H:H,"resolvido")` | `=CONT.SE(Chamados!H:H;"resolvido")` | Chamados resolvidos. |
| KPIs!B7 | `=COUNTIFS(Chamados!H:H,"resolvido",Chamados!L:L,1)/COUNTIF(Chamados!H:H,"resolvido")` | `=CONT.SES(...)/CONT.SE(...)` | **% SLA cumprido**: resolvidos que fecharam dentro do SLA ÷ resolvidos. Formato 0,0%. Formatação condicional: vermelho < 90%, verde ≥ 90%. |
| KPIs!B8 | `=AVERAGE(Chamados!K:K)` | `=MÉDIA(Chamados!K:K)` | Tempo médio de resolução (h) — ignora vazios automaticamente. |
| KPIs!B9 | `=SUM(Chamados!I:I)` | `=SOMA(Chamados!I:I)` | Total de chamados escalonados ao gestor. |
| KPIs!B10 | `=COUNTA(Leads!A:A)` | `=CONT.VALORES(Leads!A:A)` | Total de leads. |
| KPIs!B12 | `=IFERROR(B11/B10,"")` | `=SEERRO(B11/B10;"")` | Taxa de conversão com guarda contra divisão por zero. |
| KPIs!B15 | `=XLOOKUP(Auxilio!A12,Auxilio!A4:A7,Auxilio!C4:C7)` | `=PROCX(...)` | **XLOOKUP**: busca o SLA do motivo escolhido no dropdown de validação de dados. Substitui PROCV sem precisar de coluna ordenada nem índice numérico. |
| Tabela Dinamica!B4:G8 | `=COUNTIFS(Chamados!E:E,$A4,Chamados!H:H,B$3)` | `=CONT.SES(...)` | Matriz motivo × status (referências travadas com `$` para arrastar). |
| Tabela Dinamica!B9 | `=SUM(B4:B8)` | `=SOMA(B4:B8)` | Totais por coluna da matriz. |

## SOMASES — por que não usei (e quando usaria)

`SUMIFS`/`SOMASES` soma valores sob condições. Aqui os indicadores são
contagens (`COUNTIFS`), então SOMASES aparece quando o KPI vira **dinheiro ou
tempo total**, por exemplo (em `admin-ti/licencas.xlsx`):

`=SUMIFS(TabelaCotacao[Pontuacao ponderada];TabelaCotacao[Fornecedor];"Fornecedor A")`

e a pontuação ponderada da cotação é um `SUMPRODUCT`/`SOMARPRODUTO`
(pesos × notas) — ver `admin-ti/gerar_admin.py`.

## Validação de dados e formatação condicional

- **Validação (dropdown):** `Auxilio!A12` aceita só `troca, atraso, defeito,
  duvida` — mesma técnica usada nos status em `admin-ti`. Impede digitação
  fora do domínio na origem, antes de virar dado sujo no BI.
- **Formatação condicional:** `Chamados!I` pinta "escalado=1" de vermelho;
  `KPIs!B7` (% SLA) fica vermelho < 90% e verde ≥ 90%. Regra de gestão:
  abaixo de 90% o gestor já recebeu alerta — a cor conta a mesma história.

## Pivot nativa (quando preferir à matriz de fórmulas)

Aba `Tabela Dinamica`, célula A11, tem o atalho: selecionar os dados em
`Chamados` → Inserir → Tabela Dinâmica (linhas: motivo; colunas: status;
valores: contagem). A matriz de CONT.SES foi mantida porque recalcula em
qualquer Excel (inclusive web antigo) e fica versionável no Git.
