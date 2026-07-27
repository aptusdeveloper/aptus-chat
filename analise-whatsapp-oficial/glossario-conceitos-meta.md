# Glossário — Conceitos do ecossistema Meta para WhatsApp Business Platform

> Guia de referência para entender a "anatomia" da Meta por trás da Cloud API: o que é cada coisa
> (WABA, BM, App, System User...), onde cada uma é criada, e como elas se encaixam. Não é um passo a
> passo — para isso, ver `requisitos-uso-irrestrito.md` (Fase 1 = teste, Fase 2 = produção).

## 1. Visão geral — a hierarquia

Tudo no ecossistema Meta gira em torno de duas "raízes" separadas que depois se conectam:

```
business.facebook.com                          developers.facebook.com
(Meta Business Manager /                        (Meta for Developers)
 "Business Portfolio")
│                                                │
├── Verificação de Negócio (Business             ├── App (ex: "aptus-chat-teste")
│   Verification) — status do BM inteiro         │    ├── App ID / App Secret
│                                                 │    ├── Modo: Development ou Live
├── Usuários (pessoas com login, papéis           │    ├── Produtos adicionados (ex: WhatsApp)
│   Admin/Empregado)                              │    ├── Permissões & Features
│                                                 │    │    (whatsapp_business_messaging,
├── Usuários do Sistema (System Users) —          │    │     whatsapp_business_management)
│   "contas de serviço", geram tokens             │    │    ├── Standard Access (padrão)
│                                                 │    │    └── Advanced Access (via App Review)
├── Assets pertencentes a este BM:                │
│   ├── WhatsApp Business Accounts (WABA)         └── (o App é ele mesmo um "asset" que pode
│   │    ├── WABA A (ex: número de teste)              ser atribuído a um Business Manager)
│   │    │    └── Phone Number(s) + Phone Number ID
│   │    └── WABA B (ex: número real do cliente X)
│   │         └── Phone Number(s) + Phone Number ID
│   ├── Páginas do Facebook
│   ├── Contas de anúncio
│   └── Outros Apps
│
└── (opcional) Cadastro como Tech Provider / Solution Partner
     — um "papel" que o BM/App assume perante a Meta para atender outros negócios
```

**Ideia central**: o **App** (criado em developers.facebook.com) é o que define *quais permissões
existem e em que modo (Dev/Live) elas operam*. O **Business Manager** (criado em business.facebook.com)
é o que *possui os ativos de verdade* (o WABA, o número, o token gerado). Um token só funciona se
combinar as duas coisas: um App com a permissão certa + um System User do BM com acesso àquele WABA.

---

## 2. Meta for Developers (`developers.facebook.com`) e o **App**

- É o painel onde se cria e gerencia **Apps** — o equivalente a um "projeto"/"cliente OAuth" da Meta.
- Cada App tem:
  - **App ID** e **App Secret** — as credenciais que identificam o App nas chamadas de API (usadas,
    por exemplo, em `Whatsapp::FacebookApiClient#build_app_access_token` no código da aptus-chat, que
    monta `"#{app_id}|#{app_secret}"` como um tipo de token de app).
  - **Modo Development vs Live** (botão no topo do painel do App): em Development, só quem tem papel
    de Admin/Developer/Tester no próprio App consegue interagir com ele. É esse modo — não a
    verificação de negócio — que gera a restrição dos "5 números" quando se usa o número de teste
    gratuito da Meta.
  - **Produtos**: você adiciona o produto "WhatsApp" ao App para habilitar os endpoints da Cloud API
    para esse App.
  - **Permissões & Features**: cada permissão (`whatsapp_business_messaging`,
    `whatsapp_business_management`) pode estar em **Standard Access** (nível padrão, liberado sem
    revisão, com limites menores) ou **Advanced Access** (liberado só depois de passar por **App
    Review** — vídeo demonstrando o uso + formulário de caso de uso).
- Um App **não pertence** ao Business Manager por padrão — ele precisa ser explicitamente **atribuído
  como asset** a um Business Manager (Business Settings > Contas > Apps) para que System Users desse
  BM possam gerenciá-lo/gerar tokens para ele.

### App Review
- É o processo de revisão da Meta que decide se um App ganha **Advanced Access** para uma permissão.
- Só é obrigatório para quem quer ultrapassar os limites do Standard Access ou para quem é
  **Solution Provider/Tech Provider** (que são obrigados a ter Advanced Access). Um "Direct Developer"
  usando a API só para o próprio negócio pode nunca precisar disso.

---

## 3. Meta Business Manager / "Business Portfolio" (`business.facebook.com`)

