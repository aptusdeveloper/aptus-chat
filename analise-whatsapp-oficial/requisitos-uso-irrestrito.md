# Requisitos para usar a WhatsApp Cloud API sem limitações (modelo "estilo Kommo")

> Continuação de `analise.md`. Aqui o objetivo é responder diretamente: **o que falta para eu poder
> cadastrar qualquer número de cliente na aptus-chat (telefone + Phone Number ID + WABA ID + token) e
> mandar mensagem pra qualquer destinatário, sem as restrições do modo Development?**

## 0. Resumo executivo

> **Contexto atualizado**: o objetivo imediato é criar uma WABA só para **testes internos** — não
> para atender clientes reais ainda. A verificação de negócio "de verdade" e o cadastro formal como
> Tech Provider ficam para uma fase futura, quando a APTUS tiver sua própria conta verificada e for
> conectar clientes de verdade. Este documento por isso separa tudo em **Fase 1 (teste, agora)** e
> **Fase 2 (produção, depois)** — ver seção 7 para o checklist dividido dessa forma. As seções 1–6
> continuam valendo como referência de conceito e requisito, só a ordem/urgência muda.

- **A funcionalidade de "colar credenciais manualmente" já existe no código do aptus-chat.** Não é
  preciso desenvolver nada para isso — é um recurso nativo herdado do Chatwoot (ver seção 1). É esse
  caminho que serve para a fase de teste.
- **Para a fase de teste, o que falta não é burocracia pesada**: basta um Business Manager (mesmo não
  verificado), um App Meta com produto WhatsApp, um número de telefone real adicionado e verificado
  por SMS, e um token de System User. Isso já derruba a restrição dos "5 números" (que é exclusiva do
  número de teste gratuito da Meta) e permite mandar mensagem para qualquer destinatário, dentro do
  teto de 250 conversas/24h — suficiente para testar o fluxo completo.
- **Para a fase de produção** (múltiplos clientes reais), aí sim entram 3 frentes mais burocráticas:
  (1) Verificação de Negócio formal do Business Manager, (2) App Review para Advanced Access, e
  (3) — a mais importante e a que muda a resposta — **enquadramento como ISV/Tech Provider**, porque
  nessa fase a aptus-chat passa a atender **múltiplos clientes diferentes**, não um único negócio de
  teste.
- **Comprar uma conta/BM "já verificada"** é tecnicamente possível de achar no mercado, mas viola os
  Termos do Meta Business Manager, não elimina o processo de App Review, e coloca a operação inteira
  (todos os clientes) em risco de banimento em cascata. Como o objetivo agora é só teste, **não há
  motivo nenhum para essa rota** — dá pra testar tudo com uma verificação básica ou até sem
  verificação nenhuma (seção 3.1). Existe também uma alternativa **legítima e mais rápida** para
  quando chegar a hora de verificar de verdade: **Partner-led Business Verification (PLBV)** — ver
  seção 6.
- A decisão que realmente importa pra fase de produção não é técnica, é de modelo de negócio: **quem
  é o "dono" do WhatsApp Business Account de cada cliente perante a Meta** — a APTUS ou o próprio
  cliente? Isso determina se dá pra fugir do fluxo de login/popup da Meta ou não (seção 2).

---

## 1. O que já existe no código da aptus-chat

A aptus-chat é um fork do Chatwoot, e o Chatwoot já implementa **os dois caminhos** para conectar um
número da Cloud API — ambos gravam o mesmo formato de dados (`Channel::Whatsapp#provider_config`):

```ruby
# app/services/whatsapp/channel_creation_service.rb
def build_provider_config
  {
    api_key: @access_token,
    phone_number_id: @phone_info[:phone_number_id],
    business_account_id: @waba_info[:waba_id],
    source: 'embedded_signup'
  }
end
```

- **Caminho manual** (`provider: 'whatsapp_cloud'`, sem `source: 'embedded_signup'`): é literalmente o
  que você já quer — um formulário onde se cola `phone_number`, `phone_number_id`,
  `business_account_id` (WABA ID) e `api_key` (token). O model já suporta isso
  (`app/models/channel/whatsapp.rb:162-166`, `should_auto_setup_webhooks?` diferencia os dois casos) e
  dispara `setup_webhooks` automaticamente ao criar. **Esse caminho não pede login de Facebook dentro
  da aptus-chat.**
