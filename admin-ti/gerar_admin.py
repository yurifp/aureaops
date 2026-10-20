#!/usr/bin/env python3
"""AureaOps — módulo administrativo de TI (3 pastas de trabalho Excel).

Gera em admin-ti/:
  licencas.xlsx       — controle de licenças com alerta de vencimento
                        (dias_para_renovar = data_renovacao - HOJE(), formatação
                        condicional: vermelho vencido, amarelo ≤ 30 dias)
  cotacao.xlsx        — cotação comparativa com 3 fornecedores e pontuação
                        ponderada (SOMARPRODUTO pesos × notas 1–5 com validação
                        de dados; vencedor via PROCX)
  matriz-acessos.xlsx — matriz RBAC por pessoa × sistema + checklists de
                        onboarding/offboarding

Uso:  python admin-ti/gerar_admin.py   (requer openpyxl)
"""
import pathlib
import sys
from datetime import date

from openpyxl import Workbook
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation

BASE = pathlib.Path(__file__).resolve().parent

TITULO = Font(bold=True, size=13, color="2B2620")
CABECALHO = Font(bold=True, color="FFFFFF")
FUNDO_CAB = PatternFill("solid", fgColor="5C5348")
VERMELHO = PatternFill("solid", fgColor="FDECEB")
AMARELO = PatternFill("solid", fgColor="FFF3D6")
VERDE = PatternFill("solid", fgColor="E8F5EC")


def cabecalho(ws, linha, valores):
    for col, valor in enumerate(valores, 1):
        c = ws.cell(row=linha, column=col, value=valor)
        c.font = CABECALHO
        c.fill = FUNDO_CAB
    ws.freeze_panes = ws.cell(row=linha + 1, column=1)


def larguras(ws, tamanhos):
    from openpyxl.utils import get_column_letter

    for i, larg in enumerate(tamanhos, 1):
        ws.column_dimensions[get_column_letter(i)].width = larg