- É a "empresa" dentro do ecossistema Meta — o contêiner que junta pessoas, permissões e ativos
  (WABAs, Páginas, contas de anúncio, Apps, catálogos, etc.).
- **Verificação de Negócio (Business Verification)** é um status do Business Manager como um todo
  (não do App, não do WABA individual): a Meta confere documentos (CNPJ/constituição, comprovante de
  endereço, site) para confirmar que o BM representa uma empresa real. Isso desbloqueia limites
  maiores de mensageria e o selo/nome oficial, mas **não é obrigatório para operar** — dá pra usar a
  Cloud API sem verificação, só com teto mais baixo (250 conversas/24h).
- Dentro de um BM existem:
  - **Usuários** — pessoas com login (dono, admins, funcionários), usadas para administrar o painel.
  - **Usuários do Sistema (System Users)** — ver seção 4.
  - **Assets** — os "ativos" que o BM possui: WABAs, Apps, Páginas do Facebook, contas de anúncio,
    catálogos. Cada asset pode ser atribuído a um System User com um nível de permissão
    (ex: "Full Control" sobre o WABA X).
- Um Business Manager pode possuir **vários WABAs** e **vários Apps** ao mesmo tempo — não há limite
  de 1 para 1. É por isso que, no modelo "agência" descrito em `requisitos-uso-irrestrito.md`, seria
  tecnicamente possível colocar o WABA de vários clientes diferentes dentro do mesmo BM da APTUS.

---

## 4. WABA — WhatsApp Business Account

- É o **contêiner que representa uma conta de WhatsApp Business dentro da Meta**. Não é o número em
  si — é o "guarda-chuva" que:
  - Contém um ou mais **números de telefone** (cada WABA pode ter múltiplos números).
  - Guarda os **Message Templates** (HSMs) aprovados para esse conjunto de números.
  - Tem seu próprio **WABA ID** (o `business_account_id` que aparece em
    `Channel::Whatsapp#provider_config` no código da aptus-chat).
  - É **assinado (subscribed)** por um App — é o que permite o App receber webhooks desse WABA
    (`Whatsapp::FacebookApiClient#subscribe_app_to_waba`, endpoint `/{waba_id}/subscribed_apps`).
  - Pertence a exatamente um Business Manager (o "dono" do WABA).
- **Um WABA de teste** (o número gratuito `+1 555 ...` que a Meta dá por padrão ao criar um App com
  produto WhatsApp) é criado automaticamente e vem com a restrição dos 5 destinatários enquanto o App
  estiver em modo Development.
- **Um WABA "real"** é criado quando se adiciona um número de telefone de verdade (próprio ou de um
  cliente) e se completa a verificação por SMS/voz.

## 5. Phone Number / Phone Number ID

- É o número de telefone específico dentro de um WABA. Tem seu próprio **Phone Number ID** — diferente
  do WABA ID (o WABA pode ter vários números, cada um com seu próprio ID).
- Cada número tem, individualmente:
  - Um **status de verificação** (`code_verification_status`, checado em
    `Whatsapp::FacebookApiClient#phone_number_verified?`).
  - Um **quality rating** (qualidade, baseada em reclamações de usuários/bloqueios).
  - Um **messaging tier** (teto de conversas iniciadas pela empresa a cada 24h — 250 → 1.000 → 10.000
    → 100.000 → ilimitado), que sobe automaticamente com uso e qualidade.
  - Uma configuração de **webhook override** própria — é possível ter vários números no mesmo WABA
    apontando para URLs de callback diferentes (`override_phone_number_callback` no código).
  - Um **Display Name** (nome de exibição no WhatsApp) que passa por uma aprovação separada
    (Display Name Review) — é o que dá o selo verde/nome oficial visível para quem recebe a mensagem.

## 6. Usuário do Sistema (System User)

- É uma espécie de "conta de serviço" dentro do Business Manager — não representa uma pessoa, existe
  só para automações/integrações.
- Criado em **Business Settings > Usuários do Sistema**, com papel Admin ou Employee.
- Recebe **assets atribuídos** (o App, o(s) WABA(s)) com um nível de controle (ex: Full Control).
- É a partir de um System User que se gera o **token permanente** — diferente do token de "Início
  Rápido" do painel do App, que é um token de usuário comum e expira em 24h.
- Um único System User pode ter acesso a **múltiplos WABAs** ao mesmo tempo (desde que cada um seja
  explicitamente adicionado como asset dele) — é assim que um único token consegue operar vários
  números de clientes diferentes no modelo "agência".

## 7. Tipos de token — para não confundir