- **Caminho Embedded Signup** (`app/services/whatsapp/embedded_signup_service.rb`,
  `useWhatsappEmbeddedSignup.js`): já está implementado ponta a ponta — abre um popup do SDK do
  Facebook (`FB.login()`) dentro da própria aptus-chat, troca o `code` por um token
  (`Whatsapp::TokenExchangeService`), busca os dados do número (`Whatsapp::PhoneInfoService`) e cria o
  canal. **Esse caminho pede login de Meta, mas do cliente, num popup embutido — não é redirecionamento
  pra fora do produto.**

Ou seja: **o código não é o gargalo.** O que falta é o lado Meta — ter um App + Business Manager que
te dão o direito de gerar tokens que funcionam sem restrição, para qualquer número, para qualquer
cliente.

---

## 2. A decisão que precisa ser tomada primeiro: de quem é o WABA?

| | **Modelo A — Direto por cliente** | **Modelo B — Agência (BM central da APTUS)** | **Modelo C — Tech Provider (Embedded Signup)** |
|---|---|---|---|
| Quem é o "dono" do WABA na Meta | O próprio cliente (Business Manager dele) | A APTUS (um único Business Manager) | O cliente, mas gerenciado via delegação para o app da APTUS |
| Quem verifica o negócio | Cada cliente verifica o próprio BM | Só a APTUS verifica (uma vez) | Só a APTUS verifica (uma vez) |
| Fluxo de conexão na aptus-chat | Colar credenciais manualmente (já existe) | Colar credenciais manualmente (já existe) | Popup embutido, sem sair da aptus-chat (já existe) |
| Precisa a APTUS virar "Tech Provider" na Meta? | **Não** | **Sim, na prática** (ver seção 5) | **Sim, obrigatório** |
| Esforço de setup por cliente novo | Alto (cliente/você mexe no BM dele) | Baixo (só adicionar número no BM da APTUS) | Baixo (cliente clica e autoriza) |
| Risco concentrado | Baixo (problema de 1 cliente não afeta os outros) | **Alto** (1 cliente problemático pode arrastar o BM inteiro) | Médio (Meta trata cada WABA separadamente, mesmo com app compartilhado) |
| Portabilidade se o cliente sair | Total (o número já é dele) | Baixa (precisa migrar WABA, exige OTP do cliente) | Alta (WABA já é do cliente) |
| Alinhado com o que a Meta exige de SaaS multi-cliente | Sim (você não é ISV para esse número) | **Zona cinzenta / não compliant** | **Sim — é o caminho que a Meta desenhou pra isso** |

