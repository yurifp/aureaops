# AureaOps — Pacote de carreira

> **Regra de honestidade:** onde houver `[X]`, preencha com SEU número real
> (medições dos seus testes). Nada de métricas inventadas — em entrevista o
> número inventado desmonta.

## 5 bullets de currículo (Analista de Automação e Integração)

- Projetei e implementei o **AureaOps**, central de atendimento, leads e
  relatórios para um e-commerce fictício: 3 fluxos ponta a ponta (SAC com SLA e
  escalonamento, captação de leads com round-robin e follow-up D+1/D+3, BI com
  relatórios diários/semanais) integrando **n8n, Google Apps Script, Base44 e
  WhatsApp Cloud API**.
- Modelei banco relacional (7 tabelas, FK/índices/CHECKs, views de BI) em SQL e
  documentei contratos de API com **JSON Schema e OpenAPI 3**, testados por
  coleção **Postman** com casos de sucesso e falha.
- Garanti resiliência e conformidade: **idempotência por request_id**, retry
  com backoff, error workflow global com alerta imediato, mascaramento de dados
  (LGPD) e segredos fora do código (env/Script Properties).
- Construí automação de **WhatsApp em modo simulado/real** (Cloud API com
  templates, opt-in/opt-out) e painéis low-code no **Base44** com RBAC
  (admin/gestor/atendente/leitura).
- Automatizei a camada de BI: pasta de trabalho Excel gerada por script Python
  (XLOOKUP/CONT.SES/SOMARPRODUTO, tabela dinâmica, Power Query) e módulo
  administrativo de TI (licenças com alerta de vencimento, cotação ponderada,
  matriz de acessos com onboarding/offboarding).
- (Opcional, se você medir) Nos meus testes de [X] chamados e [X] leads, os
  fluxos registraram [X]% de entregas sem intervenção manual e zero
  duplicidades por reenvio.

## Texto para LinkedIn (post de lançamento)

> Acabei de publicar o AureaOps, meu projeto de portfólio para automação e
> integração: uma central de atendimento, leads e relatórios para um
> e-commerce fictício, construída com as ferramentas que eu quero usar no
> dia a dia — n8n, Google Apps Script, Base44, WhatsApp Cloud API, SQL e Excel.
>
> O que ele faz de ponta a ponta:
> 🔧 Cliente abre chamado → webhook n8n valida, deriva prioridade e SLA,
> grava no Sheets e no Base44 e avisa o atendente; a cada hora um job verifica
> o SLA e escala ao gestor o que estourou.
> 📈 Lead chega com UTMs → Apps Script distribui por round-robin, arquiva o
> payload no Drive e dispara follow-up em D+1 e D+3.
> 📊 Todo dia 7h o gestor recebe o resumo por e-mail e WhatsApp (modo
> simulado, trocável por 1 variável de ambiente) — e qualquer falha dispara um
> error workflow com alerta imediato.
>
> No meio do caminho tomei cuidado com o que separa um joguinho de um projeto:
> idempotência por request_id, retry com backoff, logs mascarados por LGPD,
> contratos versionados (OpenAPI + JSON Schema + Postman) e documentação de
> decisões — incluindo quando usar API Key versus OAuth2.
>
> Repositório no GitHub (link nos comentários). Feedbacks são muito bem-vindos —
> especialmente sobre os pontos que marquei como limitações no README, porque é
> aí que mora o próximo aprendizado. [opcional: Nos meus testes, [X] requisições
> com [X]% de sucesso e zero duplicidades.]

## 10 perguntas de entrevista (com respostas-modelo curtas)

1. **Por que idempotência por request_id gerado no front?**
   R: Rede e usuário falham mais do que servidor — clique duplo e retry do
   fetch duplicariam o registro. Com UUID único no banco, o reenvio devolve a
   resposta original em vez de criar outra linha; o mesmo id reaproveitado nas
   retentativas garante a semântica "executar uma vez".

2. **API Key ou OAuth2 aqui?**
   R: API Key para identificar a origem nos webhooks de entrada (chamada
   máquina→máquina); OAuth2 onde o n8n atua em nome de um usuário Google
   (Sheets). O access token vive ~1h e o refresh token permite renovar sem
   intervenção — escolhi escopos mínimos (só spreadsheets/drive).

3. **Por que a API do Apps Script "não devolve 400"?**
   R: Web Apps do Apps Script sempre respondem HTTP 200 — não há como mudar o
   status. Então o contrato do F2 viaja no campo `codigo` do corpo e o front
   decide por ele; documentei isso no OpenAPI para ninguém ser surpreendido.

4. **Como funciona o round-robin e por que LockService?**
   R: Um ponteiro em Script Properties escolhe o próximo vendedor e avança em
   módulo. Sem lock, duas requisições concorrentes leriam o mesmo ponteiro e
   cairiam no mesmo vendedor; o LockService serializa a seção crítica.

5. **Como o SLA é monitorado?**
   R: Um trigger horário no n8n lê os chamados não finalizados, compara
   agora − aberto_em com sla_horas e, se estourou e escalado=0, notifica o
   gestor e marca escalado=1 (evita reescalonar o mesmo chamado).

6. **O que acontece quando o Base44 está fora?**
   R: Nada se perde: o chamado/lead já foi gravado no Sheets; o espelho falha
   com log de aviso e o workflow de sync do n8n reenvia em lote a cada 15 min
   (base44_sync=0). Retry com backoff no Apps Script cobre falhas curtas.

7. **Por que gravar payload original no Drive?**
   R: A planilha guarda o dado normalizado; o Drive guarda o payload bruto por
   mês — se um campo do contrato mudar ou uma integração der defeito, dá para
   reprocessar do histórico sem pedir ao cliente de novo.

8. **WhatsApp oficial x não oficial?**
   R: O não oficial "robótiza" o app e viola os termos — risco de banimento e
   de dados passarem por terceiro sem base legal. A Cloud API oficial usa
   templates aprovados e respeita opt-in/opt-out; por isso o modo simulado
   entrega por e-mail/log e o real só entra com templates aprovados.

9. **LGPD no projeto?**
   R: Consentimento explícito obrigatório no payload (const true no schema),
   minimização de campos, logs e telas de perfil leitura com máscara
   (`m***@e***.com`), opt-out de WhatsApp checado antes de enviar e runbook
   com o passo a passo de exclusão a pedido do titular.

10. **O que você faria diferente em produção?**
    R: Rate limit por IP na frente dos webhooks públicos, listener de opt-out
    por resposta "PARAR" (webhook da Meta), trocar as buscas lineares das abas
    por índices/depara em cache quando o volume crescer, e observabilidade
    dedicada (hoje a aba logs + error workflow cumprem o papel no MVP).

## Como medir seus números reais para preencher [X]

1. Rode `tests/scripts/testar_api.mjs` N vezes (ex.: 50 envios por fluxo) e
   anote a taxa de sucesso da suíte.
2. No n8n, filtrar execuções do F1 por dia → % sem erro = "entregas sem
   intervenção".
3. Reenvie 10x o mesmo payload → confirme 10x `duplicado=true` e 1 linha na
   planilha = "zero duplicidades".
