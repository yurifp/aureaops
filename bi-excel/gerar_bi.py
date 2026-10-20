#!/usr/bin/env python3
"""AureaOps — gerador da pasta de trabalho de BI (bi-excel/aureaops_bi.xlsx).

Fonte de dados: database/aureaops.db (SQLite) se existir; senão usa um subconjunto
embarcado do seed (mesmos dados fictícios) para que o arquivo seja reprodutível
sem dependências. Também exporta CSVs (bi-excel/dados/) consumidos pelo Power Query.

Abas geradas:
  Chamados / Leads   — dados tabulares (base de fórmulas e do Power Query)
  Auxilio            — tabelas de apoio (motivo→prioridade/SLA) para XLOOKUP
  KPIs               — indicadores calculados POR FÓRMULAS do Excel
  Tabela Dinamica    — matriz motivo × status com CONT.SES + gráficos
  Graficos           — barras (chamados por motivo) e pizza (leads por origem)

Uso:  python bi-excel/gerar_bi.py
"""
import csv
import pathlib
import sqlite3
import sys

from openpyxl import Workbook
from openpyxl.chart import BarChart, PieChart, Reference
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

BASE = pathlib.Path(__file__).resolve().parent
DB = BASE.parent / "database" / "aureaops.db"
DEST_XLSX = BASE / "aureaops_bi.xlsx"
DEST_CSV = BASE / "dados"

# ---------------------------------------------------------------- fallback --
CHAMADOS_FALLBACK = [
    # protocolo, aberto_em, cliente, numero_pedido, motivo, prioridade, sla, status, escalado, resolvido_em
    ("SAC-20261010-0001", "2026-10-10 09:00", "Mariana Duarte", "PED-2026-1001", "defeito", "alta", 4, "resolvido", 0, "2026-10-10 11:00"),
    ("SAC-20261008-0002", "2026-10-08 14:00", "Rafael Nunes", "PED-2026-1002", "defeito", "alta", 4, "resolvido", 1, "2026-10-08 20:00"),
    ("SAC-20261005-0003", "2026-10-05 10:00", "Beatriz Alves", "PED-2026-1003", "troca", "media", 24, "resolvido", 0, "2026-10-05 20:00"),
    ("SAC-20261019-0004", "2026-10-19 02:00", "Carlos Menezes", "PED-2026-1004", "atraso", "media", 24, "em_atendimento", 1, None),
    ("SAC-20261011-0005", "2026-10-11 08:00", "Fernanda Lopes", "PED-2026-1005", "duvida", "baixa", 72, "resolvido", 0, "2026-10-12 14:00"),
    ("SAC-20261019-0006", "2026-10-19 20:00", "Gustavo Pereira", "PED-2026-1006", "troca", "media", 24, "aguardando_cliente", 0, None),
    ("SAC-20261020-0007", "2026-10-20 08:30", "Heloisa Martins", "PED-2026-1007", "defeito", "alta", 4, "aberto", 0, None),
    ("SAC-20261016-0008", "2026-10-16 07:00", "Thiago Barbosa", "", "duvida", "baixa", 72, "em_atendimento", 1, None),
    ("SAC-20261001-0009", "2026-10-01 09:00", "Mariana Duarte", "PED-2026-1009", "atraso", "media", 24, "resolvido", 0, "2026-10-02 15:00"),
    ("SAC-20261014-0010", "2026-10-14 12:00", "Beatriz Alves", "PED-2026-1010", "defeito", "alta", 4, "cancelado", 0, None),
]
LEADS_FALLBACK = [
    # protocolo, created_at, origem, status, vendedor, primeiro_contato_em, convertido_em
    ("LED-20261005-0001", "2026-10-05 09:04", "instagram", "convertido", "Ana Souza", "2026-10-05 10:30", "2026-10-06 15:00"),
    ("LED-20261005-0002", "2026-10-05 11:09", "google", "convertido", "Bruno Lima", "2026-10-05 14:00", "2026-10-07 09:30"),
    ("LED-20261006-0003", "2026-10-06 10:19", "instagram", "contatado", "Carla Dias", "2026-10-06 11:00", None),
    ("LED-20261006-0004", "2026-10-06 15:35", "google", "perdido", "Diego Alves", "2026-10-07 09:00", None),
    ("LED-20261008-0005", "2026-10-08 08:44", "newsletter", "contatado", "Ana Souza", "2026-10-08 09:10", None),
    ("LED-20261009-0006", "2026-10-09 13:59", "newsletter", "nao_respondeu", "Bruno Lima", "2026-10-12 10:00", None),
    ("LED-20261010-0007", "2026-10-10 09:30", "indicacao", "convertido", "Carla Dias", "2026-10-10 10:15", "2026-10-11 16:20"),
    ("LED-20261011-0008", "2026-10-11 16:50", "google", "perdido", "Diego Alves", "2026-10-12 09:00", None),
    ("LED-20261013-0009", "2026-10-13 10:09", "instagram", "contatado", "Ana Souza", "2026-10-13 10:40", None),
    ("LED-20261014-0010", "2026-10-14 09:19", "google", "nao_respondeu", "Bruno Lima", "2026-10-17 11:00", None),
    ("LED-20261015-0011", "2026-10-15 12:59", "instagram", "convertido", "Carla Dias", "2026-10-15 13:30", "2026-10-16 10:00"),
    ("LED-20261016-0012", "2026-10-16 17:40", "newsletter", "nao_respondeu", "Diego Alves", "2026-10-19 09:00", None),
    ("LED-20261018-0013", "2026-10-18 09:14", "google", "contatado", "Ana Souza", "2026-10-18 09:45", None),
    ("LED-20261018-0014", "2026-10-18 18:04", "instagram", "distribuido", "Bruno Lima", None, None),
    ("LED-20261019-0015", "2026-10-19 08:29", "newsletter", "distribuido", "Carla Dias", None, None),
    ("LED-20261020-0016", "2026-10-20 07:50", "indicacao", "novo", "", None, None),
]

