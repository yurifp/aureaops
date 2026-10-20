/**
 * ============================================================================
 * AureaOps — F2 (Captação de Leads) no Google Apps Script
 * ============================================================================
 * Responsabilidades deste Web App:
 *   doPost(e)      → recebe o lead do front-end (lead.html): autentica por API
 *                    Key, valida, garante idempotência por request_id, grava no
 *                    Sheets + Drive, distribui por round-robin, espelha no
 *                    Base44 (UrlFetchApp com retry/backoff) e responde JSON.
 *   doGet(e)       → verificação de saúde (status) e resumo protegido por chave.
 *   followUpLeads()→ trigger diária 09:00: lembrete D+1 ao vendedor e
 *                    escalonamento D+3 ao gestor (consulta a aba de logs para
 *                    não repetir avisos — mesma lógica da query Q5 do SQL).
 *
 * Segredos ficam em SCRIPT PROPERTIES (nunca no código):
 *   API_KEY_LEADS, SPREADSHEET_ID, DRIVE_PASTA_LEADS_ID,
 *   VENDEDORES (JSON), RR_PONTEIRO, GESTOR_EMAIL,
 *   BASE44_API_URL, BASE44_API_KEY
 *
 * Observação de contrato: Web Apps do Apps Script SEMPRE respondem HTTP 200.
 * O código de negócio viaja no campo "codigo" do corpo — o front-end decide
 * por ele (documentado em docs/dicionario-dados.md).
 *
 * DEPLOY (resumo — passo a passo completo no README):
 *   1. script.new → colar este arquivo; appsscript.json no ícone ⚙ (Manifest).
 *   2. Executar setup_() uma vez (cria abas, headers, trigger diária e semeia
 *      a aba pedidos para testes).
 *   3. Configurações do projeto > Propriedades do script → preencher chaves.
 *   4. Implantar > Novo > Web app: executar como EU, acesso "Qualquer pessoa".
 *   5. Copiar a URL /exec para frontend/lead.html (CONFIG.WEBHOOK_URL).
 * ============================================================================
 */

'use strict';

var VERSAO = '1.0.0';
var FLUXO = 'F2';
var FUSO = 'America/Sao_Paulo';

/** Cabeçalhos das abas (planilha "AureaOps" — id em SPREADSHEET_ID). */
var ABAS = {
  LEADS: 'leads',
  LOGS: 'logs',
  PEDIDOS: 'pedidos',
  CAMPANHAS: 'campanhas',
  CONSENTIMENTOS: 'consentimentos',
  CHAMADOS: 'chamados' // gravada pelo n8n (F1); lida pelo relatório (F3)
};

var COLUNAS_LEADS = [
  'request_id', 'protocolo', 'nome', 'email', 'telefone', 'interesse', 'mensagem',
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
  'consentimento_lgpd', 'status', 'vendedor', 'vendedor_email', 'distribuido_em',
  'primeiro_contato_em', 'convertido_em', 'base44_sync', 'created_at'
];

/* ========================================================================== *
 *  WEBHOOK PRINCIPAL                                                          *
 * ========================================================================== */

