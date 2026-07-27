# Guia pratico - o que o cliente precisa ter e fazer para eu desenvolver o WhatsApp oficial dele

> Objetivo: operar o WhatsApp oficial de **um cliente especifico** em producao, usando os ativos Meta do **proprio cliente**, sem pedir login pessoal dele e sem depender de BM/App verificados da APTUS.

## 1. Resposta curta

Sim: se **quem esta verificado e o cliente**, da para desenvolver e colocar em producao o canal dele.

Mas a forma correta muda:

- O **Business Portfolio / Business Manager**, a **WABA**, o **numero**, o **Meta App** e o **token permanente** devem ficar no ambiente do **cliente**.
- A APTUS entra como implementadora tecnica.
- O cliente **nao deve** simplesmente compartilhar o WABA dele com um app da APTUS nao verificado para producao, porque a propria Meta trata isso como acesso a dados de outro negocio, o que exige `Advanced Access` para `whatsapp_business_management`.

Em outras palavras:

- **Certo para este caso**: cliente verificado + app do cliente + WABA do cliente + token do cliente.
- **Errado para este caso**: cliente verificado + WABA do cliente + app da APTUS sem `Advanced Access` / sem fluxo de parceiro.

## 2. O que o cliente precisa ter

Para eu desenvolver e publicar o canal do cliente, ele precisa ter:

1. Um **Meta Business Portfolio / Business Manager** dele.
2. O Business Portfolio **verificado** para operacao de producao recomendada.
3. Um **Meta App** criado no `developers.facebook.com` **dentro do contexto do negocio dele**.
4. O produto **WhatsApp** adicionado nesse app.
5. Uma **WABA** dele.
6. Um **numero de telefone comercial** que sera usado no WhatsApp Business Platform.
7. Esse numero **verificado** na Meta por SMS ou voz.
8. Um **System User admin** no Business Portfolio dele.
9. Um **token permanente** de System User com as permissoes corretas.
10. Um **metodo de pagamento** ativo na WABA para operacao de producao.

## 3. O que eu vou precisar receber do cliente

No modo manual que ja existe na `aptus-chat`, os campos tecnicos obrigatorios para criar o canal sao:

- `phone_number`
- `phone_number_id`
- `business_account_id` (WABA ID)
- `api_key` (token permanente de System User)

Na pratica, para executar a configuracao sem retrabalho, eu preciso receber:

1. **Numero de telefone** em formato internacional. Ex.: `5511999999999`.
2. **Phone Number ID** do numero.
3. **WABA ID**.
4. **Token permanente de System User** com `whatsapp_business_messaging` e `whatsapp_business_management`.
5. **Acesso ao Meta App do cliente** para configurar webhook e colocar o app em `Live mode`.

## 4. O que eu nao devo pedir ao cliente

Para nao invadir o espaco pessoal dele:

- Nao pedir login e senha pessoal do Facebook/Meta.
- Nao pedir acesso ao email pessoal.
- Nao pedir para ele entregar a conta inteira para a APTUS.

O ideal e usar **acesso delegado** ou entao receber so os **identificadores e token tecnico**.

## 5. Forma recomendada de trabalho

### Opcao A - recomendada

O cliente:

- cria e mantem os ativos Meta no ambiente dele;
- adiciona voce ou um usuario tecnico da APTUS com permissao administrativa no Business Portfolio e no Meta App;
- voce faz a configuracao tecnica sem usar a conta pessoal dele.

Essa e a melhor opcao porque:

- o cliente continua dono de tudo;
- voce nao depende de senha pessoal;
- voce consegue configurar app, token, webhook e numero sem ficar pedindo print e codigo toda hora.

### Opcao B - menos invasiva, mas mais trabalhosa

O cliente nao te da acesso administrativo. Em vez disso, ele mesmo:

- cria o app;
- cria a WABA;
- registra o numero;
- gera o token;
- configura o webhook;
- te envia os dados finais.