MOTIVOS = ["troca", "atraso", "defeito", "duvida"]
STATUS_CHAMADO = ["aberto", "em_atendimento", "aguardando_cliente", "resolvido", "cancelado"]
ORIGENS = ["instagram", "google", "newsletter", "indicacao", "direto"]


def carregar_dados():
    """Lê do SQLite quando disponível; senão usa o fallback embarcado."""
    chamados, leads = [], []
    if DB.exists():
        con = sqlite3.connect(DB)
        con.row_factory = sqlite3.Row
        for r in con.execute(
            "SELECT c.protocolo, c.aberto_em, cli.nome cliente, p.numero_pedido, c.motivo,"
            "       c.prioridade, c.sla_horas, c.status, c.escalado, c.resolvido_em"
            " FROM chamados c JOIN clientes cli ON cli.id=c.cliente_id"
            " LEFT JOIN pedidos p ON p.id=c.pedido_id ORDER BY c.aberto_em"
        ):
            chamados.append(tuple(r))
        for r in con.execute(
            "SELECT ('LED-' || l.id) protocolo, l.created_at, COALESCE(ca.utm_source,'direto') origem, l.status,"
            "       COALESCE(l.vendedor,'') vendedor, l.primeiro_contato_em, l.convertido_em"
            " FROM leads l LEFT JOIN campanhas ca ON ca.id=l.campanha_id ORDER BY l.created_at"
        ):
            leads.append(tuple(r))
        con.close()
        print(f"[fonte] SQLite: {len(chamados)} chamados, {len(leads)} leads")
    else:
        chamados, leads = CHAMADOS_FALLBACK, LEADS_FALLBACK
        print("[fonte] SQLite ausente — usando fallback embarcado (seed)")
    return chamados, leads