# ============================================================ licencas.xlsx ==
def gerar_licencas():
    wb = Workbook()
    ws = wb.active
    ws.title = "Licencas"
    ws["A1"] = "Controle de licenças — AureaOps (valores fictícios, revisar TODO(manual))"
    ws["A1"].font = TITULO

    colunas = ["ferramenta", "categoria", "fornecedor", "tipo_cobranca",
               "qtd_licencas", "custo_unitario_mes_brl", "custo_total_mes_brl",
               "responsavel", "centro_custo", "data_aquisicao", "data_renovacao",
               "dias_para_renovar", "status", "observacoes"]
    cabecalho(ws, 3, colunas)

    licencas = [
        # ferramenta, categoria, fornecedor, cobrança, qtd, custo unit., resp., cc, aquisição, renovação, status, obs
        ("Google Workspace", "Produtividade", "Google", "por usuário/mês", 6, 42.00,
         "Fabiana TI", "ADM", date(2026, 1, 10), date(2027, 1, 10), "ativa", "E-mail/Drive/Sheets do time"),
        ("n8n Cloud (starter)", "Automação", "n8n", "plano/mês", 1, 89.00,
         "Fabiana TI", "TEC", date(2026, 8, 1), date(2026, 11, 1), "ativa", "Homologação (produção roda local via npm)"),
        ("Base44 (plano free)", "Low-code", "Base44", "grátis", 1, 0.00,
         "Fabiana TI", "TEC", date(2026, 9, 15), date(2027, 9, 15), "ativa", "App interno AureaOps"),
        ("Postman (free)", "APIs", "Postman", "grátis", 1, 0.00,
         "Fabiana TI", "TEC", date(2026, 9, 20), date(2027, 9, 20), "ativa", "Testes de contrato"),
        ("WhatsApp Cloud API", "Mensageria", "Meta", "por conversa", 1, 0.00,
         "Renato Gestor", "COM", date(2026, 10, 5), date(2026, 11, 5), "em_avaliacao", "MODO=simulado até aprovar templates"),
        ("Microsoft 365 Pessoal", "BI/Excel", "Microsoft", "por usuário/mês", 2, 35.00,
         "Fabiana TI", "ADM", date(2026, 2, 20), date(2026, 11, 20), "ativa", "Power Query/tabela dinâmica"),
        ("Ferramenta legada XPTO", "Automação", "XPTO", "anual", 1, 2500.00,
         "Fabiana TI", "TEC", date(2024, 3, 1), date(2026, 10, 25), "vencida", "Candidata a cancelamento (substituída pelo n8n)"),
    ]
    for i, lic in enumerate(licencas, 4):
        ws.cell(row=i, column=1, value=lic[0])
        ws.cell(row=i, column=2, value=lic[1])
        ws.cell(row=i, column=3, value=lic[2])
        ws.cell(row=i, column=4, value=lic[3])
        ws.cell(row=i, column=5, value=lic[4])
        ws.cell(row=i, column=6, value=lic[5]).number_format = "R$ #,##0.00"
        ws.cell(row=i, column=7, value=f"=E{i}*F{i}").number_format = "R$ #,##0.00"
        ws.cell(row=i, column=8, value=lic[6])
        ws.cell(row=i, column=9, value=lic[7])
        ws.cell(row=i, column=10, value=lic[8]).number_format = "DD/MM/YYYY"
        ws.cell(row=i, column=11, value=lic[9]).number_format = "DD/MM/YYYY"
        ws.cell(row=i, column=12, value=f"=K{i}-TODAY()")
        ws.cell(row=i, column=13, value=lic[10])
        ws.cell(row=i, column=14, value=lic[11])

    fim = 3 + len(licencas)
    ws.cell(row=fim + 1, column=7, value=f"=SUM(G4:G{fim})").number_format = "R$ #,##0.00"
    ws.cell(row=fim + 1, column=6, value="Custo total/mês →").font = Font(bold=True)

    # Alerta de vencimento: vermelho < 0 (vencido), amarelo 0–30, verde > 30
    ws.conditional_formatting.add(
        f"L4:L{fim}", CellIsRule(operator="lessThan", formula=["0"],
                                 fill=VERMELHO, font=Font(color="A3271F", bold=True)))
    ws.conditional_formatting.add(
        f"L4:L{fim}", CellIsRule(operator="lessThanOrEqual", formula=["30"], fill=AMARELO))
    ws.conditional_formatting.add(
        f"L4:L{fim}", CellIsRule(operator="greaterThan", formula=["30"], fill=VERDE))

    dv = DataValidation(type="list", formula1='"ativa,cancelada,em_avaliacao,vencida"')
    dv.error = "Status inválido."
    ws.add_data_validation(dv)
    dv.add(f"M4:M{fim + 10}")

    larguras(ws, [24, 14, 12, 16, 8, 12, 12, 12, 10, 13, 13, 10, 13, 40])
    wb.save(BASE / "licencas.xlsx")
    print("[ok] licencas.xlsx")


