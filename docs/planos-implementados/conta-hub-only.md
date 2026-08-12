# Conta "só Hub" no aptus-chat

> **Status: implementado em 2026-08-12.** Dois desvios em relação ao plano abaixo, ambos ditados pelo código:
>
> 1. **A allowlist do gate ficou com um controller, não dois.** `Api::V1::AccountsController` herda direto de `Api::BaseController` e nunca passa por `Api::V1::Accounts::BaseController` — listá-lo seria entrada morta. O payload de boot do dashboard continua chegando normalmente.
> 2. **`hub_only?` precisou coagir para booleano.** `ActiveModel::Type::Boolean.cast(nil)` devolve `nil`, não `false`, e o `.compact` do `serialized_for_account` então descartaria o campo do JSON. Funcionaria por ser falsy, mas o guard do roteador merece um valor estável — daí o `|| false`.
>
> Verificação executada: eslint e rubocop limpos nos arquivos tocados; `routeHelpers.spec.js` e `HubTester.spec.js` passando; `spec/requests/api/v1/accounts/` com 51 exemplos e 2 falhas **pré-existentes** (specs de `available_slots` da Agenda, dependentes de data — confirmado via `git stash`). O gate foi validado com um request spec temporário (11 exemplos, todos passando): conta `hub_only` devolve 404 em conversations, contacts, crm_deals, agenda e inboxes, mantém `/api/v1/accounts/:id` e `/api/v1/profile` com `hub_only: true`, e contas comuns seguem intactas. O spec foi removido depois, conforme a convenção do `CLAUDE.md` de não adicionar specs sem pedido.
>
> **Não executado:** a verificação manual na aplicação rodando (itens 1 a 4 da seção Verificação). Vale fazer antes de provisionar a Izzy — em especial abrir a aba Desempenho, que é a única forma de saber se o `bot_id` está correto.

## Context

A Izzy Cannabis já usa Kommo para CRM e mensageria — não precisa de nada do Chatwoot. O que ela precisa do aptus-chat é só o **Hub**: gestão do bot Botpress (Desempenho, Testar, Pagamentos). Outros clientes futuros vão cair no mesmo padrão, então a solução precisa ser **por conta, ligada no Super Admin**, sem mudança de código por cliente.

Hoje isso não existe. O estado atual do produto:

- O Hub é o **único** item condicional da sidebar (`hasAptusHub` = `aptus_hub.enabled && aptus_hub.bot_id`). Inbox, Conversas, CRM, Contatos e Settings aparecem sempre — o cliente veria cinco seções vazias.
- Depois do login o roteador manda para `accounts/:id/dashboard`, que é a home de **conversas**, não o Hub.
- A aba Pagamentos exige `administrator` (`AptusHubPolicy#payments?`) — e ser admin abre Settings inteiro: inboxes, agentes, automações, integrações, billing.
- O grupo **Agenda** vem colado no Hub na sidebar (mesma condição `hasAptusHub`), e a Izzy não usa agenda.
- Não há papel "só Hub": `CustomRole::PERMISSIONS` tem 6 permissões e nenhuma delas é do Hub, e o recurso é Enterprise desligado por padrão.

**Resultado esperado:** uma conta marcada como `hub_only` mostra exclusivamente o grupo Hub, cai direto nele no login, e bloqueia o resto da API. Um único usuário `administrator` por conta, enxergando tudo do Hub inclusive Pagamentos.

## Decisões

| Decisão | Escolha | Por quê |
|---|---|---|
| Onde mora o flag | `hub_only` dentro de `Account#aptus_hub` (`store_accessor` sobre `custom_attributes`) | Já existe a infra; **sem migration**; replicável via Super Admin como os outros 13 campos |
| Papel do cliente | 1 usuário único, `administrator` | Pagamentos exige admin; o `hub_only` é que tira Settings do caminho — não mexo na `AptusHubPolicy`, que já é usada por contas existentes |
| Agenda | Fora | Pedido explícito; sai de graça porque o menu hub_only devolve só o grupo Hub |
| Bloqueio | UI + roteador + backend | "Só ter acesso ao HUB" — esconder na sidebar não basta se a rota e a API continuam respondendo |