def horas_entre(inicio, fim):
    if not inicio or not fim:
        return None
    from datetime import datetime

    fmt = "%Y-%m-%d %H:%M"
    try:
        d1, d2 = datetime.strptime(str(inicio)[:16], fmt), datetime.strptime(str(fim)[:16], fmt)
        return round((d2 - d1).total_seconds() / 3600, 1)
    except ValueError:
        return None


def exportar_csvs(chamados, leads):
    DEST_CSV.mkdir(parents=True, exist_ok=True)
    with open(DEST_CSV / "chamados.csv", "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["protocolo", "aberto_em", "cliente", "numero_pedido", "motivo",
                    "prioridade", "sla_horas", "status", "escalado", "resolvido_em",
                    "horas_resolucao", "cumpriu_sla"])
        for c in chamados:
            hr = horas_entre(c[1], c[9])
            w.writerow(list(c) + [hr, int(hr is not None and hr <= c[6])])
    with open(DEST_CSV / "leads.csv", "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["protocolo", "created_at", "origem", "status", "vendedor",
                    "primeiro_contato_em", "convertido_em", "horas_ate_contato", "convertido"])
        for l in leads:
            hc = horas_entre(l[1], l[5])
            w.writerow(list(l) + [hc, int(l[6] is not None)])


# ------------------------------------------------------------------- estilos --
TITULO = Font(bold=True, size=13, color="2B2620")
CABECALHO = Font(bold=True, color="FFFFFF")
FUNDO_CABECALHO = PatternFill("solid", fgColor="5C5348")
BORDA = Border(bottom=Side(style="thin", color="D9D2C7"))


def cabecalho(ws, linha, valores):
    for col, valor in enumerate(valores, 1):
        celula = ws.cell(row=linha, column=col, value=valor)
        celula.font = CABECALHO
        celula.fill = FUNDO_CABECALHO
    ws.freeze_panes = ws.cell(row=linha + 1, column=1)