function doPost(e) {
  var requestId = '(desconhecido)';
  try {
    var corpo = parseCorpo_(e);
    requestId = corpo && corpo.request_id ? String(corpo.request_id) : requestId;

    if (!autenticado_(e)) {
      gravarLog_('webhook_recebido', 'aviso', requestId, 401, { motivo: 'api_key_invalida' });
      return resposta_('ERRO_AUTENTICACAO', 'Chave de integração ausente ou inválida.', null, requestId);
    }

    gravarLog_('webhook_recebido', 'sucesso', requestId, 200, { origem: 'frontend' });

    var erros = validarLead_(corpo);
    if (Object.keys(erros).length > 0) {
      gravarLog_('validacao_erro', 'aviso', requestId, 400, { campos: Object.keys(erros) });
      return resposta_('ERRO_VALIDACAO', 'Dados inválidos.', { erros: erros }, requestId);
    }

    // Idempotência: mesmo request_id → devolve a resposta original.
    var existente = buscarLinhaPorValor_(ABAS.LEADS, 'request_id', requestId);
    if (existente) {
      gravarLog_('idempotencia_duplicado', 'aviso', requestId, 200, { protocolo: existente.protocolo });
      return resposta_('OK', 'Lead já registrado (reenvio ignorado).',
        { protocolo: existente.protocolo, duplicado: true }, requestId);
    }

    var vendedor = proximoVendedor_();
    var protocolo = gerarProtocolo_('LED');
    var agora = agoraIso_();

    var linha = {};
    COLUNAS_LEADS.forEach(function (col) { linha[col] = ''; });
    linha.request_id = requestId;
    linha.protocolo = protocolo;
    linha.nome = String(corpo.nome).trim();
    linha.email = String(corpo.email).trim().toLowerCase();
    linha.telefone = String(corpo.telefone).trim();
    linha.interesse = corpo.interesse || '';
    linha.mensagem = corpo.mensagem || '';
    linha.utm_source = corpo.utm_source || '';
    linha.utm_medium = corpo.utm_medium || '';
    linha.utm_campaign = corpo.utm_campaign || '';
    linha.utm_term = corpo.utm_term || '';
    linha.utm_content = corpo.utm_content || '';
    linha.consentimento_lgpd = 1;
    linha.status = 'distribuido';
    linha.vendedor = vendedor.nome;
    linha.vendedor_email = vendedor.email;
    linha.distribuido_em = agora;
    linha.base44_sync = 0;
    linha.created_at = agora;

    gravarLinha_(ABAS.LEADS, linha);
    gravarLog_('gravacao_sheets', 'sucesso', requestId, 200,
      { aba: 'leads', vendedor: vendedor.nome, email_mascarado: mascararEmail_(linha.email) });

    salvarPayloadNoDrive_(requestId, corpo);
    gravarLog_('gravacao_drive', 'sucesso', requestId, 200, { arquivo: requestId + '.json' });

    gravarLog_('distribuicao_roundrobin', 'sucesso', requestId, null, { vendedor: vendedor.nome });

    // Espelho no Base44 com retry/backoff; falha não derruba o fluxo.
    var espelho = espelharNoBase44_(linha);
    if (espelho.ok) {
      atualizarCelula_(ABAS.LEADS, 'request_id', requestId, 'base44_sync', 1);
      gravarLog_('gravacao_base44', 'sucesso', requestId, espelho.status, {});
    } else {
      gravarLog_('gravacao_base44', 'aviso', requestId, espelho.status,
        { erro: espelho.erro, tentativas: espelho.tentativas });
    }

    registrarConsentimento_(linha.telefone);

    return resposta_('OK', 'Lead registrado e distribuído.',
      { protocolo: protocolo, vendedor: vendedor.nome }, requestId);
  } catch (erro) {
    gravarLog_('erro_interno', 'erro', requestId, 500, { mensagem: String(erro && erro.message || erro) });
    return resposta_('ERRO_INTERNO', 'Falha inesperada. A equipe já foi notificada pelos logs.', null, requestId);
  }
}

/* ========================================================================== *
 *  STATUS / RESUMO (doGet)                                                    *
 * ========================================================================== */

function doGet(e) {
  var acao = (e && e.parameter && e.parameter.action) || 'status';
  if (acao === 'status') {
    return resposta_('OK', 'Serviço ativo.',
      { servico: 'aureaops-f2', versao: VERSAO, horario: agoraIso_() }, null);
  }
  if (acao === 'resumo') {
    if (!autenticado_(e)) {
      return resposta_('ERRO_AUTENTICACAO', 'Chave de integração ausente ou inválida.', null, null);
    }
    var contagem = {};
    var dados = lerAba_(ABAS.LEADS);
    dados.forEach(function (l) {
      contagem[l.status || 'novo'] = (contagem[l.status || 'novo'] || 0) + 1;
    });
    var semContato = dados.filter(function (l) {
      return l.status === 'distribuido' && !l.primeiro_contato_em;
    }).length;
    return resposta_('OK', 'Resumo de leads.', { por_status: contagem, sem_primeiro_contato: semContato }, null);
  }
  return resposta_('ERRO_VALIDACAO', "Use ?action=status ou ?action=resumo.", null, null);
}

