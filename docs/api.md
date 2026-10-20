# AureaOps — Como consumir as APIs

Contrato completo em `openapi/openapi.yaml`; schemas dos payloads em
`docs/schemas/`. Resposta padronizada (todos os endpoints):

```json
{
  "sucesso": true,
  "codigo": "OK",
  "mensagem": "Chamado registrado com sucesso.",
  "dados": { "protocolo": "SAC-20261020-0007" },
  "request_id": "3f8b2c74-9d1e-4a6b-8f2c-1a2b3c4d5e6f"
}
```

| codigo | HTTP (F1/n8n) | HTTP (F2/Apps Script) | Significado |
|---|---|---|---|
| OK | 200 | 200 | Sucesso (ou reenvio idempotente com `dados.duplicado=true`) |
| ERRO_AUTENTICACAO | 401 | **200** (ver nota) | API Key ausente/inválida |
| ERRO_VALIDACAO | 400 | **200** (ver nota) | Campos inválidos (`dados.erros`) |
| ERRO_INTERNO | 500 | 200 | Exceção registrada em logs |

> **Nota F2:** Web Apps do Apps Script **sempre respondem HTTP 200** — não é
> possível alterar o status code. Por isso o contrato do F2 vive no campo
> `codigo` do corpo, e o `lead.html` decide por ele (documentado também no
> OpenAPI). O front trata 429/5xx mesmo assim (contrato defensivo).

## F1 — abrir chamado (webhook n8n)

```bash
curl -X POST "http://localhost:5678/webhook/f1-chamado" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $API_KEY_F1" \
  -d @tests/payloads/f1-valido.json
```

Envie o MESMO arquivo duas vezes: a segunda resposta traz
`dados.duplicado=true` e o mesmo protocolo (idempotência).

## F2 — capturar lead (Apps Script doPost)

```bash
curl -X POST "https://script.google.com/macros/s/SEU_ID/exec?api_key=$API_KEY_F2" \
  -H "Content-Type: text/plain;charset=utf-8" \
  -d @tests/payloads/f2-valido.json
```

Por que `text/plain`? Evita o preflight CORS que o Apps Script não responde.
Por que `?api_key=`? O evento `doPost` não expõe headers custom; o header
`X-Api-Key` continua aceito quando o chamador consegue enviá-lo (n8n, Node).

## F2 — healthcheck e resumo (doGet)

```bash
curl "https://script.google.com/macros/s/SEU_ID/exec?action=status"
curl "https://script.google.com/macros/s/SEU_ID/exec?action=resumo&api_key=$API_KEY_F2"
```

## Base44 (interna — chamada por n8n/Apps Script)

`POST {BASE44_API_URL}/chamado` e `POST {BASE44_API_URL}/lead` com header
`X-API-Key`. TODO(manual): confirme o path exato na aba API do seu app Base44
e alinhe os workflows (variável `BASE44_API_URL`).

## Postman

Importe `postman/colecao.json` + um ambiente (`ambiente-local.json` ou
`ambiente-producao.json`). A coleção cobre 9 cenários (sucesso, idempotência,
validação, autenticação) com testes `pm.test` prontos.