Contas atuais não são afetadas: `hub_only` default `false`.

## Mudanças

### Backend

**1. `app/services/aptus_hub/account_config.rb`** — o flag e sua exposição.

```ruby
def hub_only?
  ActiveModel::Type::Boolean.new.cast(raw[:hub_only])
end
```

E incluir no `serialized_for_account` (hoje devolve só `enabled` e `bot_id`) — **é este método que alimenta a sidebar**, via `_account.json.jbuilder:21`. Sem isso o frontend nunca vê o flag. Cuidado com o `.compact` no fim: `false` sobrevive, `nil` não — usar `hub_only?`, que sempre devolve booleano.

**2. `app/fields/aptus_hub_config_field.rb`** — adicionar ao `FIELDS`:

```ruby
{ key: :hub_only, label: 'Hub only (cliente vê apenas o Hub)', type: :boolean, default: false }
```

Colocar logo depois de `:enabled`. O template do Administrate já renderiza `:boolean` (é o tipo de `enabled`), então não há view nova.

**3. `app/views/api/v1/models/_user.json.jbuilder`** — dentro do bloco `json.accounts`, adicionar:

```ruby
json.hub_only AptusHub::AccountConfig.new(account_user.account).hub_only?
```

Necessário porque o guard do roteador (`routes/index.js`) decide a rota de destino a partir de `user.accounts`, que **hoje não carrega `custom_attributes`** — só id/name/status/onboarding_step/role/permissions. Sem essa linha o primeiro redirect pós-login não tem como saber que a conta é hub_only. Sem N+1 relevante: `custom_attributes` já vem carregado com a conta.

**4. `app/controllers/api/v1/accounts/base_controller.rb`** — o gate real:

```ruby
before_action :ensure_hub_only_scope!
```

Quando `AptusHub::AccountConfig.new(Current.account).hub_only?`, permitir só uma allowlist de controllers e responder 404 no resto. A allowlist é curta porque a mudança 5 corta as chamadas de boot da sidebar:

- `Api::V1::Accounts::AptusHubController`
- `Api::V1::Accounts::AccountsController` (o `accounts/get` do `App.vue`)

Fora do escopo deste controller e portanto não afetados: `/api/v1/profile` (`setUser`) e ActionCable. Os controllers de Agenda (`AgendaProfessionalsController`, `AgendaEventTypesController`, `AgendaAppointmentsController`) ficam de fora da allowlist de propósito.

> A allowlist é o ponto de maior risco do plano — se faltar um controller que o app busca no boot, a tela quebra. A verificação abaixo cobre isso lendo o log do Rails.

### Frontend

**5. `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`**

- `isHubOnly` computed ao lado de `hasAptusHub` (linha ~85), lendo `aptusHubConfig.value.hub_only` com o mesmo cast tolerante a string que `hasAptusHub` já faz para `enabled`.
- No `menuItems` (linha ~333): early-return com apenas o grupo **Hub** (Desempenho, Testar, e Pagamentos — este último já condicionado a `isAdmin`, que o cliente é). Sem Agenda, sem Settings.
- No `onMounted` (linhas 228-236): pular os seis dispatches (`labels/get`, `inboxes/get`, `notifications/unReadCount`, `teams/get`, `attributes/get`, `customViews/get` ×2) quando `isHubOnly`. É isso que mantém a allowlist do item 4 pequena.

**6. `app/javascript/dashboard/helper/routeHelpers.js`** — em `validateActiveAccountRoutes`, antes da checagem de permissões:

```
se currentAccount.hub_only e a rota não é do Hub -> `accounts/${accountId}/hub`
```

`validateLoggedInRoutes` já tem o `currentAccount` em mãos e roda no `beforeEach` do roteador, então esse único ponto cobre tanto o pouso pós-login quanto URL digitada na mão (`/app/accounts/:id/dashboard`, `/crm`, `/settings/inboxes`…). Reaproveitar o padrão de `isAConversationRoute` para um `isAHubRoute` com os nomes de `routes/dashboard/hub/routes.js` — e não incluir os nomes de agenda (`hub_agenda_*`) na lista.