| Tipo | Onde é gerado | Validade | Uso típico |
|---|---|---|---|
| Token de usuário (Início Rápido) | Painel do App > WhatsApp > Introdução | ~24h (curta) | Só para teste manual rápido — **não usar em produção** |
| Token de usuário de longa duração | Trocado via endpoint OAuth (`/oauth/access_token`) | ~60 dias | Intermediário — pouco usado na prática pra isso |
| Token de System User (permanente) | Business Settings > Usuários do Sistema | Não expira sozinho (só se revogado) | **O recomendado para produção** — usado em `provider_config.api_key` no código |
| Token de App (`app_id\|app_secret`) | Composto localmente a partir do App ID + Secret | Enquanto o App existir | Só para chamadas específicas tipo `debug_token`, não substitui o token de acesso normal |
| `code` do Embedded Signup | Gerado pelo popup `FB.login()` no fluxo de Embedded Signup | Uso único, curtíssimo | Trocado no backend por um token de acesso (`Whatsapp::TokenExchangeService`) |

---

## 8. ISV, Direct Developer, Tech Provider, Solution Partner — os "papéis" possíveis

| Papel | O que significa | Precisa de quê |
|---|---|---|
| **Direct Developer** | Um negócio usa a Cloud API só para si mesmo (seus próprios números, seus próprios clientes finais) | App + WABA próprios. Não precisa virar Tech Provider. Advanced Access é opcional (só se quiser passar dos limites do Standard). |
| **ISV** (Independent Software Vendor) | Uma plataforma/software que **oferece o canal WhatsApp como parte de um produto usado por outras empresas** para elas falarem com os clientes finais *delas* — é a categoria em que a aptus-chat se encaixa quando atende clientes reais | Obrigado (desde 2025) a se inscrever como **Tech Provider** |
| **Tech Provider** | Registro formal na Meta que permite a uma ISV construir a integração técnica (via SDK + Embedded Signup) para conectar WABAs de terceiros ao seu app, com Advanced Access aprovado | App com Advanced Access + Embedded Signup implementado (já existe no código da aptus-chat) |
| **Solution Partner** | Um nível acima do Tech Provider — inclui recursos como linha de crédito e faturamento direto aos clientes pelo uso da API. Processo mais longo | Normalmente só faz sentido para quem vai revender o próprio uso da API (billing), não é necessário só para operar o canal |

## 9. Embedded Signup — o que acontece tecnicamente

- É um fluxo de autorização (parecido com "Login com Facebook", mas roteirizado especificamente para
  WhatsApp) que roda dentro de um **popup do SDK JS da Meta**, sem sair do site que o iniciou.
- Sequência (visível no código: `useWhatsappEmbeddedSignup.js` + `embedded_signup_service.rb`):
  1. O front carrega o SDK do Facebook e chama `FB.login()` com uma **Configuration ID** específica
     para WhatsApp (`window.chatwootConfig.whatsappConfigurationId`).
  2. O usuário (o cliente que está conectando o número dele) faz login/autoriza no popup.
  3. O popup devolve, por dois canais diferentes (por isso o código espera os dois): um `code`
     (via `FB.login()`) e um evento `postMessage` com `business_id`, `waba_id`, `phone_number_id`.
  4. O backend troca o `code` por um **access token** (`Whatsapp::TokenExchangeService`), busca
     detalhes do número (`Whatsapp::PhoneInfoService`) e cria o canal com esses dados.
- Quem "loga" nesse fluxo é o **cliente final**, autorizando o WABA dele para o App da APTUS — a
  APTUS nunca vê a senha do cliente, só recebe o resultado (token + IDs).

## 10. Webhooks — dois níveis de assinatura

- **Nível WABA**: o App se inscreve no WABA inteiro (`/{waba_id}/subscribed_apps`) para receber
  eventos (mensagens, status) de todos os números daquele WABA.
- **Nível número**: cada número pode sobrescrever a URL de callback (`override_callback_uri`) — é
  assim que vários números do mesmo WABA podem apontar para lugares diferentes, se necessário.

---

## 11. Resumo — "o que é criado onde"

| Conceito | Criado em | Pertence a | Identificador |
|---|---|---|---|
| App | developers.facebook.com | (pode ser atribuído a um BM) | App ID / App Secret |
| Business Manager | business.facebook.com | Ninguém acima — é a raiz | Business ID |
| WABA | Dentro de um BM (via App/Embedded Signup ou painel) | Um Business Manager | WABA ID |
| Número de telefone | Dentro de um WABA | Aquele WABA | Phone Number ID |
| System User | Business Settings do BM | Aquele Business Manager | — |
| Token permanente | Gerado a partir de um System User | Vale para os assets atribuídos a ele | (string do token) |
| Message Templates | Dentro de um WABA | Aquele WABA | Nome do template |