def principal():
    chamados, leads = carregar_dados()
    exportar_csvs(chamados, leads)

    wb = Workbook()

    # ---------------------------------------------------------------- Chamados
    ws = wb.active
    ws.title = "Chamados"
    cabecalho(ws, 1, ["protocolo", "aberto_em", "cliente", "numero_pedido", "motivo",
                      "prioridade", "sla_horas", "status", "escalado", "resolvido_em",
                      "horas_resolucao", "cumpriu_sla"])
    for i, c in enumerate(chamados, 2):
        hr = horas_entre(c[1], c[9])
        ws.append(list(c) + [hr, int(hr is not None and hr <= c[6])])
    n_chamados = len(chamados) + 1
    for col, larg in zip("ABCDEFGHIJKL", [18, 17, 18, 15, 9, 10, 9, 18, 9, 17, 14, 11]):
        ws.column_dimensions[col].width = larg
    ws.conditional_formatting.add(
        f"I2:I{n_chamados}",
        CellIsRule(operator="equal", formula=["1"],
                   fill=PatternFill("solid", fgColor="FDECEB"), font=Font(color="A3271F", bold=True)))

    # ------------------------------------------------------------------ Leads
    ws = wb.create_sheet("Leads")
    cabecalho(ws, 1, ["protocolo", "created_at", "origem", "status", "vendedor",
                      "primeiro_contato_em", "convertido_em", "horas_ate_contato", "convertido"])
    for l in leads:
        hc = horas_entre(l[1], l[5])
        ws.append(list(l) + [hc, int(l[6] is not None)])
    n_leads = len(leads) + 1
    for col, larg in zip("ABCDEFGHI", [18, 17, 12, 14, 14, 19, 17, 17, 11]):
        ws.column_dimensions[col].width = larg

    # --------------------------------------------------------------- Auxilio
    ws = wb.create_sheet("Auxilio")
    ws["A1"] = "Motivo → prioridade/SLA (base do XLOOKUP em KPIs)"
    ws["A1"].font = TITULO
    cabecalho(ws, 3, ["motivo", "prioridade", "sla_horas"])
    for i, m in enumerate(MOTIVOS, 4):
        mapa = {"troca": ("media", 24), "atraso": ("media", 24),
                "defeito": ("alta", 4), "duvida": ("baixa", 72)}[m]
        ws.append([m, mapa[0], mapa[1]])
    dv = DataValidation(type="list", formula1='"' + ",".join(MOTIVOS) + '"', allow_blank=False)
    dv.error = "Escolha um motivo da lista."
    dv.prompt = "Motivo válido do domínio do sistema."
    ws.add_data_validation(dv)
    dv.add("A12")  # célula de teste da validação de dados
    ws["A11"] = "Teste de validação (dropdown):"
    ws["A11"].font = Font(bold=True)

    # ------------------------------------------------------------------- KPIs
    ws = wb.create_sheet("KPIs")
    ws["A1"] = "KPIs AureaOps (calculados por fórmulas — nenhum valor é 'colado')"
    ws["A1"].font = TITULO
    linhas = [
        # (rótulo, fórmula em inglês — o Excel exibe traduzido em pt-BR, formato)
        ("Chamados — total", f"=COUNTA(Chamados!A2:A{n_chamados})", "0"),
        ("Chamados — resolvidos", f'=COUNTIF(Chamados!H2:H{n_chamados},"resolvido")', "0"),
        ("Chamados — em aberto (não finalizados)",
         f'=COUNTA(Chamados!A2:A{n_chamados})-COUNTIF(Chamados!H2:H{n_chamados},"resolvido")'
         f'-COUNTIF(Chamados!H2:H{n_chamados},"cancelado")', "0"),
        ("SLA — % cumprido (entre resolvidos)",
         f'=IFERROR(COUNTIFS(Chamados!H2:H{n_chamados},"resolvido",Chamados!L2:L{n_chamados},1)'
         f'/COUNTIF(Chamados!H2:H{n_chamados},"resolvido"),"")', "0.0%"),
        ("SLA — tempo médio de resolução (h)",
         f"=IFERROR(AVERAGE(Chamados!K2:K{n_chamados}),\"\")", "0.0"),
        ("SLA — chamados escalonados", f"=SUM(Chamados!I2:I{n_chamados})", "0"),
        ("Leads — total", f"=COUNTA(Leads!A2:A{n_leads})", "0"),
        ("Leads — convertidos", f'=COUNTIF(Leads!D2:D{n_leads},"convertido")', "0"),
        ("Leads — taxa de conversão", '=IFERROR(B11/B10,"")', "0.0%"),
        ("Leads — sem primeiro contato", f'=COUNTIF(Leads!D2:D{n_leads},"distribuido")', "0"),
        ("Leads — tempo médio até 1º contato (h)", f'=IFERROR(AVERAGE(Leads!H2:H{n_leads}),"")', "0.0"),
        ("XLOOKUP — SLA do motivo selecionado em Auxilio!A12",
         '=IFERROR(XLOOKUP(Auxilio!A12,Auxilio!A4:A7,Auxilio!C4:C7),"—")', "0"),
    ]
    cabecalho(ws, 3, ["Indicador", "Valor", "Como se calcula"])
    explicacoes = [
        "CONT.VALORES na coluna de protocolos", "CONT.SES por status",
        "total − resolvidos − cancelados", "CONT.SES(resolvido E cumpriu_sla=1)/CONT.SE(resolvido)",
        "MÉDIA das horas de resolução", "SOMA da coluna escalado",
        "CONT.VALORES dos protocolos", "CONT.SES status=convertido",
        "convertidos / total", "CONT.SES status=distribuido",
        "MÉDIA das horas até primeiro contato",
        "PROCV moderno: busca sla_horas do motivo escolhido no dropdown",
    ]
    for i, ((rotulo, formula, fmt), expl) in enumerate(zip(linhas, explicacoes), 4):
        ws.cell(row=i, column=1, value=rotulo)
        c = ws.cell(row=i, column=2, value=formula)
        c.number_format = fmt
        ws.cell(row=i, column=3, value=expl)
    ws.conditional_formatting.add(
        "B7", CellIsRule(operator="lessThan", formula=["0.9"],
                         fill=PatternFill("solid", fgColor="FDECEB"), font=Font(color="A3271F", bold=True)))
    ws.conditional_formatting.add(
        "B7", CellIsRule(operator="greaterThanOrEqual", formula=["0.9"],
                         fill=PatternFill("solid", fgColor="E8F5EC"), font=Font(color="1E6B34", bold=True)))
    ws.column_dimensions["A"].width = 46
    ws.column_dimensions["B"].width = 12
    ws.column_dimensions["C"].width = 44

    # -------------------------------------------------------- Tabela Dinamica
    ws = wb.create_sheet("Tabela Dinamica")
    ws["A1"] = "Chamados por motivo × status (CONT.SES — matriz estilo tabela dinâmica)"
    ws["A1"].font = TITULO
    ws["A3"] = "motivo \\ status"
    ws["A3"].font = Font(bold=True)
    for j, st in enumerate(STATUS_CHAMADO, 2):
        ws.cell(row=3, column=j, value=st).font = Font(bold=True)
    for i, m in enumerate(MOTIVOS, 4):
        ws.cell(row=i, column=1, value=m)
        for j in range(2, 2 + len(STATUS_CHAMADO)):
            col = get_column_letter(j)
            ws.cell(row=i, column=j, value=(
                f'=COUNTIFS(Chamados!E2:E{n_chamados},$A{i},'
                f'Chamados!H2:H{n_chamados},{col}$3)'))
    ws.cell(row=9, column=1, value="total").font = Font(bold=True)
    for j in range(2, 2 + len(STATUS_CHAMADO)):
        letra = get_column_letter(j)
        ws.cell(row=9, column=j, value=f"=SUM({letra}4:{letra}8)").font = Font(bold=True)
    ws["A11"] = ("Pivot nativa em 3 cliques: selecione A1:L"
                 f"{n_chamados} em 'Chamados' → Inserir → Tabela Dinâmica "
                 "(linhas: motivo; colunas: status; valores: contagem).")
    ws["A11"].font = Font(italic=True, color="5C5348")

    ws["A13"] = "Leads por origem"
    ws["A13"].font = TITULO
    ws["A14"], ws["B14"] = "origem", "leads"
    ws["A14"].font = ws["B14"].font = Font(bold=True)
    for i, o in enumerate(ORIGENS, 15):
        ws.cell(row=i, column=1, value=o)
        ws.cell(row=i, column=2, value=f'=COUNTIF(Leads!C2:C{n_leads},A{i})')

    # ---------------------------------------------------------------- Graficos
    ws = wb.create_sheet("Graficos")
    ws["A1"] = "Gráficos (vinculados às matrizes da aba Tabela Dinamica)"
    ws["A1"].font = TITULO

    barra = BarChart()
    barra.title = "Chamados por motivo"
    barra.type = "col"
    dados = Reference(wb["Tabela Dinamica"], min_col=7, min_row=3, max_col=7, max_row=8)
    rotulos = Reference(wb["Tabela Dinamica"], min_col=1, min_row=4, max_row=8)
    barra.add_data(dados, titles_from_data=True)
    barra.set_categories(rotulos)
    barra.height, barra.width = 8, 14
    ws.add_chart(barra, "A3")

    pizza = PieChart()
    pizza.title = "Leads por origem"
    dados = Reference(wb["Tabela Dinamica"], min_col=2, min_row=14, max_row=19)
    rotulos = Reference(wb["Tabela Dinamica"], min_col=1, min_row=15, max_row=19)
    pizza.add_data(dados, titles_from_data=True)
    pizza.set_categories(rotulos)
    pizza.height, pizza.width = 8, 12
    ws.add_chart(pizza, "J3")

    wb.save(DEST_XLSX)
    print(f"[ok] {DEST_XLSX} gerado")
    print(f"[ok] CSVs em {DEST_CSV} (base do Power Query)")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
