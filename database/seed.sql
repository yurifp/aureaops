-- ============================================================================
-- AureaOps — seed.sql (dados 100% fictícios)
-- Telefones usam DDD 00 e domínios @example.com / @aureahome.example
-- (reservados para documentação) para garantir que nada é real.
-- Data de referência: 2026-10-20.
-- ============================================================================

-- ---------------------------------------------------------------- clientes --
INSERT INTO clientes (id, nome, email, telefone, created_at) VALUES
 (1,'Mariana Duarte',  'mariana.duarte@example.com',  '(00) 90000-0101','2026-08-02 10:15:00'),
 (2,'Rafael Nunes',    'rafael.nunes@example.com',    '(00) 90000-0102','2026-08-09 14:30:00'),
 (3,'Beatriz Alves',   'beatriz.alves@example.com',   '(00) 90000-0103','2026-08-15 09:05:00'),
 (4,'Carlos Menezes',  'carlos.menezes@example.com',  '(00) 90000-0104','2026-08-21 18:40:00'),
 (5,'Fernanda Lopes',  'fernanda.lopes@example.com',  '(00) 90000-0105','2026-09-01 11:20:00'),
 (6,'Gustavo Pereira', 'gustavo.pereira@example.com', '(00) 90000-0106','2026-09-10 16:55:00'),
 (7,'Heloisa Martins', 'heloisa.martins@example.com', '(00) 90000-0107','2026-09-18 08:45:00'),
 (8,'Thiago Barbosa',  'thiago.barbosa@example.com',  '(00) 90000-0108','2026-10-01 13:10:00');

-- ----------------------------------------------------------------- pedidos --
INSERT INTO pedidos (id, cliente_id, numero_pedido, data_pedido, valor_total, status, created_at) VALUES
 ( 1,1,'PED-2026-1001','2026-09-28', 349.90,'entregue', '2026-09-28 20:12:00'),
 ( 2,2,'PED-2026-1002','2026-10-01',1299.00,'entregue', '2026-10-01 09:40:00'),
 ( 3,3,'PED-2026-1003','2026-10-03', 189.90,'enviado',  '2026-10-03 15:22:00'),
 ( 4,4,'PED-2026-1004','2026-10-05', 759.50,'entregue', '2026-10-05 11:05:00'),
 ( 5,5,'PED-2026-1005','2026-10-08',  89.90,'enviado',  '2026-10-08 17:31:00'),
 ( 6,6,'PED-2026-1006','2026-10-10',1549.00,'entregue', '2026-10-10 10:48:00'),
 ( 7,7,'PED-2026-1007','2026-10-12', 429.00,'pago',     '2026-10-12 22:19:00'),
 ( 8,8,'PED-2026-1008','2026-10-14', 649.00,'entregue', '2026-10-14 08:56:00'),
 ( 9,1,'PED-2026-1009','2026-10-16', 219.90,'pago',     '2026-10-16 19:03:00'),
 (10,3,'PED-2026-1010','2026-10-17', 539.00,'enviado',  '2026-10-17 14:27:00'),
 (11,5,'PED-2026-1011','2026-10-18', 129.90,'pago',     '2026-10-18 09:15:00'),
 (12,6,'PED-2026-1012','2026-10-19', 999.00,'pago',     '2026-10-19 21:37:00');