/* ========================================================================== *
 *  FOLLOW-UP D+1 / D+3 (trigger diária 09:00)                                 *
 * ========================================================================== */

function followUpLeads() {
  var agora = new Date();
  var dados = lerAba_(ABAS.LEADS);
  var enviados = { d1: 0, d3: 0 };

  dados.forEach(function (lead) {
    if (lead.status !== 'distribuido' || lead.primeiro_contato_em) return;
    var distribuicao = new Date(lead.distribuido_em);
    if (isNaN(distribuicao.getTime())) return;
    var horas = (agora - distribuicao) / 3600000;

    if (horas >= 72) {
      if (!followupJaEnviado_(lead.request_id, 'followup_d3')) {
        enviarEmail_(prop_('GESTOR_EMAIL'),
          '[AureaOps] Lead sem contato há 3 dias — escalonamento',
          'O lead ' + lead.protocolo + ' (' + mascararEmail_(lead.email) + ') foi distribuído para ' +
          lead.vendedor + ' em ' + lead.distribuido_em + ' e segue sem primeiro contato.\n' +
          'Status alterado para nao_respondeu automaticamente.');
        atualizarCelula_(ABAS.LEADS, 'request_id', lead.request_id, 'status', 'nao_respondeu');
        gravarLog_('followup_d3', 'aviso', lead.request_id, null, { vendedor: lead.vendedor });
        enviados.d3 += 1;
      }
    } else if (horas >= 24) {
      if (!followupJaEnviado_(lead.request_id, 'followup_d1')) {
        enviarEmail_(lead.vendedor_email,
          '[AureaOps] Lembrete: lead esperando contato desde ontem',
          'Olá, ' + lead.vendedor + '!\n\nO lead ' + lead.protocolo +
          ' está há mais de 24h aguardando primeiro contato.\n' +
          'Interesse declarado: ' + (lead.interesse || 'não informado') + '.\n\nAbraço, AureaOps');
        gravarLog_('followup_d1', 'aviso', lead.request_id, null, { vendedor: lead.vendedor });
        enviados.d1 += 1;
      }
    }
  });

  gravarLog_('followup_verificacao', 'sucesso', null, null, enviados);
  return enviados;
}

/* ========================================================================== *
 *  AUXILIARES — autenticação, validação, idempotência                         *
 * ========================================================================== */

function prop_(chave) {
  return PropertiesService.getScriptProperties().getProperty(chave);
}

/** API Key aceita via header X-Api-Key OU ?api_key= (limitação do GAS). */
function autenticado_(e) {
  var esperada = prop_('API_KEY_LEADS');
  if (!esperada) return false;
  var recebida = null;
  if (e && e.parameter && e.parameter.api_key) recebida = String(e.parameter.api_key);
  if (!recebida && e && e.headers && e.headers['x-api-key']) recebida = String(e.headers['x-api-key']);
  if (!recebida && e && e.postData && e.postData.type === 'application/json') {
    try { recebida = JSON.parse(e.postData.contents).api_key || null; } catch (_) {}
  }
  return recebida === esperada;
}

function parseCorpo_(e) {
  if (e && e.postData && e.postData.contents) {
    try { return JSON.parse(e.postData.contents); } catch (_) { return null; }
  }
  return null;
}

function validarLead_(corpo) {
  var erros = {};
  if (!corpo || typeof corpo !== 'object') {
    return { payload: ['Corpo da requisição não é um JSON válido.'] };
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(corpo.request_id || ''))) {
    erros.request_id = ['request_id deve ser um UUID v4 gerado no cliente.'];
  }
  if (!corpo.nome || String(corpo.nome).trim().length < 3) erros.nome = ['Informe o nome completo.'];
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(corpo.email || ''))) erros.email = ['E-mail inválido.'];
  var digitos = String(corpo.telefone || '').replace(/\D/g, '');
  if (digitos.length < 8 || digitos.length > 15) erros.telefone = ['Telefone inválido (com DDD).'];
  if (corpo.consentimento_lgpd !== true) erros.consentimento_lgpd = ['Consentimento LGPD obrigatório.'];
  return erros;
}

