# Análise — Uso da API Oficial do WhatsApp (Cloud API) sem Verificação de Negócio

## Contexto
Durante os testes de 08/07, conectamos um número real à WhatsApp Cloud API (Meta) e conseguimos
enviar mensagens via POST direto (`send_test_whatsapp.sh`) sem nunca ter completado a Verificação
de Negócio (Business Verification) no Meta Business Manager. Esta análise documenta o que a Meta
libera nesse estado "não verificado" e onde estão os limites.

## Resumo
A Meta permite enviar e receber mensagens pela Cloud API mesmo com a conta não verificada. Isso é
suficiente para testar o fluxo completo (webhook de entrada, envio de saída, integração com
aptus-chat/Botpress). As restrições aparecem quando se tenta sair do ambiente de teste para
atender clientes reais em volume.

## O que funciona sem verificação
- Criar um WABA (WhatsApp Business Account) e conectar um número de telefone real, ou usar o
  número de teste gratuito que a Meta fornece por padrão.
- Enviar mensagens de texto livre via `POST /{phone_number_id}/messages` com um access token
  válido — é exatamente o que os scripts desta pasta fazem.
- Testar o fluxo ponta a ponta em ambiente de desenvolvimento.

## Limitações enquanto o app está em modo "Development" / não verificado

1. **Lista de destinatários restrita a 5 números.**
   Enquanto o app Meta não passou por App Review (não está em modo "Live"), só é possível enviar
   mensagens para números cadastrados manualmente em WhatsApp > Configuração da API > campo "Para".
   Foi por isso que precisamos cadastrar o número pessoal (+55 31 99995-0225) como destinatário de
   teste antes do primeiro envio funcionar — sem esse cadastro a Meta rejeita a chamada.

2. **Token de acesso temporário expira em 24h.**
   O token gerado via App Dashboard > Início Rápido é um token de usuário temporário (24h de
   validade) — origem do problema recorrente de "token expirou, gera outro". A solução definitiva é
   gerar um token de **System User permanente** em Business Settings > Usuários do Sistema, que não
   expira nesse ciclo curto.

3. **Limite de volume por camada (messaging tier).**
   Todo número novo — verificado ou não — começa numa camada inicial (tipicamente 250 conversas
   iniciadas pela empresa a cada 24h). O limite sobe automaticamente conforme volume de uso e
   quality rating do número, independente de verificação. A verificação de negócio ajuda a começar
   em camadas mais altas e reduz risco de bloqueio por "atividade suspeita" em número novo.

4. **Janela de 24h para mensagem livre.**
   Textos livres (como os scripts desta pasta enviam) só podem ser enviados dentro de 24h após a
   última mensagem do usuário. Fora dessa janela é obrigatório usar um Message Template
   pré-aprovado pela Meta (HSM). Essa regra vale com ou sem verificação de negócio.

5. **Selo de verificação e nome de exibição.**
   Sem Verificação de Negócio, o número não recebe o selo verde oficial, e o nome de exibição do
   WhatsApp Business passa por uma aprovação separada (Display Name Review). É mais uma questão de
   confiança do usuário final do que uma restrição técnica de envio.

6. **Sair do modo teste para atender clientes reais.**
   Para atender qualquer número (não só os cadastrados manualmente), o app precisa sair do modo
   Development — isso é feito solicitando **App Review** para a permissão
   `whatsapp_business_messaging`, ou usando o fluxo de **Embedded Signup** (login via Meta/Facebook,
   já implementado no fork do aptus-chat — ver sessão de 06/07), que em geral já resolve esse passo
   automaticamente ao conectar o WABA do cliente final. A Verificação de Negócio costuma ser
   pré-requisito para o App Review ser aprovado.

## Conclusão prática pra APTUS
- **Para testes internos** (o que fizemos): a Meta libera tudo sem burocracia — só exige cadastrar
  manualmente os números de teste.
- **Para uso real com clientes do aptus-chat**: os próximos passos são (1) Verificação de Negócio no
  Business Manager, (2) token de System User permanente em vez do temporário de 24h, e (3) sair do
  modo Development via App Review ou via Embedded Signup por cliente.

## Scripts nesta pasta
- `send_test_whatsapp.sh` — recriação do disparo único original: envia "teste 1" para o número
  pessoal cadastrado como destinatário de teste.
- `send_whatsapp.sh` — versão reutilizável, aceita número e mensagem como argumentos
  (`./send_whatsapp.sh 5531999999999 "mensagem"`).

Ambos usam as credenciais atuais de `/Users/ederambrosio/Projetos/Aptus/aplicativo-aptus-chat-dados.md`
(Phone Number ID e token do app aptus-chat-teste). O token é temporário — se expirar, gere um novo em
developers.facebook.com e atualize os scripts.