# ============================================================ cotacao.xlsx ===
def gerar_cotacao():
    wb = Workbook()

    ws = wb.active
    ws.title = "Criterios"
    ws["A1"] = "Cotação comparativa — plataforma de automação (objetivo do projeto)"
    ws["A1"].font = TITULO
    cabecalho(ws, 3, ["criterio", "peso", "justificativa"])
    criterios = [
        ("Custo total (12 meses)", 0.30, "Orçamento do MVP é o principal limite."),
        ("Facilidade de aprendizado", 0.20, "Time pequeno, sem dedicação exclusiva à ferramenta."),
        ("Integrações nativas/APIs", 0.25, "Google Workspace, WhatsApp Cloud API e REST genérico."),
        ("Versionamento/exportação", 0.15, "Fluxos precisam morar no Git (auditoria do projeto)."),
        ("Suporte e comunidade", 0.10, "Resolução de dúvidas em português/inglês."),
    ]
    for i, (c, p, j) in enumerate(criterios, 4):
        ws.cell(row=i, column=1, value=c)
        ws.cell(row=i, column=2, value=p).number_format = "0%"
        ws.cell(row=i, column=3, value=j)
    ws.cell(row=9, column=1, value="SOMA dos pesos (deve dar 100%)").font = Font(bold=True)
    ws.cell(row=9, column=2, value="=SUM(B4:B8)").number_format = "0%"
    dv_peso = DataValidation(type="decimal", operator="between", formula1="0", formula2="1")
    ws.add_data_validation(dv_peso)
    dv_peso.add("B4:B8")
    larguras(ws, [30, 8, 60])

    ws = wb.create_sheet("Cotacao")
    ws["A1"] = "Notas 1 (péssimo) a 5 (excelente) — preencha e a ponderação recalcula"
    ws["A1"].font = TITULO
    fornecedores = ["n8n Cloud", "Make", "Power Automate"]
    cabecalho(ws, 3, ["criterio", "peso"] + fornecedores + ["peso × nota máxima"])
    for i, (c, p, _) in enumerate(criterios, 4):
        ws.cell(row=i, column=1, value=c)
        ws.cell(row=i, column=2, value=f"=Criterios!B{i}").number_format = "0%"
        # Notas iniciais da avaliação documentada em docs/comparativo-ferramentas.md
        for col, nota in zip((3, 4, 5), (4, 3, 3)):
            ws.cell(row=i, column=col, value=nota)
    ws.cell(row=9, column=1, value="Pontuação ponderada (SOMARPRODUTO)").font = Font(bold=True)
    for col in (3, 4, 5):
        letra = chr(ord("A") + col - 1)
        ws.cell(row=9, column=col,
                value=f"=SUMPRODUCT($B$4:$B$8,{letra}4:{letra}8)").number_format = "0.00"
    ws.cell(row=10, column=1, value="Ranking").font = Font(bold=True)
    for col in (3, 4, 5):
        letra = chr(ord("A") + col - 1)
        ws.cell(row=10, column=col, value=f"=RANK({letra}9,$C$9:$E$9)")
    ws.cell(row=12, column=1, value="Vencedor (PROCX pela maior pontuação)").font = Font(bold=True)
    ws.cell(row=12, column=3, value='=XLOOKUP(MAX(C9:E9),C9:E9,C3:E3)')

    dv_nota = DataValidation(type="whole", operator="between", formula1="1", formula2="5")
    dv_nota.error = "Notas de 1 a 5."
    ws.add_data_validation(dv_nota)
    dv_nota.add("C4:E8")
    ws.conditional_formatting.add(
        "C9:E9", CellIsRule(operator="equal",
                            formula=["MAX($C$9:$E$9)"], fill=VERDE, font=Font(bold=True)))
    larguras(ws, [30, 8, 14, 14, 14, 18])
    wb.save(BASE / "cotacao.xlsx")
    print("[ok] cotacao.xlsx")