-- ---------------------------------------------------------------- chamados --
-- Cenários propositais: dentro do SLA, fora do SLA, escalado, aberto, cancelado.
INSERT INTO chamados
 (id, cliente_id, pedido_id, protocolo, motivo, prioridade, sla_horas, status,
  descricao, vinculo_pedido_ok, escalado, request_id, aberto_em,
  primeira_resposta_em, resolvido_em, created_at) VALUES
 (1,1,1,'SAC-20261010-0001','defeito','alta', 4,'resolvido',
  'Cadeira chegou com o braço direito riscado e soltando parafuso.',1,0,
  '11111111-1111-4111-8111-111111111101','2026-10-10 09:00:00','2026-10-10 09:45:00','2026-10-10 11:00:00','2026-10-10 09:00:05'),
 (2,2,2,'SAC-20261008-0002','defeito','alta', 4,'resolvido',
  'Máquina de café veio com reservatório trincado, vaza água.',1,1,
  '11111111-1111-4111-8111-111111111102','2026-10-08 14:00:00','2026-10-08 14:30:00','2026-10-08 20:00:00','2026-10-08 14:00:06'),
 (3,3,3,'SAC-20261005-0003','troca','media',24,'resolvido',
  'Comprei o jogo de lençol casal e preciso trocar por tamanho queen.',1,0,
  '11111111-1111-4111-8111-111111111103','2026-10-05 10:00:00','2026-10-05 11:00:00','2026-10-05 20:00:00','2026-10-05 10:00:04'),
 (4,4,4,'SAC-20261019-0004','atraso','media',24,'em_atendimento',
  'Pedido com previsão de entrega vencida há 6 dias, rastreio parado.',1,1,
  '11111111-1111-4111-8111-111111111104','2026-10-19 02:00:00','2026-10-19 03:00:00',NULL,'2026-10-19 02:00:03'),
 (5,5,5,'SAC-20261011-0005','duvida','baixa',72,'resolvido',
  'Como calibro a luminária pendente para altura de bancada?',1,0,
  '11111111-1111-4111-8111-111111111105','2026-10-11 08:00:00','2026-10-11 08:30:00','2026-10-12 14:00:00','2026-10-11 08:00:02'),
 (6,6,6,'SAC-20261019-0006','troca','media',24,'aguardando_cliente',
  'Sofá recebido em outra cor; quero trocar pelo modelo anunciado.',1,0,
  '11111111-1111-4111-8111-111111111106','2026-10-19 20:00:00','2026-10-19 21:00:00',NULL,'2026-10-19 20:00:04'),
 (7,7,7,'SAC-20261020-0007','defeito','alta', 4,'aberto',
  'Tapete entregue com borda desfiada em dois pontos.',1,0,
  '11111111-1111-4111-8111-111111111107','2026-10-20 08:30:00',NULL,NULL,'2026-10-20 08:30:02'),
 (8,8,8,'SAC-20261016-0008','duvida','baixa',72,'em_atendimento',
  'Preciso da nota fiscal do pedido para garantia estendida.',0,1,
  '11111111-1111-4111-8111-111111111108','2026-10-16 07:00:00','2026-10-16 07:20:00',NULL,'2026-10-16 07:00:05'),
 (9,1,9,'SAC-20261001-0009','atraso','media',24,'resolvido',
  'Entrega prevista para 29/09 e nada chegou; preciso de posição.',1,0,
  '11111111-1111-4111-8111-111111111109','2026-10-01 09:00:00','2026-10-01 10:00:00','2026-10-02 15:00:00','2026-10-01 09:00:03'),
 (10,3,10,'SAC-20261014-0010','defeito','alta', 4,'cancelado',
  'Quadro veio com vidro quebrado; cliente desistiu e pediu reembolso direto.',1,0,
  '11111111-1111-4111-8111-111111111110','2026-10-14 12:00:00','2026-10-14 12:15:00',NULL,'2026-10-14 12:00:02');

