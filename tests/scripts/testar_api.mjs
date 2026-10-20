#!/usr/bin/env node
/**
 * AureaOps — suíte de testes de integração (Node 18+, sem dependências).
 *
 * Cobre os contratos de F1 (webhook n8n) e F2 (Apps Script):
 *   - autenticação (401 real no F1; codigo=ERRO_AUTENTICACAO no corpo no F2)
 *   - validação (400 real no F1; codigo=ERRO_VALIDACAO no corpo no F2)
 *   - sucesso (protocolo SAC-/LED-)
 *   - idempotência (mesmo request_id → duplicado=true com o MESMO protocolo)
 *
 * Uso:
 *   F1_URL=http://localhost:5678/webhook/f1-chamado \
 *   F1_KEY=chave-f1 \
 *   F2_URL="https://script.google.com/macros/s/SEU_ID/exec" \
 *   F2_KEY=chave-f2 \
 *   node tests/scripts/testar_api.mjs
 *
 * Os request_id dos arquivos em tests/payloads/ são reaproveitados nas
 * retentativas — é isso que exercita a idempotência de ponta a ponta.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const PAYLOADS = path.join(AQUI, '..', 'payloads');

const F1_URL = process.env.F1_URL || '';
const F1_KEY = process.env.F1_KEY || '';
const F2_URL = process.env.F2_URL || '';
const F2_KEY = process.env.F2_KEY || '';

const lerPayload = (nome) =>
  JSON.parse(readFileSync(path.join(PAYLOADS, nome), 'utf8'));

let passaram = 0;
let falharam = 0;

function check(nome, condicao, detalhe = '') {
  if (condicao) {
    passaram += 1;
    console.log(`  PASS  ${nome}`);
  } else {
    falharam += 1;
    console.log(`  FAIL  ${nome} ${detalhe}`);
  }
}

async function postF1(payload, comChave = true) {
  const resposta = await fetch(F1_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(comChave ? { 'X-Api-Key': F1_KEY } : {}),
    },
    body: JSON.stringify(payload),
  });
  return { status: resposta.status, corpo: await resposta.json().catch(() => ({})) };
}

async function postF2(payload, chave = F2_KEY) {
  const separador = F2_URL.includes('?') ? '&' : '?';
  const resposta = await fetch(F2_URL + separador + 'api_key=' + encodeURIComponent(chave), {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain;charset=utf-8' },
    body: JSON.stringify(payload),
    redirect: 'follow',
  });
  return { status: resposta.status, corpo: await resposta.json().catch(() => ({})) };
}

async function testarF1() {
  if (!F1_URL || !F1_KEY) {
    console.log('\n[F1] pulado — defina F1_URL e F1_KEY');
    return;
  }
  console.log('\n[F1] webhook n8n:', F1_URL);

  const valido = lerPayload('f1-valido.json');
  const primeira = await postF1(valido);
  check('cria chamado (HTTP 200)', primeira.status === 200, `status=${primeira.status}`);
  check('sucesso=true', primeira.corpo.sucesso === true);
  check('protocolo SAC-AAAAMMDD-NNNN',
    /^SAC-\d{8}-\d{4}$/.test(primeira.corpo?.dados?.protocolo || ''));

  const segunda = await postF1(valido); // MESMO request_id
  check('reenvio idempotente (200)', segunda.status === 200);
  check('duplicado=true com mesmo protocolo',
    segunda.corpo?.dados?.duplicado === true &&
    segunda.corpo?.dados?.protocolo === primeira.corpo?.dados?.protocolo);

  const semChave = await postF1(valido, false);
  check('sem API Key → 401', semChave.status === 401, `status=${semChave.status}`);
  check('codigo=ERRO_AUTENTICACAO', semChave.corpo?.codigo === 'ERRO_AUTENTICACAO');

  const motivoInvalido = await postF1(lerPayload('f1-invalido-motivo.json'));
  check('motivo fora do domínio → 400', motivoInvalido.status === 400, `status=${motivoInvalido.status}`);
  check('erros apontam o campo motivo',
    Array.isArray(motivoInvalido.corpo?.dados?.erros?.motivo));

  const semConsentimento = await postF1(lerPayload('f1-invalido-consentimento.json'));
  check('sem LGPD → 400', semConsentimento.status === 400);
  check('erros apontam consentimento_lgpd',
    Array.isArray(semConsentimento.corpo?.dados?.erros?.consentimento_lgpd));
}

async function testarF2() {
  if (!F2_URL || !F2_KEY) {
    console.log('\n[F2] pulado — defina F2_URL e F2_KEY');
    return;
  }
  console.log('\n[F2] Apps Script:', F2_URL);

  const status = await fetch(F2_URL + '?action=status').then((r) => r.json()).catch(() => ({}));
  check('healthcheck status', status.sucesso === true, JSON.stringify(status));

  const valido = lerPayload('f2-valido.json');
  const primeira = await postF2(valido);
  check('HTTP 200 (GAS sempre responde 200)', primeira.status === 200);
  check('sucesso=true', primeira.corpo.sucesso === true);
  check('protocolo LED-AAAAMMDD-NNNN',
    /^LED-\d{8}-\d{4}$/.test(primeira.corpo?.dados?.protocolo || ''));

  const segunda = await postF2(valido);
  check('reenvio idempotente',
    segunda.corpo?.dados?.duplicado === true &&
    segunda.corpo?.dados?.protocolo === primeira.corpo?.dados?.protocolo);

  const emailInvalido = await postF2(lerPayload('f2-invalido-email.json'));
  check('e-mail inválido → codigo=ERRO_VALIDACAO',
    emailInvalido.corpo?.codigo === 'ERRO_VALIDACAO');

  const chaveErrada = await postF2(valido, 'chave-errada');
  check('chave errada → codigo=ERRO_AUTENTICACAO',
    chaveErrada.corpo?.codigo === 'ERRO_AUTENTICACAO');
}

const main = async () => {
  console.log('AureaOps — testes de integração');
  await testarF1();
  await testarF2();
  console.log(`\nResultado: ${passaram} passaram, ${falharam} falharam`);
  process.exit(falharam > 0 ? 1 : 0);
};

main().catch((erro) => {
  console.error('Falha ao executar a suíte:', erro);
  process.exit(1);
});
