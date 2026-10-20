# AureaOps — Roteiro do vídeo de demonstração (2 minutos)

Grave a tela em 1080p com o README aberto ao fundo. Tom: "problema → solução →
prova". Ensaie uma vez com cronômetro: cada bloco abaixo tem tempo máximo.

| Tempo | Tela | Fala (roteiro) |
|---|---|---|
| 0:00–0:10 | README (diagrama de arquitetura) | "AureaOps: central de atendimento, leads e relatórios que eu construí para uma loja virtual fictícia — três fluxos ponta a ponta com n8n, Google Apps Script, Base44 e WhatsApp em modo simulado." |
| 0:10–0:30 | `chamado.html` preenchendo | "O cliente abre um chamado. O formulário gera um UUID de idempotência, valida no navegador e envia por API Key ao webhook do n8n." |
| 0:30–0:50 | n8n aberto no F1 (execução recente) + aba chamados | "O workflow valida de novo no servidor, deriva prioridade e SLA do motivo — defeito são 4 horas —, grava no Google Sheets e no Base44 e avisa o atendente. Reenvio do mesmo request_id não duplica: devolve o mesmo protocolo." |
| 0:50–1:10 | Base44: painel de SLA | "No app interno, o gestor vê o painel de SLA por prioridade — o mesmo cálculo das views SQL — com papéis de acesso por perfil." |
| 1:10–1:30 | `lead.html` + aba leads + e-mail do vendedor | "No Comercial, o lead entra pelo Apps Script: distribuição round-robin entre vendedores, payload arquivado no Drive e follow-up automático em D+1 e D+3, com escalonamento se ninguém contatar." |
| 1:30–1:50 | Postman rodando a coleção (verde) + `logs_integracao` | "Os contratos têm coleção Postman com testes de sucesso, validação e autenticação — e tudo que roda deixa rastro mascarado na auditoria, em conformidade com a LGPD." |
| 1:50–2:00 | README → seção "Decisões técnicas" | "Tudo documentado no GitHub: arquitetura, runbook, segurança — API Key versus OAuth2 — e a matriz que liga cada requisito ao arquivo que o comprova." |

Dicas: mostre o mouse seguindo a fala; se algo carregar devagar, corte na
edição; termine com o repositório aberto (URL do GitHub na descrição).