/* ========================================================================== *
 *  AUXILIARES — Sheets                                                        *
 * ========================================================================== */

function planilha_() {
  return SpreadsheetApp.openById(prop_('SPREADSHEET_ID'));
}

function aba_(nome) {
  var p = planilha_();
  var a = p.getSheetByName(nome);
  if (!a) {
    a = p.insertSheet(nome);
    var headers = {
      leads: COLUNAS_LEADS,
      logs: ['criado_em', 'fluxo', 'evento', 'status', 'request_id', 'http_status', 'detalhe'],
      pedidos: ['numero_pedido', 'cliente_nome', 'cliente_email', 'cliente_telefone', 'data_pedido', 'valor_total', 'status'],
      campanhas: ['nome', 'utm_source', 'utm_medium', 'utm_campaign', 'ativa'],
      consentimentos: ['telefone', 'opt_in_em', 'opt_out_em', 'origem'],
      chamados: ['protocolo', 'aberto_em', 'nome', 'email', 'telefone', 'numero_pedido', 'motivo',
        'prioridade', 'sla_horas', 'status', 'descricao', 'vinculo_pedido_ok', 'escalado',
        'request_id', 'primeira_resposta_em', 'resolvido_em', 'created_at']
    }[nome] || [];
    if (headers.length) a.appendRow(headers);
    a.setFrozenRows(1);
  }
  return a;
}

/** Lê a aba como array de objetos usando a linha 1 como chaves. */
function lerAba_(nome) {
  var a = aba_(nome);
  var valores = a.getDataRange().getValues();
  if (valores.length < 2) return [];
  var cabecalho = valores[0];
  return valores.slice(1).map(function (linha) {
    var obj = {};
    cabecalho.forEach(function (chave, i) { obj[chave] = linha[i]; });
    return obj;
  }).filter(function (obj) { return Object.keys(obj).some(function (k) { return obj[k] !== ''; }); });
}

function gravarLinha_(nome, objeto) {
  var a = aba_(nome);
  var cabecalho = a.getRange(1, 1, 1, a.getLastColumn()).getValues()[0];
  a.appendRow(cabecalho.map(function (col) { return objeto[col] !== undefined ? objeto[col] : ''; }));
}

/** Busca linear (volume do MVP); retorna o objeto da linha ou null. */
function buscarLinhaPorValor_(nome, coluna, valor) {
  return lerAba_(nome).filter(function (obj) { return String(obj[coluna]) === String(valor); })[0] || null;
}

function atualizarCelula_(nome, colunaChave, valorChave, colunaAlvo, valorAlvo) {
  var a = aba_(nome);
  var valores = a.getDataRange().getValues();
  var cabecalho = valores[0];
  var idxChave = cabecalho.indexOf(colunaChave);
  var idxAlvo = cabecalho.indexOf(colunaAlvo);
  if (idxChave < 0 || idxAlvo < 0) return;
  for (var i = 1; i < valores.length; i++) {
    if (String(valores[i][idxChave]) === String(valorChave)) {
      a.getRange(i + 1, idxAlvo + 1).setValue(valorAlvo);
      return;
    }
  }
}

/* ========================================================================== *
 *  AUXILIARES — round-robin, protocolo, Drive, Base44, e-mail, logs           *
 * ========================================================================== */

/** Round-robin protegido por LockService (duas requisições concorrentes
 *  nunca levam o mesmo vendedor nem corrompem o ponteiro). */