-- ------------------------------------------------------ interacoes_chamado --
INSERT INTO interacoes_chamado (chamado_id, autor, canal, mensagem, created_at) VALUES
 (1,'cliente',   'web',      'Abertura do chamado via formulário do site.',              '2026-10-10 09:00:05'),
 (1,'atendente', 'interno',   'Foto do defeito validada; peça de reposição aprovada.',   '2026-10-10 09:45:10'),
 (1,'sistema',   'web',       'Chamado resolvido automaticamente após confirmação.',     '2026-10-10 11:00:00'),
 (2,'cliente',   'web',      'Abertura do chamado via formulário do site.',              '2026-10-08 14:00:06'),
 (2,'sistema',   'email',     'SLA de 4h expirado; escalonado ao gestor.',               '2026-10-08 18:00:00'),
 (2,'atendente', 'whatsapp',  'Produto substituído; transportadora retirou o defeituoso.','2026-10-08 19:50:00'),
 (3,'cliente',   'web',      'Abertura do chamado via formulário do site.',              '2026-10-05 10:00:04'),
 (3,'atendente', 'interno',   'Troca autorizada; código de postagem enviado por e-mail.','2026-10-05 11:00:00'),
 (4,'cliente',   'web',      'Abertura do chamado via formulário do site.',              '2026-10-19 02:00:03'),
 (4,'sistema',   'email',     'SLA de 24h expirado; escalonado ao gestor.',              '2026-10-20 02:00:00'),
 (5,'cliente',   'web',      'Abertura do chamado via formulário do site.',              '2026-10-11 08:00:02'),
 (5,'atendente', 'email',     'Manual de instalação enviado com vídeo de apoio.',        '2026-10-11 08:30:00'),
 (6,'cliente',   'web',      'Abertura do chamado via formulário do site.',              '2026-10-19 20:00:04'),
 (6,'atendente', 'whatsapp',  'Aguardando cliente enviar foto da etiqueta do sofá.',     '2026-10-19 21:00:00'),
 (7,'cliente',   'web',      'Abertura do chamado via formulário do site.',              '2026-10-20 08:30:02'),
 (8,'cliente',   'web',      'Abertura do chamado via formulário do site.',              '2026-10-16 07:00:05'),
 (8,'sistema',   'email',     'SLA de 72h expirado; escalonado ao gestor.',              '2026-10-19 07:00:00'),
 (9,'cliente',   'web',      'Abertura do chamado via formulário do site.',              '2026-10-01 09:00:03'),
 (9,'atendente', 'interno',   'Transportadora ressarciu; entrega refeita.',              '2026-10-02 14:55:00'),
 (10,'cliente',  'web',      'Abertura do chamado via formulário do site.',              '2026-10-14 12:00:02'),
 (10,'atendente','interno',   'Cancelado a pedido do cliente; reembolso total.',         '2026-10-14 12:30:00');

-- --------------------------------------------------------------- campanhas --
INSERT INTO campanhas (id, nome, utm_source, utm_medium, utm_campaign, ativa, created_at) VALUES
 (1,'Instagram Decor Primavera','instagram', 'social',  'primavera-2026',   1,'2026-09-20 09:00:00'),
 (2,'Google Busca Decoração',   'google',    'cpc',     'decoracao-sala',   1,'2026-09-22 09:00:00'),
 (3,'Newsletter Boas-vindas',   'newsletter','email',   'boas-vindas',      1,'2026-09-25 09:00:00'),
 (4,'Programa Indique Amigas',  'indicacao', 'referral','programa-indique', 0,'2026-08-10 09:00:00');

