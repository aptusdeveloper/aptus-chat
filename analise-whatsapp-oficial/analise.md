# Análise — Uso da API Oficial do WhatsApp (Cloud API) sem Verificação de Negócio

## Contexto
Em 08/07 testamos envio direto via WhatsApp Cloud API (Meta) com `POST /{phone_number_id}/messages`,
sem nunca ter completado a Verificação de Negócio (Business Verification) no Meta Business Manager.
Nesse mesmo período (06–08/07) passamos por **dois cenários diferentes**, que têm regras distintas e
não devem ser confundidos:

- **Cenário A — app próprio do aptus-chat, em modo Development**, usando o número de teste gratuito
  que a Meta fornece (`+1 555 145-3145`). Precisou cadastrar manualmente o destinatário de teste
  (+55 31 99995-0225) antes do primeiro envio funcionar.
- **Cenário B — número real de um cliente (simulação Gurgel Veículos), já conectado via a própria
  integração da Kommo** (login com Facebook que a Kommo já tem, com app próprio da Kommo já
  aprovado/"live" na Meta). Os scripts desta pasta (`send_test_whatsapp.sh` / `send_whatsapp.sh`) usam
  esse padrão — extraímos Phone Number ID + WABA ID + token direto do painel da Meta para esse número
  e enviamos via POST, **sem cadastrar nenhum destinatário manualmente**, porque o número já operava
  com permissão de mensagem irrestrita (herdada do app já-live da Kommo).

Essa distinção é o ponto central desta análise: a restrição de destinatários não é sobre
"verificado vs. não verificado" — é sobre **o app estar em modo Development (sandbox) ou Live**.

## Resumo
A Meta permite enviar e receber mensagens pela Cloud API mesmo com a conta/empresa não verificada.
Isso é suficiente para testar o fluxo completo (webhook de entrada, envio de saída, integração com
aptus-chat/Botpress). A restrição de destinatários só existe enquanto o **app específico usado pra
gerar o token** está em modo Development — um número conectado via um app de terceiro já aprovado
(caso da Kommo) não sofre essa restrição, mesmo sem a APTUS ter verificado nada.

## O que funciona sem verificação de negócio
- Criar um WABA (WhatsApp Business Account) e conectar um número de telefone real, ou usar o
  número de teste gratuito que a Meta fornece por padrão.
- Enviar mensagens de texto livre via `POST /{phone_number_id}/messages` com um access token
  válido — é exatamente o que os scripts desta pasta fazem.
- Testar o fluxo ponta a ponta em ambiente de desenvolvimento.
- Enviar para qualquer destinatário (não só números pré-cadastrados), **desde que** o token/app por
  trás do número já esteja em modo Live — isso não depende da APTUS verificar a própria empresa,
  só depende de qual app está gerenciando aquele WABA (ver Cenário B acima).

## Limitações

1. **Lista de destinatários restrita a 5 números — só no Cenário A (app próprio em Development).**
   Enquanto o app Meta usado para gerar o token não passou por App Review (não está em modo "Live"),
   só é possível enviar mensagens para números cadastrados manualmente em WhatsApp > Configuração da
   API > campo "Para". Foi o caso do app próprio do aptus-chat com o número de teste
   `+1 555 145-3145` — precisamos cadastrar o número pessoal (+55 31 99995-0225) como destinatário
   antes do primeiro envio funcionar. **Não se aplica** quando o número já está conectado via um app
   de terceiro já Live (Cenário B, scripts desta pasta).