O pedido original ("colar telefone, phone number ID, WABA ID e token, sem precisar logar no
Facebook dentro da aptus-chat") **bate exatamente com o Modelo A ou B**, tecnicamente. O problema é
que o **Modelo B tem um porém regulatório grande**, explicado na seção 5 — é o motivo pelo qual eu não
recomendaria construir a operação real de vocês em cima dele.

---

## 3. Requisitos da Meta, passo a passo (comuns a qualquer modelo)

### 3.1. Business Manager + Verificação de Negócio
- Precisa de uma conta no [Meta Business Manager](https://business.facebook.com) com CNPJ, endereço e
  telefone consistentes entre: cadastro no Business Manager, documento de constituição da empresa,
  site oficial e comprovante de endereço.
- Documentos tipicamente pedidos: documento de constituição/CNPJ, comprovante de endereço, e às vezes
  confirmação de domínio do site.
- Prazo real: 1–5 dias úteis com documentação limpa e consistente; pode chegar a 2–4 semanas se os
  dados baterem errado entre as fontes.
- **Sem verificação**, o WABA fica no que a Meta chama de "Limited/Standard Access": ainda dá pra
  mandar mensagem para qualquer número (não só os 5 de teste) mas o teto é de **250 conversas
  iniciadas pela empresa a cada 24h**, e sem selo verde/nome verificado.

### 3.2. App Meta + produto WhatsApp
- Criar um app tipo "Business" em developers.facebook.com, adicionar o produto WhatsApp.
- Isso já dá o WABA de teste gratuito (`+1 555 xxx`) e permissões `whatsapp_business_messaging` +
  `whatsapp_business_management` em modo **Standard Access** — funciona para qualquer número real
  adicionado ao WABA, só limitado pelo teto de 250 conversas/24h enquanto não sobe de tier.

### 3.3. App Review → Advanced Access (isso é o que remove de vez a lista de 5 números)
- Standard Access já livra da lista de 5 destinatários manuais **desde que o número seja um número
  real verificado no WABA** (não o número de teste `+1 555`). O que ficou registrado no `analise.md`
  como "Cenário A restrito a 5 números" é especificamente o número de teste gratuito da Meta.
- Advanced Access (via App Review) é o que aumenta o teto de mensagens além dos 250/24h e permite
  pular direto para tiers maiores mais rápido. Para solicitar:
  - Gravar um vídeo mostrando o app enviando mensagem via `whatsapp_business_messaging` e recebendo
    resposta no WhatsApp.
  - Criar e usar um template para demonstrar `whatsapp_business_management`.
  - Preencher formulário descrevendo o caso de uso.
- **Direct Developers (uso interno, um único negócio) não precisam de Advanced Access** para operar
  sem restrição de destinatário — só Solution Providers/Tech Providers são obrigados a ter Advanced
  Access. Isso reforça a diferença entre Modelo A/B (não-ISV) e Modelo C (ISV).

### 3.4. Token permanente (System User)
- Token de "Início Rápido" expira em 24h — **não usar em produção**.
- Gerar via **Business Settings > Usuários do Sistema**: criar um System User com papel Admin,
  atribuir o app como asset (Full Control), atribuir cada WABA como asset também, e gerar o token
  marcando `whatsapp_business_messaging` + `whatsapp_business_management`.
- Esse token não expira sozinho (só se revogado manualmente ou se o System User for removido).
- **Importante para o Modelo B**: cada WABA novo (cada cliente novo) precisa ser explicitamente
  adicionado como asset do System User antes do token conseguir operar naquele número — não é
  automático só por estar no mesmo Business Manager.

### 3.5. Registro/verificação do número de telefone
- Se o número já estiver ativo no app comum do WhatsApp, precisa ser removido de lá antes de entrar
  na Cloud API — **a menos que** se use o recurso de **Coexistence**, que permite manter o WhatsApp
  Business App e a Cloud API operando ao mesmo tempo no mesmo número.
- Verificação do número é feita por código SMS/voz (endpoint `/register` — é exatamente o que
  `Whatsapp::FacebookApiClient#register_phone_number` já faz no código de vocês).

---

## 4. Limites de mensageria (tiers) — como sobem, com ou sem verificação

| Nível | Conversas iniciadas pela empresa / 24h |
|---|---|
| Inicial (não verificado / Standard) | 250 |
| Após qualidade + volume consistentes | 1.000 |
| Próximo degrau | 10.000 |
| Próximo degrau | 100.000 |
| Topo | Ilimitado |

- A subida é **automática**, baseada em volume de uso e *quality rating* (não em ter feito
  verificação — verificação só ajuda a começar mais alto e acelera a confiança inicial da Meta no
  número).
- Isso é **por número de telefone**, não por app — cada número novo de cada cliente novo começa do
  zero nesse contador, mesmo que o token/app por trás já seja o mesmo de outros clientes "avançados".
- Regras que continuam valendo em qualquer tier: janela de 24h para texto livre (fora dela, obrigatório
  usar Message Template pré-aprovado/HSM), e Display Name Review separado por número (selo
  verde/nome oficial, não é bloqueio técnico de envio).

---

## 5. O ponto mais importante: obrigatoriedade de Tech Provider para ISVs

> **Isso é uma preocupação de Fase 2 (produção), não da WABA de teste que você quer criar agora.**
> Uma WABA de teste, usada internamente pela própria equipe da APTUS para validar o fluxo técnico,
> não enquadra a APTUS como ISV — não tem "outro negócio" sendo atendido ainda. Essa seção fica aqui
> como referência para quando a fase de produção chegar.

Isso é o que muda a resposta pro caso de vocês e por isso está destacado à parte.

- A Meta define **ISV (Independent Software Vendor)** como qualquer plataforma que oferece o canal
  WhatsApp como parte de um produto usado por **outras empresas** para falar com os clientes finais
  delas. Isso descreve exatamente a aptus-chat: um cliente como a Gurgel Veículos usa a aptus-chat
  para atender os clientes *dele*.
- Desde 2025, a Meta tornou **obrigatório** que todo ISV se registre no **Tech Provider Program** para
  continuar podendo enviar mensagens via WhatsApp Business Platform — sem esse cadastro, o envio é
  bloqueado. Diferentes parceiros (Twilio, Infobip) registraram prazos de migração entre março e
  junho de 2025 — ou seja, esse prazo **já passou** em relação à data atual.
- O programa Tech Provider foi desenhado justamente em torno do **Embedded Signup**: o cliente
  autoriza o WABA dele delegando acesso ao app da APTUS, sem a APTUS precisar "possuir" o Business
  Manager do cliente. É o Modelo C — e é exatamente o que já está implementado no código
  (`embedded_signup_service.rb` + `useWhatsappEmbeddedSignup.js`).
- **Implicação prática para o Modelo B** (todos os números de clientes dentro de um único Business
  Manager da APTUS, sem o cliente nunca interagir com a Meta): esse desenho é o que se fazia antes de
  2025 por agências e ainda funciona tecnicamente enquanto o token for válido, mas **não é o caminho
  que a Meta reconhece hoje para uma plataforma que atende múltiplos negócios** — o risco não é só
  "feio", é de a conta ser enquadrada como uso não conforme se a Meta identificar o padrão (múltiplos
  negócios não relacionados operando sob um único Business Manager/app sem registro como Tech
  Provider).
- **Boa notícia**: Embedded Signup (Modelo C) entrega exatamente os mesmos três dados que você queria
  digitar manualmente — WABA ID, Phone Number ID e token — só que capturados automaticamente via
  popup, sem seu time precisar entrar no Meta Business Manager toda vez que um cliente novo chegar.
  Do ponto de vista de UX, o cliente nunca "sai" da aptus-chat; o que ele vê é um popup da Meta pedindo
  para autorizar o número dele, do mesmo jeito que provavelmente ele viu ao conectar o número dele na
  Kommo.

**Recomendação**: para uso real com múltiplos clientes, ir de Modelo C (Tech Provider + Embedded
Signup), que já está implementado. Reservar o formulário manual (Modelo A) para casos em que o
próprio cliente já tem um Meta App/Business Manager verificado e só entrega as credenciais prontas —
nesse caso a APTUS não é a ISV daquele número, e não há problema de conformidade.

---

## 6. E comprar uma conta/Business Manager já verificada, só para testar?

Existe um mercado informal (inclusive brasileiro) vendendo "BM verificada" para destravar a API sem
passar pela verificação própria. Pesquisando sobre isso:

- Isso **viola os Termos de Serviço do Meta Business Manager** — contas e verificações não são
  transferíveis, e a Meta pode revogar retroativamente a verificação de uma BM se detectar troca de
  titularidade/documentos incompatíveis com o histórico da conta.
- Não elimina o App Review — comprar uma BM verificada só resolve a *verificação de negócio*; ainda
  seria necessário ter um app com Advanced Access aprovado para o "qualquer número, sem limite" — e
  App Review avalia o app e o caso de uso, não a BM.
- Risco de banimento em cascata: se a BM comprada for suspensa (comum, já que a origem/documentos
  raramente resistem a uma auditoria da Meta), **todos os WABAs/números conectados a ela caem
  junto** — incluindo os de clientes reais, não só os de teste.
- Mesmo "só para testar antes de ir pra produção": o app fica associado a essa BM no histórico da
  Meta; se ela for banida depois, isso pode manchar a reputação do App ID usado, mesmo que
  depois vocês migrem para uma BM própria.

**Alternativa legítima e mais rápida, que existe pra exatamente esse problema** — pular a burocracia
de verificação manual sem comprar nada de terceiro:

- **Partner-led Business Verification (PLBV)**: ao conectar o WABA através de um parceiro
  Meta (Tech Provider) que já tem esse selo — como 360dialog, Twilio, Gupshup, Infobip — o parceiro
  consegue verificar o negócio do cliente final de forma acelerada (minutos/poucos dias) em nome da
  Meta, sem o cliente (ou vocês) passar pelo processo manual de Security Center. É o caminho oficial
  que a própria Meta recomenda para acelerar isso, sem ferir os termos de uso.
- Isso é compatível com o Modelo C (Tech Provider + Embedded Signup): ao ficarem Tech Provider, vocês
  também herdam a possibilidade de oferecer PLBV para os próprios clientes da aptus-chat.

---

## 7. Checklist prático recomendado

### Fase 1 — WABA de teste (o que fazer agora)

1. Criar um Business Manager (pode ser um já existente da APTUS, mesmo sem verificação) e um App tipo
   "Business" em developers.facebook.com, adicionando o produto WhatsApp.
2. Adicionar um número de telefone real ao WABA (não precisa ser o número final de produção) e
   verificar por SMS/voz (`Whatsapp::FacebookApiClient#register_phone_number` já faz isso no código).
3. Gerar um **token de System User permanente** (Business Settings > Usuários do Sistema), atribuindo
   o app e o WABA de teste como assets — evita o problema recorrente do token de 24h.
4. Colar `phone_number` + `phone_number_id` + `business_account_id` (WABA ID) + `api_key` no
   formulário manual que já existe na aptus-chat (`Channel::Whatsapp`, `provider: 'whatsapp_cloud'`).
5. Testar o fluxo completo (webhook de entrada, envio de saída, integração com Botpress) — sem se
   preocupar ainda com Verificação de Negócio, App Review/Advanced Access ou Tech Provider. O teto de
   250 conversas/24h é mais do que suficiente para essa etapa.
6. **Não comprar BM/conta verificada de terceiros** para essa fase — não há necessidade nenhuma, o
   teste funciona com uma verificação básica ou até sem verificação.

### Fase 2 — Produção com clientes reais (quando chegar a hora)

7. **Decidir o modelo** (seção 2) — recomendo Modelo C (Tech Provider + Embedded Signup), já que é o
   que está implementado e é o único totalmente alinhado com as regras atuais da Meta para SaaS
   multi-cliente.
8. Completar a Verificação de Negócio formal do Business Manager da APTUS (CNPJ + comprovante + site
   consistentes) — ou usar Partner-led Business Verification (PLBV) via um Tech Provider já
   estabelecido para acelerar isso.
9. Inscrever a APTUS no **Tech Provider Program** (developers.facebook.com/docs/whatsapp/solution-providers).
10. Solicitar App Review para `whatsapp_business_messaging` + `whatsapp_business_management` com
    Advanced Access (vídeo de demonstração + formulário de caso de uso).
11. Para cada cliente novo: rodar o fluxo de Embedded Signup já existente na aptus-chat (o cliente
    autoriza via popup da Meta) — ou, se o cliente já tiver seu próprio Meta App/BM verificado e
    preferir não usar o popup, usar o formulário manual (`phone_number` + `phone_number_id` +
    `business_account_id` + `api_key`).
12. Configurar Message Templates para qualquer comunicação fora da janela de 24h.
13. Acompanhar o *quality rating* de cada número para garantir a subida automática de tier (250 →
    1.000 → 10.000 → 100.000 → ilimitado).

---

## Fontes
- [WhatsApp API Prerequisites: Phone, Documents, and Verification — Wati](https://www.wati.io/en/blog/whatsapp-api-prerequisites/)
- [Meta Business Verification for WhatsApp API | 2026 Fix Guide — Zaple](https://zaple.ai/blog/meta-business-verification-whatsapp/)
- [How to Get WhatsApp Business API — 2026 Guide — go4whatsup](https://www.go4whatsup.com/guides/get-whatsapp-business-api/)
- [Meta Advanced Access: Which Permissions Need App Review](https://singhamandeep.com/what-is-meta-advanced-access/)
- [App Review sample submission for WhatsApp Business Platform solution providers — Meta for Developers](https://developers.facebook.com/docs/whatsapp/solution-providers/app-review/sample-submission)
- [Permanent Access Token for WhatsApp Business APIs — Medium](https://turivishal.medium.com/permanent-access-token-for-whatsapp-business-apis-c81e1dfc86c7)
- [Access Tokens Guide — Meta for Developers](https://developers.facebook.com/documentation/business-messaging/whatsapp/access-tokens/)
- [Tech Provider Program overview — Twilio](https://www.twilio.com/docs/whatsapp/isv/tech-provider-program)
- [Tech Provider Program: ISV to Tech Provider Migration — Infobip](https://www.infobip.com/docs/whatsapp/tech-provider-program/isv-to-tech-provider)
- [Meta Tech Partner Migration 2024 — Bird Docs](https://docs.bird.com/applications/channels/channels/supported-channels/whatsapp/how-to/become-a-whatsapp-tech-provider/meta-tech-partner-migration-2024)
- [Become a Tech Provider — Meta for Developers](https://developers.facebook.com/documentation/business-messaging/whatsapp/solution-providers/get-started-for-tech-providers)
- [Embedded Signup overview — Meta for Developers](https://developers.facebook.com/documentation/business-messaging/whatsapp/embedded-signup/overview)
- [WhatsApp Messaging Limits — Meta for Developers](https://developers.facebook.com/documentation/business-messaging/whatsapp/messaging-limits)
- [WhatsApp Messaging Limits 2026: Scale Without Getting Banned — Chatarmin](https://chatarmin.com/en/blog/whats-app-messaging-limits)
- [Meta Business Verification | Client Documentation — 360dialog](https://docs.360dialog.com/docs/resources/meta-business-verification)
- [WhatsApp API without Facebook Business Verification: The New Process — Whatsera](https://whatsera.com/blog/whatsapp-api-without-facebook-business-verification-the-new-process/)
- [Bloqueio no WhatsApp Business: Novas Regras da Meta e Como se Proteger — Bradial](https://bradial.com.br/blog-bloqueio-whatsapp-business-regras-meta-api-oficial/)
- [Banimento WhatsApp Business 2026: A Onda no Brasil — Agathas Web Brasil](https://agathas.com.br/blog/banimento-whatsapp-business-2026-brasil)