-- ------------------------------------------------------------------- leads --
-- Round-robin fictício entre Ana Souza, Bruno Lima, Carla Dias e Diego Alves.
-- L14/L15 sem primeiro contato alimentam a consulta de follow-up (D+1/D+3).
INSERT INTO leads
 (id, nome, email, telefone, interesse, mensagem, campanha_id, utm_term, utm_content,
  consentimento_lgpd, status, vendedor, distribuido_em, primeiro_contato_em,
  convertido_em, base44_sync, request_id, created_at) VALUES
 ( 1,'Patrícia Ramos','patricia.ramos@example.com','(00) 90000-0201','Sofá retrátil',NULL,1,'sofa-3-lugares','carrossel-01',1,'convertido',   'Ana Souza',  '2026-10-05 09:05:00','2026-10-05 10:30:00','2026-10-06 15:00:00',1,'22222222-2222-4222-8222-222222222201','2026-10-05 09:04:55'),
 ( 2,'Lucas Moreira', 'lucas.moreira@example.com', '(00) 90000-0202','Mesa jantar',   NULL,2,'mesa-jantar',   'anuncio-07',    1,'convertido',   'Bruno Lima', '2026-10-05 11:10:00','2026-10-05 14:00:00','2026-10-07 09:30:00',1,'22222222-2222-4222-8222-222222222202','2026-10-05 11:09:58'),
 ( 3,'Aline Castro',  'aline.castro@example.com',  '(00) 90000-0203','Cadeiras',      'Quero 4 cadeiras.',1,NULL,           'stories-03',    1,'contatado',    'Carla Dias', '2026-10-06 10:20:00','2026-10-06 11:00:00',NULL,1,'22222222-2222-4222-8222-222222222203','2026-10-06 10:19:50'),
 ( 4,'Rodrigo Faria', 'rodrigo.faria@example.com', '(00) 90000-0204','Luminária',     NULL,2,'luminaria-pendente','link-patrocinado',1,'perdido',   'Diego Alves','2026-10-06 15:35:00','2026-10-07 09:00:00',NULL,1,'22222222-2222-4222-8222-222222222204','2026-10-06 15:35:10'),
 ( 5,'Camila Rocha',  'camila.rocha@example.com',  '(00) 90000-0205','Tapete sala',   NULL,3,NULL,           'bloco-02',      1,'contatado',    'Ana Souza',  '2026-10-08 08:45:00','2026-10-08 09:10:00',NULL,1,'22222222-2222-4222-8222-222222222205','2026-10-08 08:44:59'),
 ( 6,'Felipe Antunes','felipe.antunes@example.com','(00) 90000-0206','Kit lençóis',   'Qual o tamanho king?',3,NULL,        'bloco-01',      1,'nao_respondeu','Bruno Lima','2026-10-09 14:00:00','2026-10-12 10:00:00',NULL,1,'22222222-2222-4222-8222-222222222206','2026-10-09 13:59:57'),
 ( 7,'Vanessa Prado', 'vanessa.prado@example.com', '(00) 90000-0207','Organizadores', NULL,4,NULL,           NULL,            1,'convertido',   'Carla Dias', '2026-10-10 09:30:00','2026-10-10 10:15:00','2026-10-11 16:20:00',1,'22222222-2222-4222-8222-222222222207','2026-10-10 09:30:03'),
 ( 8,'Marcelo Teixeira','marcelo.teixeira@example.com','(00) 90000-0208','Painel TV', NULL,2,'painel-tv',     'anuncio-02',    1,'perdido',      'Diego Alves','2026-10-11 16:50:00','2026-10-12 09:00:00',NULL,1,'22222222-2222-4222-8222-222222222208','2026-10-11 16:50:01'),
 ( 9,'Juliana Freitas','juliana.freitas@example.com','(00) 90000-0209','Cortina blackout',NULL,1,'blackout','reel-05',     1,'contatado',    'Ana Souza',  '2026-10-13 10:10:00','2026-10-13 10:40:00',NULL,1,'22222222-2222-4222-8222-222222222209','2026-10-13 10:09:49'),
 (10,'Eduardo Salles', 'eduardo.salles@example.com','(00) 90000-0210','Cama box',      NULL,2,'cama-box-queen','anuncio-11',  1,'nao_respondeu','Bruno Lima','2026-10-14 09:20:00','2026-10-17 11:00:00',NULL,1,'22222222-2222-4222-8222-222222222210','2026-10-14 09:19:52'),
 (11,'Renata Serra',  'renata.serra@example.com',  '(00) 90000-0211','Quadros',       'Sugestões de composição.',1,NULL,  'carrossel-04',  1,'convertido',   'Carla Dias', '2026-10-15 13:00:00','2026-10-15 13:30:00','2026-10-16 10:00:00',1,'22222222-2222-4222-8222-222222222211','2026-10-15 12:59:58'),
 (12,'Bruno Sampaio', 'bruno.sampaio@example.com', '(00) 90000-0212','Aparador',      NULL,3,NULL,           'bloco-03',      1,'nao_respondeu','Diego Alves','2026-10-16 17:40:00','2026-10-19 09:00:00',NULL,1,'22222222-2222-4222-8222-222222222212','2026-10-16 17:40:07'),
 (13,'Larissa Mota',  'larissa.mota@example.com',  '(00) 90000-0213','Espelho banheiro',NULL,2,'espelho-banheiro','link-patrocinado',1,'contatado', 'Ana Souza',  '2026-10-18 09:15:00','2026-10-18 09:45:00',NULL,1,'22222222-2222-4222-8222-222222222213','2026-10-18 09:14:51'),
 (14,'Otávio Bastos', 'otavio.bastos@example.com', '(00) 90000-0214','Rack sala',     NULL,1,'rack-madeira', 'reel-02',       1,'distribuido',  'Bruno Lima', '2026-10-18 18:05:00',NULL,NULL,0,'22222222-2222-4222-8222-222222222214','2026-10-18 18:04:56'),
 (15,'Simone Vieira','simone.vieira@example.com',  '(00) 90000-0215','Kit banheiro',  NULL,3,NULL,           'bloco-04',      1,'distribuido',  'Carla Dias', '2026-10-19 08:30:00',NULL,NULL,0,'22222222-2222-4222-8222-222222222215','2026-10-19 08:29:54'),
 (16,'Denis Cunha',   'denis.cunha@example.com',   '(00) 90000-0216','Poltrona',      'Tem na cor beige?',4,NULL,NULL,       1,'novo',         NULL,         NULL,NULL,NULL,0,'22222222-2222-4222-8222-222222222216','2026-10-20 07:50:02');