Essa opcao funciona, mas costuma gerar mais idas e vindas.

## 6. Passo a passo objetivo para passar ao cliente

### Passo 1 - ter o Business Portfolio do cliente pronto

O cliente deve:

1. Entrar em `business.facebook.com`.
2. Garantir que o negocio dele exista como **Business Portfolio**.
3. Concluir a **Business Verification** desse portfolio.

Observacao:

- Para teste, a verificacao nao e estritamente obrigatoria.
- Para producao, e o caminho correto e reduz travas operacionais.

### Passo 2 - criar o Meta App do proprio cliente

O cliente deve:

1. Entrar em `developers.facebook.com`.
2. Criar um novo app do negocio dele.
3. Adicionar o produto **WhatsApp** ao app.

Regra importante:

- O app deve ser **do cliente**, nao da APTUS, se a operacao vai usar o WABA do cliente sem a APTUS estar no modelo formal de parceiro/Tech Provider.

### Passo 3 - criar ou conectar a WABA do cliente

O cliente deve:

1. No app, abrir a area do WhatsApp / API Setup.
2. Criar ou conectar a **WhatsApp Business Account (WABA)** dele.
3. Confirmar que a WABA ficou vinculada ao negocio dele.

### Passo 4 - adicionar o numero oficial

O cliente deve:

1. Escolher o numero que sera usado em producao.
2. Confirmar que esse numero pode receber **SMS ou chamada de voz**.
3. Se o numero estiver preso a outro uso antigo do WhatsApp, resolver isso antes da migracao ou usar a trilha apropriada de coexistencia/migracao.
4. Adicionar o numero na WABA.
5. Validar o numero por codigo.

Observacoes:

- Sem registro valido do numero, nao existe envio/recebimento pela Cloud API.
- O nome de exibicao tambem pode passar por revisao da Meta.

### Passo 5 - criar um System User e gerar token permanente

O cliente deve:

1. Abrir `Business Settings`.
2. Criar um **System User** com perfil admin.
3. Dar a esse System User acesso ao app e a WABA.
4. Gerar um **System User Access Token**.
5. Marcar as permissoes:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`

Resultado esperado:

- esse token sera o `api_key` usado na `aptus-chat`;
- ele e o token correto para producao;
- ele nao e o token curto de 24h do painel rapido.

### Passo 6 - adicionar metodo de pagamento

O cliente deve:

1. Abrir o **WhatsApp Manager** da WABA.
2. Vincular um **metodo de pagamento valido**.

Sem isso:

- a operacao de producao fica incompleta;
- principalmente mensagens cobradas e uso continuo podem falhar ou ficar limitados.

### Passo 7 - colocar o app em Live mode

Depois que o ambiente estiver pronto e o desenvolvimento estiver concluido, o cliente ou voce com acesso delegado deve:

1. Abrir o App Dashboard.
2. Revisar se webhook e numero ja estao corretos.
3. Colocar o app em **Live mode**.

Observacao:

- A documentacao da Meta indica que alguns webhooks nao sao enviados quando o app fica em `Development mode`.

### Passo 8 - configurar o webhook

No app do cliente, deve ser configurado:

1. A **Callback URL** da `aptus-chat`.
2. O **Verify Token** do webhook.
3. A inscricao do app nos eventos do `whatsapp_business_account`.

Sem webhook correto:

- a APTUS pode ate conseguir enviar mensagem;
- mas nao vai receber mensagens de entrada nem eventos de status corretamente.

### Passo 9 - me entregar os dados finais

Quando tudo acima estiver pronto, o cliente deve me passar:

1. `phone_number`
2. `phone_number_id`
3. `business_account_id` (WABA ID)
4. `api_key` permanente do System User

Se eu nao tiver acesso ao App Dashboard dele, o cliente tambem precisa confirmar por escrito que:

5. o app esta em `Live mode`;
6. o webhook esta configurado;
7. o numero foi registrado com sucesso;
8. o metodo de pagamento esta ativo.

## 7. O que eu faco depois que receber isso

Minha parte fica assim:

1. Validar o token e os IDs.
2. Cadastrar o canal manualmente na `aptus-chat`.
3. Informar:
   - `phone_number`
   - `phone_number_id`
   - `business_account_id`
   - `api_key`
4. Validar envio de mensagem.
5. Validar webhook de entrada.
6. Validar status de entrega/leitura.
7. So entao liberar como producao.

## 8. Checklist enxuto para mandar ao cliente

Voce pode mandar isso quase literalmente:

1. Tenha seu **Business Portfolio** criado e **verificado**.
2. Crie um **Meta App** do seu negocio em `developers.facebook.com`.
3. Adicione o produto **WhatsApp** ao app.
4. Crie ou conecte sua **WABA** nesse app.
5. Adicione seu **numero oficial** e valide por SMS/voz.
6. Crie um **System User admin**.
7. Gere um **token permanente** com `whatsapp_business_messaging` e `whatsapp_business_management`.
8. Adicione um **metodo de pagamento** na WABA.
9. Configure o **webhook** da nossa plataforma no app.
10. Coloque o app em **Live mode**.
11. Me envie:
    - numero em formato internacional
    - `phone_number_id`
    - `waba_id`
    - token permanente

## 9. Resposta direta para a sua duvida principal

> "Ele precisa ter a BM verificada, ai ele deve criar a WABA e me passar as credenciais?"

Resposta objetiva:

- **Sim**, para o modelo mais limpo, o cliente deve ter o **Business Portfolio dele verificado**.
- **Sim**, o cliente deve ter a **WABA dele** e o **numero dele** registrados no ambiente Meta dele.
- **Sim**, ele pode te passar as **credenciais tecnicas** finais para o modo manual.
- **Mas** o ideal e ele tambem te dar **acesso tecnico delegado ao app dele**, para voce configurar webhook e publicacao sem pedir a conta pessoal dele.

## 10. Recomendacao final

Para este caso, o roteiro mais correto e menos invasivo e:

1. O cliente cria e verifica o ambiente Meta dele.
2. O cliente cria o app dele e a WABA dele.
3. O cliente te adiciona como acesso tecnico, sem compartilhar login pessoal.
4. Voce configura webhook, token, canal e testes.
5. O canal entra em producao usando **ativos do cliente**, nao ativos da APTUS.

## Fontes oficiais consultadas em 27 de julho de 2026

- Meta - Access Tokens Guide  
  https://developers.facebook.com/documentation/business-messaging/whatsapp/access-tokens/
- Meta - Permissions  
  https://developers.facebook.com/documentation/business-messaging/whatsapp/permissions/
- Meta - WhatsApp Cloud API Get Started  
  https://developers.facebook.com/documentation/business-messaging/whatsapp/get-started
- Meta - WhatsApp Business Accounts  
  https://developers.facebook.com/documentation/business-messaging/whatsapp/whatsapp-business-accounts
- Meta - Register a business phone number  
  https://developers.facebook.com/documentation/business-messaging/whatsapp/business-phone-numbers/registration
- Meta - Business phone numbers  
  https://developers.facebook.com/documentation/business-messaging/whatsapp/business-phone-numbers/phone-numbers
- Meta - Webhooks overview  
  https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview
- Meta - App Review for Solution Providers  
  https://developers.facebook.com/documentation/business-messaging/whatsapp/solution-providers/app-review

## Trechos de documentacao que sustentam este guia

- A Meta diz que, para `direct developer`, use **System User access token**.
- A Meta diz que, se o app acessa **WABAs que nao pertencem ao seu negocio**, ele precisa de **Advanced access** para `whatsapp_business_management`.
- A Meta diz que alguns **webhooks nao sao enviados** se o app continuar em `Dev mode`.
- A Meta diz que, depois de criar a WABA, deve-se **conectar o numero e configurar o metodo de pagamento**.