2. **O "loop" de publicar o app próprio.**
   Pra tirar o app do aptus-chat do modo Development (Cenário A) e remover essa restrição, é preciso
   App Review aprovado pra `whatsapp_business_messaging` — e isso, na prática, exige Verificação de
   Negócio da APTUS no Business Manager. Ou seja: dá pra gerar token e testar sem verificação, mas
   pra publicar o app (e atender qualquer cliente sem whitelist) a verificação vira pré-requisito.
   É esse loop que gerou a frustração na sessão de 08/07 ("pra gerar token tem q linkar cm app
   proprio -> pra publicar o app proprio precisa verificado").

3. **Token de acesso temporário expira em 24h.**
   O token gerado via App Dashboard > Início Rápido é um token de usuário temporário (24h de
   validade) — origem do problema recorrente de "token expirou, gera outro". A solução definitiva é
   gerar um token de **System User permanente** em Business Settings > Usuários do Sistema, que não
   expira nesse ciclo curto. Vale tanto pro Cenário A quanto pro B.

4. **Limite de volume por camada (messaging tier).**
   Todo número novo — verificado ou não — começa numa camada inicial (tipicamente 250 conversas
   iniciadas pela empresa a cada 24h). O limite sobe automaticamente conforme volume de uso e
   quality rating do número, independente de verificação. A verificação de negócio ajuda a começar
   em camadas mais altas e reduz risco de bloqueio por "atividade suspeita" em número novo.

5. **Janela de 24h para mensagem livre.**
   Textos livres (como os scripts desta pasta enviam) só podem ser enviados dentro de 24h após a
   última mensagem do usuário. Fora dessa janela é obrigatório usar um Message Template
   pré-aprovado pela Meta (HSM). Essa regra vale com ou sem verificação de negócio, e em ambos os
   cenários.

6. **Selo de verificação e nome de exibição.**
   Sem Verificação de Negócio, o número não recebe o selo verde oficial, e o nome de exibição do
   WhatsApp Business passa por uma aprovação separada (Display Name Review). É mais uma questão de
   confiança do usuário final do que uma restrição técnica de envio.

## Conclusão prática pra APTUS
- **Para testes internos** (o que fizemos): a Meta libera tudo sem burocracia — dá pra testar sem
  verificação nenhuma, seja com o número de teste (cadastrando destinatário) ou com um número real
  já Live emprestado de outro app (Cenário B).
- **Para uso real com clientes do aptus-chat** (múltiplos clientes, qualquer destinatário, sem
  depender do app de terceiros): os próximos passos são (1) Verificação de Negócio da APTUS no
  Business Manager, (2) App Review aprovado pra `whatsapp_business_messaging` — ou usar o fluxo de
  **Embedded Signup** que já existe no fork do aptus-chat (ver sessão de 06/07), que resolve esse
  passo automaticamente ao conectar o WABA de cada cliente — e (3) token de System User permanente
  em vez do temporário de 24h.

## Scripts nesta pasta
- `send_test_whatsapp.sh` — recriação do disparo único original: envia "teste 1" para o número
  pessoal (+55 31 99995-0225).
- `send_whatsapp.sh` — versão reutilizável, aceita número e mensagem como argumentos
  (`./send_whatsapp.sh 5531999999999 "mensagem"`).

**Atenção:** ambos usam as credenciais atuais de
`/Users/ederambrosio/Projetos/Aptus/docs/privado/credenciais/aplicativo-aptus-chat-dados.md` — que são do app
**aptus-chat-teste, Cenário A** (número de teste da Meta, modo Development). Ou seja, herdam a
restrição de destinatários: `send_test_whatsapp.sh` funciona porque o número pessoal já está
cadastrado como destinatário de teste, mas `send_whatsapp.sh` só vai funcionar pra outros números se
eles também forem cadastrados manualmente em WhatsApp > Configuração da API > "Para" (ou se o app
aptus-chat sair do modo Development).

O disparo original de 08/07 (o que não exigia whitelist) usava credenciais do **Cenário B** — um
número real da simulação Gurgel Veículos, emprestado do app já-live da Kommo. Esse token já expirou
(validade de 24h) e não foi reaproveitado aqui porque não pertence à infraestrutura do aptus-chat —
recriar esse cenário exigiria gerar credenciais novas dentro do próprio fluxo da Kommo.

Se o token do aptus-chat-teste expirar, gere um novo em developers.facebook.com e atualize os
scripts.