-- --------------------------------------------------------- logs_integracao --
INSERT INTO logs_integracao (fluxo, evento, status, request_id, http_status, detalhe, criado_em) VALUES
 ('F1','webhook_recebido','sucesso','11111111-1111-4111-8111-111111111107',200,'{"origem":"frontend","ip_mascarado":"***.***.***.17"}','2026-10-20 08:30:01'),
 ('F1','validacao_ok','sucesso','11111111-1111-4111-8111-111111111107',NULL,'{"motivo":"defeito","prioridade":"alta"}','2026-10-20 08:30:01'),
 ('F1','gravacao_sheets','sucesso','11111111-1111-4111-8111-111111111107',200,'{"aba":"chamados","linha":11}','2026-10-20 08:30:03'),
 ('F1','gravacao_base44','aviso','11111111-1111-4111-8111-111111111107',503,'{"erro":"servico_indisponivel","retry_agendado":true}','2026-10-20 08:30:04'),
 ('F1','whatsapp_simulado','sucesso','11111111-1111-4111-8111-111111111107',200,'{"destino":"a***@a***.example","canal":"email_substituto"}','2026-10-20 08:30:05'),
 ('F2','webhook_recebido','sucesso','22222222-2222-4222-8222-222222222216',200,'{"origem":"frontend"}','2026-10-20 07:50:01'),
 ('F2','distribuicao_roundrobin','sucesso','22222222-2222-4222-8222-222222222216',NULL,'{"vendedor":"fila_unica"}','2026-10-20 07:50:02'),
 ('F2','gravacao_drive','sucesso','22222222-2222-4222-8222-222222222216',200,'{"arquivo":"2026-10/22222216.json"}','2026-10-20 07:50:02'),
 ('F2','gravacao_base44','erro','22222222-2222-4222-8222-222222222214',503,'{"erro":"servico_indisponivel","tentativas":3}','2026-10-18 18:05:09'),
 ('F3','relatorio_diario','sucesso',NULL,200,'{"chamados_24h":3,"leads_24h":2,"canais":["email","whatsapp_simulado"]}','2026-10-20 07:00:03'),
 ('F3','sla_verificacao','aviso',NULL,NULL,'{"vencidos":2,"escalonados":0}','2026-10-20 07:00:01'),
 ('F1','sla_escalonamento','erro','11111111-1111-4111-8111-111111111104',NULL,'{"erro":"falha_envio_whatsapp","fallback":"email"}','2026-10-20 02:00:06');