# ===================================================== matriz-acessos.xlsx ===
def gerar_matriz():
    wb = Workbook()
    ws = wb.active
    ws.title = "Matriz"
    ws["A1"] = "Matriz de acessos (RBAC) — pessoa × sistema"
    ws["A1"].font = TITULO
    ws["A2"] = "Valores: Admin / Editor / Leitor / — (sem acesso). Revisar a cada onboarding/offboarding."
    sistemas = ["Google Sheets", "n8n", "Base44", "Gmail (grupo)", "WhatsApp Meta", "GitHub"]
    cabecalho(ws, 4, ["pessoa", "papel"] + sistemas + ["revisado_em"])
    pessoas = [
        ("Fabiana TI", "admin", "Admin", "Admin", "Admin", "Editor", "Admin", "Editor"),
        ("Renato Gestor", "gestor", "Editor", "Editor", "Editor", "Editor", "Editor", "Leitor"),
        ("Lucas Atendimento", "atendente", "Editor", "—", "Editor", "Editor", "Leitor", "—"),
        ("Ana Souza", "vendedor", "Editor", "—", "Editor", "Editor", "—", "—"),
        ("Bruno Lima", "vendedor", "Editor", "—", "Editor", "Editor", "—", "—"),
        ("Carla Dias", "vendedor", "Editor", "—", "Editor", "Editor", "—", "—"),
        ("Diego Alves", "vendedor", "Editor", "—", "Editor", "Editor", "—", "—"),
        ("Estágio Auditoria", "leitura", "Leitor", "—", "Leitor", "Leitor", "—", "—"),
    ]
    for i, p in enumerate(pessoas, 5):
        for j, valor in enumerate(p, 1):
            ws.cell(row=i, column=j, value=valor)
        ws.cell(row=i, column=9, value="2026-10-20")
    dv = DataValidation(type="list", formula1='"Admin,Editor,Leitor,—"', allow_blank=False)
    dv.error = "Use Admin, Editor, Leitor ou —"
    ws.add_data_validation(dv)
    dv.add("C5:H20")
    larguras(ws, [20, 12, 14, 10, 10, 14, 14, 10])

    ws = wb.create_sheet("Onboarding")
    ws["A1"] = "Checklist de onboarding (prazo alvo: mesmo dia do início)"
    ws["A1"].font = TITULO
    cabecalho(ws, 3, ["etapa", "responsavel", "prazo", "concluido"])
    etapas = [
        ("Criar e-mail no Google Workspace e adicionar aos grupos", "Fabiana TI", "D0"),
        ("Conceder papel no Base44 conforme matriz (mínimo necessário)", "Renato Gestor", "D0"),
        ("Compartilhar planilha AureaOps (permissão de edição por aba)", "Fabiana TI", "D0"),
        ("Criar usuário no n8n (se papel exigir) e testar login", "Fabiana TI", "D1"),
        ("Enviar runbook + roteiro do projeto (docs/runbook.md)", "Renato Gestor", "D1"),
        ("Revisar acessos reais × matriz (conferência em 7 dias)", "Fabiana TI", "D7"),
    ]
    for i, (e, r, p) in enumerate(etapas, 4):
        ws.cell(row=i, column=1, value=e)
        ws.cell(row=i, column=2, value=r)
        ws.cell(row=i, column=3, value=p)
        ws.cell(row=i, column=4, value="")
    dv2 = DataValidation(type="list", formula1='"SIM,NÃO,N/A"')
    ws.add_data_validation(dv2)
    dv2.add("D4:D30")
    larguras(ws, [60, 16, 8, 12])

    ws = wb.create_sheet("Offboarding")
    ws["A1"] = "Checklist de offboarding (prazo alvo: mesmo dia da saída)"
    ws["A1"].font = TITULO
    cabecalho(ws, 3, ["etapa", "responsavel", "prazo", "concluido"])
    etapas = [
        ("Suspender acesso ao Google Workspace (desativar, não apagar, por 30 dias)", "Fabiana TI", "D0"),
        ("Remover papel do Base44", "Renato Gestor", "D0"),
        ("Remover compartilhamento da planilha AureaOps", "Fabiana TI", "D0"),
        ("Remover usuário do n8n; transferir workflows do dono", "Fabiana TI", "D0"),
        ("Revogar API Keys/chaves pessoais emitidas para a pessoa", "Fabiana TI", "D0"),
        ("Redirecionar e-mails por 15 dias e registrar a saída na matriz", "Renato Gestor", "D0"),
    ]
    for i, (e, r, p) in enumerate(etapas, 4):
        ws.cell(row=i, column=1, value=e)
        ws.cell(row=i, column=2, value=r)
        ws.cell(row=i, column=3, value=p)
    dv3 = DataValidation(type="list", formula1='"SIM,NÃO,N/A"')
    ws.add_data_validation(dv3)
    dv3.add("D4:D30")
    larguras(ws, [60, 16, 8, 12])

    wb.save(BASE / "matriz-acessos.xlsx")
    print("[ok] matriz-acessos.xlsx")


if __name__ == "__main__":
    try:
        import openpyxl  # noqa: F401
    except ImportError:
        print("Dependência ausente: pip install openpyxl")
        sys.exit(1)
    gerar_licencas()
    gerar_cotacao()
    gerar_matriz()
    print(f"[ok] Arquivos em {BASE}")