**7. `app/javascript/dashboard/routes/index.js`** — no guard onde hoje se calcula `target` (linha ~44), usar `'hub'` no lugar de `'dashboard'` quando `userAccount?.hub_only`. É o caso de entrada sem rota (`to.name === 'no_accounts' || !to.name`).

O menu de perfil (avatar) fica como está — é onde o cliente troca a senha.

## Runbook de provisionamento (replicável)

1. **Super Admin → Accounts → New.** Nome do cliente, locale `pt_BR`, status `active`.
   > Usar o formulário do Super Admin, **não** o `AccountBuilder` do console: o builder grava `onboarding_step: 'account_details'`, e o guard do roteador força um admin nessa condição para o wizard de onboarding (dados da conta → setup de inbox) antes de qualquer outra tela. A conta criada pelo Administrate nasce sem `onboarding_step`.
2. **No mesmo formulário, seção "Aptus Hub":** `enabled` ✓, `hub_only` ✓, `bot_id` (Botpress), `bot_name`, `status`, `ai_model`, `go_live_on`, `monthly_fee`, `bot_fixed_cost` (10), `currency` BRL, `payment_day`, `markup_rate` 0.14, `tax_rate` 0.07, `webchat_script_url` (sem ela a aba Testar mostra estado vazio).
3. **Super Admin → Account Users:** vincular o usuário único à conta com role `administrator`. Criar o usuário antes em Super Admin → Users se ainda não existir.
4. **Senha:** o cliente recebe o e-mail de confirmação do Devise. Isso depende de `SMTP_ADDRESS` configurado — **sem SMTP nenhum e-mail sai, e a falha é silenciosa** (só log). Confirmar o envio ou definir a senha pelo Super Admin.
5. **Conferir antes de entregar:** logar como o cliente, confirmar que cai em `/app/accounts/:id/hub` e que a sidebar tem só o grupo Hub.

### Pontos de atenção herdados (não são regressões deste plano)

- `bot_id` não é validado contra o Botpress Cloud. Erro de digitação vira "Não foi possível buscar os dados do bot agora". Abrir Desempenho e ver número real antes de entregar.
- As credenciais do Botpress são **globais** (`BOTPRESS_API_KEY`, `BOTPRESS_WORKSPACE_ID`) — o bot da Izzy precisa estar no workspace da Aptus para o analytics resolver.
- A aba Pagamentos dispara até 12 chamadas HTTP externas (6 meses × analytics + cotação), sem cache nem circuit breaker; Botpress ou AwesomeAPI lentos derrubam a tela inteira.
- A conta nova continua criando o "Funil de Atendimento" com 6 estágios (`after_create_commit :setup_crm_default_pipeline` em `app/models/account.rb:119`). Fica invisível no modo hub_only — não vale a pena suprimir.

## Verificação

1. `./dev.sh` e criar uma conta de teste com `hub_only` ligado, seguindo o runbook.
2. Logar como o usuário dessa conta e confirmar: pouso em `/app/accounts/:id/hub`; sidebar só com Hub; Desempenho, Testar e Pagamentos abrindo.
3. **Testar o bloqueio:** digitar na barra de endereço `/app/accounts/:id/dashboard`, `/crm`, `/settings/inboxes` e `/hub/agenda` — todos devem cair em `hub_performance`.
4. **Fechar a allowlist:** com a aba Network aberta e acompanhando `/tmp/overmind-aptus.log`, recarregar o Hub e confirmar que nenhuma chamada da API responde 404/403. Qualquer 404 inesperado é controller faltando na allowlist do item 4.
5. **Não-regressão:** logar numa conta existente que usa o produto inteiro (conta 2, WhatsApp) e confirmar sidebar completa, conversas e CRM funcionando. Depois numa conta com Hub ligado e `hub_only` desligado, confirmar que Hub **e** Agenda continuam aparecendo.
6. `pnpm eslint` e `bundle exec rubocop -a`.
