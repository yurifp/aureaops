# AureaOps — Segurança: API Key x OAuth2 e checklist

## API Key x OAuth2 — quando usar cada um

| Critério | API Key | OAuth2 |
|---|---|---|
| O que prova | "Quem chama conhece a chave" (identidade da APLICAÇÃO/origem) | "Quem autorizou foi o dono do recurso" (identidade do USUÁRIO + escopos) |
| Custo de implementar | Trivial: comparar um header/string | Troca de tokens, redirecionamento, renovação |
| Escopos granulares | Difícil (ou a chave tudo pode, ou nada) | Nativo (ex.: `spreadsheets`, `drive.file`) |
| Revogação | Trocar a chave (derruba todos os clientes dela) | Revogar por usuário/app sem afetar os demais |
| Ideal para | Chamada servidor→servidor e webhooks de formulário público | Acesso a dados de terceiros em nome de alguém (Google, Meta) |

**No AureaOps:** API Key protege os webhooks de entrada (F1 no n8n, F2 no Apps
Script) porque quem chama é o nosso próprio formulário — basta identificá-lo.
OAuth2 autoriza o n8n a ler/escrever no Google Sheets **em nome da conta do
projeto**, porque o recurso pertence a um usuário Google.

## OAuth2 no projeto (n8n → Google Sheets), em 4 frases

1. No n8n, ao conectar o node Google Sheets, abre-se o **fluxo Authorization
   Code**: o n8n redireciona para o Google, você faz login e **autoriza os
   escopos mínimos** (Sheets; opcional Drive).
2. O Google devolve ao n8n um **access token** de curta vida (~1h) — é ele que
   autentica cada chamada REST (`Authorization: Bearer ...`).
3. Junto vem o **refresh token** de longa vida: quando o access token expira,
   o n8n troca o refresh por um access novo **sem intervenção humana** — por
   isso a credencial "fica conectada" para sempre até ser revogada.
4. Escopos mínimos escolhidos: `spreadsheets` (e `drive` só onde o Apps Script
   salva payloads). Nada de escopo "tudo".

Analogia de entrevista: **access token = chave do quarto do hotel** (vence no
check-out); **refresh token = seu número de reserva** (permite pedir chaves
novas enquanto a reserva durar).

## Rotação de chaves (processo, 1 parágrafo)

Gere com `node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"`.
Para trocar sem downtime: publique a nova chave como `API_KEY_F1_NOVA` ao lado
da antiga → aceite as duas por 24h (o IF do workflow compara contra as duas) →
troque o front/configs → remova a antiga. O mesmo vale para `API_KEY_LEADS`
(Script Properties) e a API Key do Base44 (regenerar no painel). Toda troca
registrada em `logs_integracao` (evento `chave_rotacionada`) e na matriz de
acessos.

## API Key exposta no front-end — limites e mitigação

- **Limite:** tudo que vai ao navegador é público (DevTools). A chave do
  formulário identifica a ORIGEM, não uma pessoa; sozinha não protege nada
  sensível.
- **Mitigação adotada:** (1) escopo mínimo — o endpoint só CRIA registro, não
  lê/apaga; (2) idempotência por `request_id` (abuso não duplica dados);
  (3) validação server-side idêntica à do cliente; (4) honeypot contra bots;
  (5) logs mascarados; (6) rotação documentada. Para produção real: rate limit
  por IP/proxy (ex.: Cloudflare Worker na frente) — declarado como roadmap.

## Checklist de segurança (atendido ✔ / roadmap ➜)

- ✔ Nenhum segredo no repositório (`.env.example` + Script Properties; `.gitignore` bloqueia `.env`)
- ✔ Autenticação em TODOS os endpoints de escrita (API Key)
- ✔ Validação de entrada server-side (domínios fechados, regex, tamanhos)
- ✔ Idempotência por `request_id` único em chamados/leads
- ✔ Logs sem dados sensíveis (máscara de e-mail/telefone)
- ✔ Consentimento LGPD obrigatório no payload (schema `const true`)
- ✔ Opt-in de WhatsApp registrado (aba consentimentos) e opt-out checado antes de envio real
- ✔ OAuth2 com escopos mínimos no Google; segredo só no lado server (n8n/Apps Script)
- ✔ Tratamento de erro com retry/backoff e alerta (error workflow + logs)
- ➜ Rate limit por IP na frente dos webhooks públicos
- ➜ Listener de opt-out por resposta "PARAR" no WhatsApp (webhook da Meta)
- ➜ Rotação automática programada (hoje: processo documentado)

## LGPD em uma frase por item

- **Base legal:** consentimento explícito no formulário (chamado) / legítimo
  interesse declarado com opt-out (lead comercial).
- **Minimização:** só campos necessários; interesse/mensagem opcionais.
- **Mascaramento:** logs e telas de perfil "leitura" mostram `m***@e***.com`.
- **Retenção/eliminação:** payloads originais ficam em Drive por pasta mensal
  — exclusão = apagar arquivo + linha da planilha (runbook documenta o passo a
  passo quando um titular pedir).