function proximoVendedor_() {
  var lock = LockService.getScriptLock();
  lock.waitLock(5000);
  try {
    var vendedores = JSON.parse(prop_('VENDEDORES') || '[]');
    if (!vendedores.length) {
      return { nome: '(time comercial)', email: prop_('GESTOR_EMAIL') };
    }
    var props = PropertiesService.getScriptProperties();
    var ponteiro = Number(props.getProperty('RR_PONTEIRO') || 0) % vendedores.length;
    props.setProperty('RR_PONTEIRO', String((ponteiro + 1) % vendedores.length));
    return vendedores[ponteiro];
  } finally {
    lock.releaseLock();
  }
}

function gerarProtocolo_(prefixo) {
  var hoje = Utilities.formatDate(new Date(), FUSO, 'yyyyMMdd');
  var doDia = lerAba_(ABAS.LEADS).filter(function (l) {
    return String(l.created_at || '').indexOf(Utilities.formatDate(new Date(), FUSO, 'yyyy-MM-dd')) === 0;
  }).length + 1;
  return prefixo + '-' + hoje + '-' + ('0000' + doDia).slice(-4);
}

/** Guarda o payload original em Drive/aureaops-leads/AAAA-MM/request_id.json. */
function salvarPayloadNoDrive_(requestId, corpo) {
  var pastaRaizId = prop_('DRIVE_PASTA_LEADS_ID');
  var pastaRaiz = pastaRaizId ? DriveApp.getFolderById(pastaRaizId) : DriveApp.getRootFolder();
  var mes = Utilities.formatDate(new Date(), FUSO, 'yyyy-MM');
  var pastas = pastaRaiz.getFoldersByName(mes);
  var pasta = pastas.hasNext() ? pastas.next() : pastaRaiz.createFolder(mes);
  pasta.createFile(requestId + '.json', JSON.stringify(corpo, null, 2), 'application/json');
}

/** Espelho no Base44 com retry exponencial (3 tentativas). */
function espelharNoBase44_(linha) {
  var urlBase = prop_('BASE44_API_URL');
  var chave = prop_('BASE44_API_KEY');
  if (!urlBase || !chave || chave.indexOf('TODO') === 0) {
    return { ok: false, status: null, tentativas: 0, erro: 'base44_nao_configurado' };
  }
  var payload = {
    request_id: linha.request_id,
    nome: linha.nome,
    email: linha.email,
    telefone: linha.telefone,
    interesse: linha.interesse,
    mensagem: linha.mensagem,
    utm_source: linha.utm_source,
    utm_medium: linha.utm_medium,
    utm_campaign: linha.utm_campaign,
    utm_term: linha.utm_term,
    utm_content: linha.utm_content,
    consentimento_lgpd: true,
    status: linha.status,
    vendedor: linha.vendedor,
    distribuido_em: linha.distribuido_em,
    origem: 'apps_script'
  };
  var resultado = fetchComRetry_(urlBase.replace(/\/$/, '') + '/lead', {
    method: 'post',
    contentType: 'application/json',
    headers: { 'X-API-Key': chave },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  }, 3);
  var ok = resultado.status >= 200 && resultado.status < 300;
  return { ok: ok, status: resultado.status, tentativas: resultado.tentativas, erro: ok ? null : resultado.corpo };
}

/** UrlFetchApp + backoff exponencial (0,5s; 1s; 2s). */
function fetchComRetry_(url, opcoes, tentativas) {
  var ultima = { status: 0, corpo: '', tentativas: 0 };
  for (var i = 0; i < tentativas; i++) {
    if (i > 0) Utilities.sleep(500 * Math.pow(2, i - 1));
    try {
      var resposta = UrlFetchApp.fetch(url, opcoes);
      ultima = { status: resposta.getResponseCode(), corpo: resposta.getContentText(), tentativas: i + 1 };
      if (ultima.status >= 200 && ultima.status < 300) return ultima;
    } catch (erro) {
      ultima = { status: 0, corpo: String(erro && erro.message || erro), tentativas: i + 1 };
    }
  }
  return ultima;
}

function enviarEmail_(destino, assunto, texto) {
  if (!destino) return;
  MailApp.sendEmail({ to: destino, subject: assunto, body: texto });
}

