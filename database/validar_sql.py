#!/usr/bin/env python3
"""Valida schema.sql, seed.sql, views.sql e queries.sql em memória (SQLite).

Uso:  python database/validar_sql.py
Saída: execução de cada query de exemplo com as primeiras linhas.
"""
import pathlib
import re
import sqlite3
import sys

BASE = pathlib.Path(__file__).resolve().parent


def main() -> int:
    db = sqlite3.connect(":memory:")
    for arquivo in ("schema.sql", "seed.sql", "views.sql"):
        db.executescript((BASE / arquivo).read_text(encoding="utf-8"))
        print(f"[ok] {arquivo} executado")

    for view in ("vw_chamados_detalhe", "vw_sla_resumo", "vw_funil_leads"):
        linhas = db.execute(f"SELECT COUNT(*) FROM {view}").fetchone()[0]
        print(f"[ok] {view}: {linhas} linhas")
        for linha in db.execute(f"SELECT * FROM {view} LIMIT 5"):
            print("      ", linha)

    texto = (BASE / "queries.sql").read_text(encoding="utf-8")
    for i, bloco in enumerate(re.split(r";\s*\n", texto), 1):
        corpo = "\n".join(
            l for l in bloco.splitlines() if not l.strip().startswith("--")
        ).strip()
        if not corpo:
            continue
        linhas = db.execute(corpo).fetchall()
        print(f"[ok] query {i}: {len(linhas)} linha(s)")
        for linha in linhas[:3]:
            print("      ", linha)
    print("\nTudo verde: schema, seed, views e queries executam sem erro.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