/** Opt-in de WhatsApp registrado na criação do lead (aba consentimentos). */
function registrarConsentimento_(telefone) {
  var existente = buscarLinhaPorValor_(ABAS.CONSENTIMENTOS, 'telefone', telefone);
  if (!existente) {
    gravarLinha_(ABAS.CONSENTIMENTOS, {
      telefone: telefone, opt_in_em: agoraIso_(), opt_out_em: '', origem: 'formulario_lead'
    });
  }
}

/* ========================================================================== *
 *  LOGS + MÁSCARAS (LGPD) + RESPOSTA PADRÃO                                   *
 * ========================================================================== */

function gravarLog_(evento, status, requestId, httpStatus, detalhe) {
  try {
    aba_(ABAS.LOGS).appendRow([
      agoraIso_(), FLUXO, evento, status, requestId || '', httpStatus || '',
      JSON.stringify(detalhe || {})
    ]);
  } catch (_) { /* log nunca deve quebrar o fluxo principal */ }
}

function mascararEmail_(email) {
  var partes = String(email || '').split('@');
  if (partes.length !== 2) return '***';
  return partes[0].charAt(0) + '***@' + partes[1].charAt(0) + '***';
}

function mascararTelefone_(telefone) {
  var texto = String(telefone || '');
  return texto.length <= 4 ? '***' : '***' + texto.slice(-4);
}

/** Corpo de resposta padronizado (HTTP será sempre 200 no GAS). */
function resposta_(codigo, mensagem, dados, requestId) {
  var corpo = {
    sucesso: codigo === 'OK',
    codigo: codigo,
    mensagem: mensagem,
    dados: dados || null,
    request_id: requestId || null
  };
  return ContentService
    .createTextOutput(JSON.stringify(corpo))
    .setMimeType(ContentService.MimeType.JSON);
}

function agoraIso_() {
  return Utilities.formatDate(new Date(), FUSO, "yyyy-MM-dd'T'HH:mm:ssXXX");
}

/* ========================================================================== *
 *  SETUP (executar UMA vez após colar o script)                               *
 * ========================================================================== */

/** Cria abas com headers, semeia pedidos de exemplo e a trigger diária. */
function setup_() {
  Object.keys(ABAS).forEach(function (nome) { aba_(ABAS[nome]); });

  var pedidos = aba_(ABAS.PEDIDOS);
  if (pedidos.getLastRow() < 2) {
    [
      ['PED-2026-1001', 'Mariana Duarte', 'mariana.duarte@example.com', '(00) 90000-0101', '2026-09-28', 349.90, 'entregue'],
      ['PED-2026-1002', 'Rafael Nunes', 'rafael.nunes@example.com', '(00) 90000-0102', '2026-10-01', 1299.00, 'entregue'],
      ['PED-2026-1003', 'Beatriz Alves', 'beatriz.alves@example.com', '(00) 90000-0103', '2026-10-03', 189.90, 'enviado'],
      ['PED-2026-1004', 'Carlos Menezes', 'carlos.menezes@example.com', '(00) 90000-0104', '2026-10-05', 759.50, 'entregue'],
      ['PED-2026-1005', 'Fernanda Lopes', 'fernanda.lopes@example.com', '(00) 90000-0105', '2026-10-08', 89.90, 'enviado'],
      ['PED-2026-1006', 'Gustavo Pereira', 'gustavo.pereira@example.com', '(00) 90000-0106', '2026-10-10', 1549.00, 'entregue']
    ].forEach(function (p) { pedidos.appendRow(p); });
  }

  var triggers = ScriptApp.getProjectTriggers();
  var jaExiste = triggers.some(function (t) {
    return t.getHandlerFunction() === 'followUpLeads';
  });
  if (!jaExiste) {
    ScriptApp.newTrigger('followUpLeads').timeBased().atHour(9).everyDays(1).create();
  }
  Logger.log('Setup concluído: abas criadas, pedidos semeados, trigger diária 09h verificada.');
}
