# Análise Funcional Completa — Aptus Chat (Aptus Hub)

> **Sobre este documento**: análise funcional do produto, não uma revisão de arquitetura ou tecnologia. Cobre apenas o que está **realmente ativo e acessível** no estado atual do código. Qualquer funcionalidade marcada ou comentada com `APTUS-HIDDEN` foi excluída do catálogo de disponíveis e aparece apenas nas seções que tratam explicitamente de itens ocultos.
>
> **Base da investigação**: leitura direta de modelos, controllers, policies, rotas, componentes Vue, mailers, jobs e configurações do repositório `aptus-chat` (fork do Chatwoot open source, versão base `4.15.1`), incluindo o histórico de commits para confirmar a origem de funcionalidades novas. Nenhum arquivo do projeto foi alterado durante esta análise.
>
> **Contexto da instalação analisada**: `DEPLOYMENT_ENV=self-hosted`, `INSTALLATION_NAME=Aptus` (instância com marca própria), pasta `enterprise/` presente e ativa no código (`ChatwootApp.enterprise? = true`), mas `INSTALLATION_PRICING_PLAN=community`. Isso significa que várias telas "de plano pago" do Chatwoot original existem prontas no código, mas ficam com o conteúdo desligado (sem tela de upgrade, porque a marca não é mais "Chatwoot") até alguém habilitar manualmente a funcionalidade por conta, pelo painel Super Admin.
>
> **Convenção de status usada neste documento**:
> - **Disponível** — confirmado ativo por múltiplas evidências (rota + tela + backend).
> - **Disponível com condição** — existe e funciona, mas depende de uma feature flag, configuração externa ou plano.
> - **Escondido (APTUS-HIDDEN)** — removido da navegação por decisão deliberada da Aptus para o MVP. Não é tratado como disponível em nenhuma tabela de funcionalidades ativas.
> - **Parcialmente implementado** — parte do fluxo existe, parte não.
> - **Necessita validação manual** — não foi possível confirmar 100% apenas lendo o código.
>
> **Atualização de 2026-07-24**: a versão original deste documento foi escrita a partir do estado do código anterior a uma leva de commits de 23–24/07 que não estava refletida no texto (o arquivo ficou "untracked" no working tree e só foi commitado junto do último desses commits). Esta revisão incorpora essas mudanças:
> - `feat(crm): add CRM module...` (08/07) e `feat(crm): custom attributes...` (21/07) — já cobertos pela versão original.
> - `d4977a402 Add CRM automations builder` (23/07) e `03565663a chore(crm-automations): rework condition/action inputs...` (24/07) — o motor de automação do CRM (seção 8.7) **ganhou UI completa** nesse meio tempo; a versão anterior deste doc ainda o descrevia como "só configurável via banco de dados", o que deixou de ser verdade.
> - `4f34c9c27 Add customer Hub MVP` (23/07) e `0803853e8 feat(aptus-hub): expand Hub tabs...` (24/07) — um módulo inteiramente novo, **Aptus Hub**, não existia na versão anterior deste documento. Ver seção 28.
>
> **Atualização de 2026-08-12**: adicionado o modo **conta só-Hub** (`hub_only`), que permite entregar a plataforma a um cliente que usa apenas a gestão do bot — o caso da Izzy Cannabis, que opera CRM e mensageria no Kommo. Ver 3.4 (modelo de acesso) e 28.7 (comportamento e provisionamento). Isso fecha a lacuna nº 2 da seção 27 e o item 12 da seção 26.
>
> **Defasagem conhecida deste documento**: entre 24/07 e hoje o produto ganhou um módulo **Agenda** dentro do Hub (profissionais, procedimentos, consultas, motor de disponibilidade e API consumida pelo bot via integração `aptus-agenda`), além de uma reformulação do construtor de automações do CRM para múltiplos gatilhos. Nenhum dos dois está descrito aqui — as menções a Agenda nas seções 5 e 28.7 são incidentais, não um catálogo. Uma próxima revisão precisa cobrir esses dois módulos.
> - `3d0354b82 fix(sidebar): split CRM into Funil/Automações submenu...` (24/07) — reflete-se na seção 5.
> - `f4d92919b Fix CRM automation action execution` (23/07) — incorporado na seção 8.7.

---

# 1. Resumo executivo

O **Aptus Chat** (nome interno atual, que será renomeado para **Aptus Hub**) é uma plataforma de atendimento ao cliente construída sobre o Chatwoot, um sistema open source de mensageria multicanal. A Aptus manteve toda a base de atendimento do Chatwoot (conversas, contatos, canais, agentes, automações, macros) e está **construindo por cima um módulo próprio de CRM em formato Kanban** — a mudança funcional mais importante feita até agora.

## O que o sistema oferece hoje

1. **Central de atendimento multicanal** — conversas de WhatsApp, e-mail, Instagram, Facebook, Telegram, Line, SMS, chat do site (Web Widget) e canais via API genérica chegam numa caixa de entrada única, com atribuição a agentes/times, respostas prontas, macros, notas internas, menções e histórico completo por contato.
2. **Gestão de contatos** — cadastro, edição, importação/exportação em CSV, mesclagem de duplicados, segmentação por filtros salvos, atributos personalizados, bloqueio.
3. **CRM em Kanban** (funcionalidade nova, criada pela Aptus) — funis de vendas/atendimento com estágios personalizáveis, cards de negócio (“deals”) que já nascem automaticamente vinculados a cada nova conversa, com um motor de automação configurável pela própria interface (gatilhos, condições e ações, incluindo disparo automático de mensagem ao lead).
4. **Administração de agentes, times e distribuição** — convite de agentes, papéis (agente/administrador), times, atribuição automática round-robin, políticas de atribuição mais avançadas (parcialmente ativas).
5. **Automação de atendimento** — regras que reagem a eventos de conversa (criação, atualização, nova mensagem) e disparam ações como atribuir, rotular, mudar status, enviar e-mail, dispararwebhook.
6. **Configurações extensas de conta** — canais, labels, atributos personalizados, automações, bots via webhook, macros, respostas prontas, integrações, papéis customizados (Enterprise), SLA (Enterprise), fluxo de auto-resolução de conversas.
7. **Aptus Hub** (módulo novo, adicionado em 23–24/07) — portal por conta, habilitado manualmente pelo Super Admin, onde agentes/administradores daquela conta acompanham o desempenho do bot Botpress (sessões, mensagens, usuários, custo de LLM/tokens), testam o bot ao vivo via webchat embutido, e veem o detalhamento financeiro mensal (custo do bot + mensalidade Aptus, convertido USD→BRL com markup e imposto configuráveis). Ver seção 28.
8. **Conta só-Hub** (`hub_only`, 12/08) — uma conta pode ser recortada para entregar **apenas** o Hub, escondendo e bloqueando conversas, CRM, contatos e configurações. É o formato para o cliente que contrata só o bot e usa CRM/mensageria em outra ferramenta. Ver 3.4 e 28.7.

## Estágio atual do produto

O sistema está em fase de **adaptação de um produto open source maduro (Chatwoot) para um caso de uso específico da Aptus**, com um MVP claramente recortado: várias funcionalidades nativas do Chatwoot (Relatórios, Central de Ajuda/Portais, Campanhas, Companies, a IA “Captain”/Copilot, assinatura de mensagens) foram **deliberadamente escondidas da navegação** para reduzir escopo, mas continuam existindo no código-fonte, muitas vezes com o backend totalmente funcional por baixo. Em paralelo, a Aptus já construiu duas frentes de funcionalidade própria em ritmo bem ativo (commits diários entre 21 e 24/07): o módulo de **CRM Kanban**, cujo motor de automação ganhou interface completa nesta última leva de commits, e o módulo **Aptus Hub**, que nasceu já como o portal de acompanhamento do bot/faturamento por cliente (ver seção 28) — potencialmente sobrepondo-se em propósito ao projeto `aptus-hub` (Angular, porta 4200) descrito no `CLAUDE.md` do workspace principal como "painel do cliente operador, em desenvolvimento". Essa sobreposição de arquitetura ainda não parece ter sido decidida (ver seção 27).

## O que uma empresa consegue fazer no sistema hoje

- Atender clientes por WhatsApp e outros canais em uma única tela, com toda a equipe podendo colaborar via notas internas, menções e transferência de conversas.
- Organizar sua base de contatos e aplicar segmentações e rótulos.
- Acompanhar oportunidades/leads em um quadro Kanban que já se popula sozinho a cada nova conversa, com automações configuráveis pela própria interface (gatilhos, condições e ações, incluindo disparo de mensagem automática ao lead).
- Configurar regras de automação para reduzir trabalho manual do time de atendimento.
- Administrar quem tem acesso a quê, dentro de um modelo de dois papéis (agente/administrador), com um mecanismo mais granular de papéis customizados já implementado no código, porém desligado por padrão.
- Acompanhar, por conta/cliente, o desempenho e o custo do bot Botpress associado, e testar o bot ao vivo, pelo módulo Aptus Hub (quando habilitado para a conta).
- Entregar a um cliente que só contratou o bot uma conta enxuta, em que a plataforma inteira se resume ao Hub — sem expor conversas, funil, contatos ou configurações que ele não usa.

## Principais diferenças em relação ao Chatwoot original

| Diferença | Descrição |
|---|---|
| **CRM Kanban** | Não existe no Chatwoot original — é uma adição 100% nova da Aptus (ver seção 8), incluindo motor de automação com UI própria. |
| **Aptus Hub** | Módulo novo (23–24/07), também 100% Aptus — portal de desempenho/custo/teste do bot por conta (ver seção 28). |
| **Conta só-Hub** | Recorte de conta (`hub_only`) que entrega apenas o Hub e bloqueia o resto do produto em menu, rota e API — não existe conceito equivalente no Chatwoot original (ver 3.4 e 28.7). |
| **Escopo reduzido de MVP** | Reports, Central de Ajuda, Campanhas, Companies, IA “Captain” e assinatura de mensagens foram retirados da navegação, mas não do código. |
| **Marca própria** | Nome da instalação, logotipo e tela de login já rebrandeados para Aptus; o sistema se comporta como “instância com marca própria” em vários pontos de lógica de paywall. |
| **Cadastro público desativado** | Só é possível entrar no sistema por convite de um administrador — não há tela pública de criação de conta. |
| **E-mails sempre em português** | O sistema força `pt_BR` em todos os e-mails, independentemente do idioma configurado na conta. |
| **Exigência de atributos antes de resolver conversa** | Recurso condicional (ligado por conta) que impede resolver uma conversa sem preencher certos campos — não é padrão do Chatwoot. |
| **Atribuição por atendimento com nomenclatura em português** | O pipeline padrão criado automaticamente para cada conta usa estágios como “Novo Lead”, “Qualificação Bot”, “Aguardando Humano”, “Em Atendimento” — nomenclatura pensada para o negócio de bots de atendimento da Aptus. |

Referências para conferência:
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
- `config/features.yml`, `config/installation_config.yml`, `.env`
- `app/services/crm/default_pipeline_setup_service.rb`

---

# 2. Como acessar e navegar pelo sistema

## 2.1 Tela inicial e login

- A tela de login (`/login`) já está rebrandeada — usa os logotipos `/brand-assets/logo-azul.svg` (claro) e `/brand-assets/logo-branca.svg` (escuro), não mais o logotipo do Chatwoot.
- Campos: e-mail e senha. Há suporte a login via Google (se configurado) e via SSO/SAML (aparece apenas se a instalação for identificada como Enterprise E a conta tiver o método habilitado — ver seção 14).
- Link **“Esqueci minha senha”** leva ao fluxo `/auth/password/edit` → `/auth/reset/password` (o usuário recebe um e-mail com link de redefinição, sujeito às condições descritas na seção 13).
- **Não existe cadastro público de conta.** O botão/rota de signup (`/auth/signup`) está bloqueado tanto no frontend quanto no backend porque a variável `ENABLE_ACCOUNT_SIGNUP` está definida como `false` no ambiente. **A única forma de entrar no sistema é ser convidado por um administrador** pela tela Configurações → Agentes (ver seção 10).
- **Convite/confirmação de conta**: ao ser cadastrado como agente, o usuário recebe um e-mail de confirmação (reaproveitando o mecanismo padrão de confirmação de e-mail do Devise, não um e-mail de “convite” dedicado). Ao confirmar, ele é direcionado para definir uma senha via o mesmo fluxo de "esqueci minha senha".

## 2.2 Entrada e redirecionamento

Depois de autenticado, o sistema decide para onde levar o usuário:
- Se a conta ainda está em processo de configuração inicial (onboarding) e o usuário é administrador, é levado para a tela de onboarding (dados da conta / configuração de inbox).
- Caso contrário, cai direto na tela de **Conversas → Caixa de Entrada** (equivalente ao primeiro item do menu lateral, “Inbox”).

## 2.3 Seleção/troca de conta

- Um mesmo usuário pode pertencer a mais de uma conta (empresa) na mesma instalação.
- O seletor de conta fica no topo do menu lateral (`SidebarAccountSwitcher`). Clicar nele mostra a lista de contas às quais o usuário pertence, com o papel em cada uma. Trocar de conta faz um recarregamento completo da página para a URL da nova conta (não é uma troca “instantânea” via navegação SPA).
- Existe um botão “Nova conta” no seletor, mas ele só aparece se a instalação permitir criação de conta pelo próprio painel (configuração `createNewAccountFromDashboard` do backend) — combinado ao cadastro público desativado, isso é o único caminho para criar uma segunda conta sem passar pelo Super Admin.

## 2.4 Layout principal

- **Menu lateral** (esquerda): ver seção 5 para a lista completa.
- **Busca global**: um campo de busca no topo do menu lateral (atalho de teclado `Cmd/Ctrl+K` mostrado ao lado) abre a tela de busca, que cobre conversas, contatos, mensagens e artigos de central de ajuda (embora a seção de Central de Ajuda esteja oculta do menu, a aba de busca por artigos continua presente no componente).
- **Botão de nova conversa** (ícone de lápis) ao lado da busca abre o fluxo de composição de uma nova conversa.
- **Menu de perfil** (avatar, no rodapé do menu lateral): Suporte da Aptus (se configurado), Atalhos de teclado, Configurações de Perfil, Aparência, Documentação (ainda aponta para a documentação pública do Chatwoot, não da Aptus), Changelog (idem, ainda é o changelog do Chatwoot), Console Super Admin (só visível para super administradores da instalação), Sair.
- **Não existe mais um sino de notificações visível na interface.** Existe um componente pronto para isso (`SidebarNotificationBell.vue`), mas ele não está sendo usado em nenhuma tela — é código "órfão". Hoje, a única forma de chegar à tela de notificações é pelo atalho de teclado `Cmd/Ctrl+K` (Command Bar) buscando “Notifications”, ou pela contagem de não lidos que aparece como selo no item **Inbox** do menu.
- **Command Bar (`Cmd/Ctrl+K`)**: paleta de comandos com atalhos de navegação rápida (“ir para Relatórios”, “ir para Configurações”, etc.). É importante notar que essa paleta **não respeita a mesma regra de ocultação usada no menu lateral** — como as funcionalidades de Relatórios, Central de Ajuda e Campanhas continuam com suas feature flags ligadas no backend, os comandos de navegação para essas áreas aparecem na Command Bar mesmo estando ocultas no menu (ver observação de segurança na seção 21).
- **Atalhos de teclado**: modal próprio (`Cmd/Ctrl+/`) lista todos os atalhos disponíveis.

Referências para conferência:
- `app/javascript/v3/views/login/Index.vue`, `app/javascript/v3/views/routes.js`, `app/javascript/v3/helpers/RouteHelper.js`
- `app/javascript/dashboard/routes/index.js`, `app/javascript/dashboard/routes/dashboard/Dashboard.vue`
- `app/javascript/dashboard/composables/commands/useGoToCommandHotKeys.js`
- `.env` (`ENABLE_ACCOUNT_SIGNUP=false`)

---

# 3. Tipos de usuário e níveis de acesso

## 3.1 Modelo de dados

No banco de dados, um usuário (`User`) pode pertencer a várias contas, e a cada vínculo conta↔usuário (`AccountUser`) corresponde um **papel**:

- **`agent`** (agente) — papel padrão.
- **`administrator`** (administrador da conta) — controle total sobre a conta.

Além dessas duas roles nativas, existe um terceiro mecanismo, **Papéis Customizados (Custom Roles)**, implementado no código mas **desligado por padrão** (ver seção 3.3).

Fora dessas duas camadas, existe ainda o **Super Administrador da instalação** — um usuário especial que não pertence ao conceito de “conta”, mas administra a instalação inteira (todas as contas). Tecnicamente, é o mesmo modelo `User`, mas com uma coluna de tipo (`type = 'SuperAdmin'`) — não existe uma tabela separada.

## 3.2 Papéis nativos: Agente vs. Administrador

| Aspecto | Agente | Administrador |
|---|---|---|
| Ver conversas | Só das inboxes/times aos quais está associado | Todas as conversas da conta |
| Excluir conversa | Não pode | Pode (endpoint e botão restritos a admin) |
| Ver/gerenciar contatos | Ver, criar, editar livremente | + Importar, exportar, excluir |
| Ver inboxes | Só as atribuídas a ele | Todas; pode criar/editar/excluir |
| Times | Ver | Criar, editar, excluir, gerenciar membros |
| Agent Bots | Ver | Criar, editar, excluir, resetar tokens |
| Regras de automação | Sem acesso | Controle total |
| Macros | Cria macros próprias; só edita/exclui as suas (ou globais, se for admin) | Controle total sobre macros globais |
| Labels | Ver | Criar, editar, excluir |
| Webhooks (Integrações) | Sem acesso | Controle total |
| Atributos personalizados | Ver | Criar, editar, excluir |
| SLA (se habilitado) | Ver | Criar, editar, excluir |
| Papéis customizados (se habilitado) | Sem acesso | Único que pode gerenciar |
| Política de capacidade de agente (se habilitado) | Sem acesso | Controle total |
| CRM — ver negócios (deals) | Vê **todos** os negócios da conta (não há filtro por responsável) | Vê todos |
| CRM — gerenciar funis/estágios | Sem acesso | Único que pode criar/editar/excluir funis e estágios |
| Cadastrar/remover agentes | Não pode | Pode convidar, editar papel, remover |
| Configurações da conta | Sem acesso à maioria das telas | Acesso total |

> **Nota de esclarecimento de nomenclatura**: o sistema não usa os termos “supervisor” ou “usuário parcial” — só existem, nativamente, `agent` e `administrator`. Qualquer granularidade adicional passa pelo mecanismo de Papéis Customizados.

## 3.3 Papéis Customizados (Custom Roles) — recurso Enterprise, hoje desligado por padrão

O código já implementa um terceiro tipo de papel, granular, com uma lista fixa de 6 permissões possíveis:

- `conversation_manage` — gerencia todas as conversas.
- `conversation_unassigned_manage` — gerencia conversas não atribuídas + as suas.
- `conversation_participating_manage` — só conversas atribuídas/participando.
- `contact_manage` — gerencia contatos, incluindo importar/exportar.
- `report_manage` — acessa relatórios (nota: a tela de Relatórios está oculta do menu no MVP, ver seção 5).
- `knowledge_base_manage` — gerencia Central de Ajuda (também oculta do menu no MVP).

Um administrador pode criar uma role customizada (ex: “Supervisor”) combinando essas seis permissões, em Configurações → Papéis Customizados, e depois atribuir essa role a um agente na tela de edição de agente.

**Condição de disponibilidade**: este recurso depende da feature flag `custom_roles`, que vem **desativada por padrão** (`enabled: false, premium: true` em `config/features.yml`). Como a instalação está com marca própria (“Aptus”, não “Chatwoot”), o sistema não mostra a tela de upgrade/pagamento que apareceria em uma instalação Chatwoot Cloud — em vez disso, a tela simplesmente aparece bloqueada (“Add role” desabilitado) até que um Super Admin da instalação habilite essa funcionalidade manualmente para a conta específica, pelo painel Super Admin → Contas.

> **Nuance técnica relevante**: mesmo com a tela bloqueada, o endpoint de API para criar papéis customizados não tem uma segunda verificação da feature flag — só exige que quem chame seja administrador. Ou seja, tecnicamente um administrador poderia criar papéis customizados via chamada direta à API mesmo com a tela desabilitada. Isso é um ponto para validação/decisão de produto (ver seção 21).

## 3.4 Contas só-Hub (`hub_only`) — recorte de acesso por conta, não por papel

Além dos papéis acima, existe um segundo eixo de restrição, aplicado à **conta inteira** em vez do usuário: uma conta marcada como `hub_only` só dá acesso ao módulo Hub. Isso atende o cliente que contrata só o bot (usa CRM e mensageria em outra ferramenta, como o Kommo) e não tem uso para conversas, contatos, funil ou configurações.

Não é um papel novo: o usuário continua sendo `administrator` ou `agent` da conta. O que muda é o alcance da conta:

| Camada | Comportamento numa conta `hub_only` |
|---|---|
| Menu lateral | Só o grupo Hub (sem Agenda, sem Settings, sem Conversas/CRM/Contatos) |
| Rota | Qualquer rota fora do Hub — inclusive digitada na barra de endereço — redireciona para `hub_performance` |
| Login | Entra direto no Hub; o wizard de onboarding (dados da conta → setup de inbox) é pulado |
| API | Todo controller sob `Api::V1::Accounts::BaseController` responde 404, exceto o do próprio Hub |

O modelo pretendido é **um único usuário por conta só-Hub**, com papel `administrator` — assim a aba Pagamentos (que exige admin, ver 28.4) funciona sem que isso abra Settings, já que Settings deixa de existir na navegação e na API.

Contas comuns não são afetadas: o flag nasce desligado. Ver 28.7 para o provisionamento.

## 3.5 Super Administrador da instalação

- Representa quem administra a instalação inteira, não uma conta específica (equivalente a “administrador de sistema” ou “dono da plataforma”).
- É criado marcando a coluna `type` do usuário como `SuperAdmin` — isso pode ser feito por outro Super Admin, pela tela `/super_admin/users`.
- Entra pela URL `/super_admin` com um login próprio (mesmo mecanismo de autenticação, mas rota separada).
- Detalhes completos de tudo o que o Super Admin pode fazer estão na seção 16.

## 3.6 Contatos (usuários finais) — não são “usuários” do sistema

Pessoas que enviam mensagens pelos canais (WhatsApp, site, etc.) são tratadas como **Contatos**, uma entidade totalmente separada de `User`. Contatos nunca acessam o painel do Aptus Chat — eles só existem como registros de dados dentro de uma conta, vinculados a conversas. Ver seção 7 para detalhes.

> Numa conta `hub_only` (ver 3.4) não existem contatos, porque não existe canal de mensageria — o bot daquele cliente conversa por fora (Kommo, WhatsApp de outro provedor) e o aptus-chat só acompanha o desempenho dele.

## 3.7 Matriz de permissões resumida

| Funcionalidade | Tipo de usuário | Ver | Criar | Editar | Excluir | Observações |
|---|---|---|---|---|---|---|
| Conversas | Agente | Só das suas inboxes/times | — | Responde/atua | Não | — |
| Conversas | Administrador | Todas | — | Sim | Sim | Exclusão restrita a admin (policy + UI) |
| Contatos | Agente | Sim | Sim | Sim | Não | Sem importar/exportar |
| Contatos | Administrador | Sim | Sim | Sim | Sim | + Importar/Exportar |
| Empresas (Companies) | — | — | — | — | — | **Escondido (APTUS-HIDDEN)** — backend intacto (Enterprise), sem UI |
| CRM — Negócios (deals) | Agente | Todos (sem filtro por responsável) | Sim (campos limitados na UI) | Sim (nome/estágio/atributos custom) | Sim | Amount/moeda/data/probabilidade/contato/responsável só via API direta |
| CRM — Funis/Estágios | Agente | Sim | Não | Não | Não | — |
| CRM — Funis/Estágios | Administrador | Sim | Sim | Sim | Sim | — |
| Agentes | Agente | Lista | Não | Não | Não | — |
| Agentes | Administrador | Lista | Sim (convite) | Sim (papel, disponibilidade) | Sim | — |
| Times | Agente | Sim | Não | Não | Não | — |
| Times | Administrador | Sim | Sim | Sim | Sim | Sem associação direta a inbox |
| Inboxes | Agente | Só as atribuídas | Não | Não | Não | — |
| Inboxes | Administrador | Todas | Sim | Sim | Sim | — |
| Automações | Agente | — | — | — | — | Sem acesso a esta tela |
| Automações | Administrador | Sim | Sim | Sim | Sim | — |
| Macros | Agente | Sim | Sim (próprias) | Só as próprias | Só as próprias | Globais só por admin |
| Labels | Agente | Sim | Não | Não | Não | — |
| Labels | Administrador | Sim | Sim | Sim | Sim | — |
| Atributos Personalizados | Agente | Sim | Não | Não | Não | — |
| Atributos Personalizados | Administrador | Sim | Sim | Sim | Sim | — |
| Webhooks/Integrações | Agente | — | — | — | — | Sem acesso |
| Webhooks/Integrações | Administrador | Sim | Sim | Sim | Sim | — |
| SLA | — | — | — | — | — | Enterprise, gated (`sla`, off por padrão) |
| Papéis Customizados | — | — | — | — | — | Enterprise, gated (`custom_roles`, off por padrão) |
| Audit Logs | Administrador | Sim (se flag ligada) | — | — | — | Gated (`audit_logs`, off por padrão) |
| Configurações da Conta | Administrador | Sim | — | Sim | — | Agente sem acesso |
| Billing | — | — | — | — | — | Só Chatwoot Cloud; redireciona sozinho neste self-hosted |
| Super Admin (instalação) | Super Admin | Tudo | Tudo | Tudo | Tudo | Fora do escopo de conta |

> A matriz acima vale para contas comuns. Numa conta `hub_only` (ver 3.4), tudo que não é Hub sai da matriz: some do menu, a rota redireciona e a API responde 404 — independentemente do papel do usuário.

Referências para conferência:
- `app/models/account_user.rb`, `app/models/user.rb`, `app/models/super_admin.rb`
- `enterprise/app/models/custom_role.rb`, `enterprise/app/models/enterprise/account_user.rb`
- `app/policies/*.rb`, `enterprise/app/policies/**/*.rb`
- `config/features.yml`

---

# 4. Mapa completo de telas e rotas

> Nesta seção documentamos as telas mais importantes com o formato completo pedido. Telas de Configurações (Settings) mais simples estão detalhadas de forma tabular na seção 14 para evitar repetição excessiva de formato — aqui aprofundamos as telas centrais do produto.

## Inbox (Caixa de Entrada)

**Como acessar:** Entrar no sistema → primeiro item do menu lateral, “Inbox”.
**Rota:** `inbox_view` (equivalente à home de conversas com `inboxId: 0`).
**Quem pode acessar:** Qualquer agente ou administrador.
**Objetivo da tela:** Visão consolidada de todas as conversas relevantes para o usuário logado, com contador de não lidas.
**Elementos disponíveis:** Lista de conversas, abas de atribuição (Minhas/Não atribuídas/Todas — com permissões diferentes por role), filtro de status, ordenação, pesquisa avançada, seleção múltipla para ações em massa.
**Fluxo de uso:** O agente abre a tela, filtra pelas suas conversas, abre uma conversa da lista para atender.
**Comportamentos automáticos:** Atualização em tempo real via WebSocket (ActionCable) — novas mensagens, mudanças de status e atribuições aparecem sem precisar recarregar a página.
**E-mails relacionados:** Não diretamente — mas mensagens enviadas por e-mail em conversas de inbox de e-mail disparam o mailer de resposta (ver seção 13).
**Restrições ou condições:** Nenhuma feature flag; sempre visível.
**Observações:** A ordem das abas (Minhas/Não atribuídas/Todas) é personalizável e fica salva no navegador do usuário — não é um recurso padrão do Chatwoot, parece customização da Aptus.

Referências para conferência:
- `app/javascript/dashboard/components/ChatList.vue`
- `app/javascript/dashboard/routes/dashboard/conversation/conversation.routes.js`
- `app/channels/room_channel.rb`

## Conversa individual

**Como acessar:** A partir de qualquer lista de conversas, clicar em uma conversa.
**Rota:** `inbox_view_conversation` / `conversation_through_*` conforme a origem (menções, participando, etc.).
**Quem pode acessar:** Agente com acesso à inbox/time da conversa, ou administrador.
**Objetivo da tela:** Atender a conversa — ler histórico, responder, colaborar internamente.
**Elementos disponíveis:** Cabeçalho (nome do contato, status, botão de chamada de voz se WhatsApp, ações — resolver/reabrir/soneca/silenciar/excluir), corpo com histórico de mensagens e eventos de sistema, caixa de resposta (texto, nota privada, anexos, áudio, emojis, menções, respostas prontas, variáveis, macros), painel lateral “Contato” com abas: ações da conversa, participantes, informações da conversa, atributos do contato, conversas anteriores do contato, macros, notas do contato, arquivos compartilhados (e, se integrações estiverem conectadas, issues do Linear/pedidos do Shopify).
**Fluxo de uso:** Ler mensagens → responder ou registrar nota interna → opcionalmente atribuir/rotular/definir prioridade → resolver.
**Comportamentos automáticos:** Indicador de digitação em tempo real, presença online/offline dos agentes, reabertura automática da conversa se o contato responder após ela estar “snoozed” (ou, se “resolved”, reabre para “pending”/“open” dependendo se a inbox tem bot ativo), bloqueio de resolução se a conta exigir atributos obrigatórios preenchidos antes (condicional).
**E-mails relacionados:** “Enviar transcript por e-mail” (botão no menu de mais ações) dispara e-mail com o histórico da conversa. Mensagens de canais de e-mail geram e-mail de fato ao contato.
**Restrições ou condições:** Exclusão de conversa restrita a administrador. Upload múltiplo de anexos só em alguns canais. Editor desabilitado fora da janela de mensageria de 24h (WhatsApp/Instagram/Facebook), com necessidade de usar template aprovado para reabrir.
**Observações:** A aba “Copilot” do painel lateral foi removida (APTUS-HIDDEN) — hoje só existe a aba “Contato”.

Referências para conferência:
- `app/models/conversation.rb`, `app/models/message.rb`
- `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`
- `app/javascript/dashboard/components-next/Conversation/SidepanelSwitch.vue`
- `app/controllers/api/v1/accounts/conversations_controller.rb`

## CRM (Kanban)

**Como acessar:** Menu lateral → “CRM”.
**Rota:** `crm_kanban`.
**Quem pode acessar:** Qualquer agente ou administrador (leitura e movimentação de cards); só administrador cria/edita funis e estágios.
**Objetivo da tela:** Visualizar e gerenciar negócios/leads em um quadro estilo Kanban, organizados por funil e estágio.
**Elementos disponíveis:** Seletor de funil, colunas por estágio (com drag-and-drop entre colunas), cards de negócio (nome, valor, data de fechamento, indicação de ganho/perdido), botão “+” por coluna para criar negócio manualmente (só nome e estágio), painel lateral do negócio (edição inline de nome, mudança de estágio, contato vinculado somente leitura, responsável somente leitura, atributos personalizados do negócio com CRUD completo, exclusão com confirmação dupla), painel de configurações do quadro (criar/editar/excluir funis e estágios, cor e marcação de "ganho"/"perdido" por estágio).
**Fluxo de uso:** Uma conversa nova já cria automaticamente um negócio no funil padrão; o agente acompanha/move os cards conforme o atendimento avança, ou cria negócios manualmente.
**Comportamentos automáticos:** Toda conversa nova gera um negócio automaticamente vinculado ao contato. Existe um motor de automação (regras baseadas em evento e em tempo, como “negócio parado há X dias”) rodando em segundo plano, mas **sem nenhuma tela ainda para configurá-lo** — hoje só pode ser configurado diretamente no banco de dados.
**E-mails relacionados:** Não identificado nenhum disparo de e-mail a partir do CRM.
**Restrições ou condições:** Nenhuma feature flag — item sempre visível no menu.
**Observações:** Ver seção 8 para o detalhamento completo, incluindo lacunas de implementação.

Referências para conferência:
- `app/models/crm_deal.rb`, `crm_pipeline.rb`, `crm_stage.rb`
- `app/javascript/dashboard/components-next/Crm/*`
- `app/controllers/api/v1/accounts/crm_deals_controller.rb`

## Contatos (listagem)

**Como acessar:** Menu lateral → “Contatos”.
**Rota:** `contacts_dashboard_index` (e variações: `contacts_dashboard_active`, `contacts_dashboard_segments_index`, `contacts_dashboard_labels_index`).
**Quem pode acessar:** Qualquer agente ou administrador.
**Objetivo da tela:** Gerenciar a base de contatos da conta.
**Elementos disponíveis:** Abas/filtros (Todos, Ativos, Segmentos salvos, Marcados com determinada label), busca, criação de contato, importação (CSV, com modelo de exemplo para download), exportação, edição, notas, histórico de conversas, atributos personalizados, mesclagem de duplicados, bloqueio.
**Fluxo de uso:** Buscar/filtrar contato → abrir ficha → editar dados, ver histórico ou registrar nota.
**Comportamentos automáticos:** Nenhum processamento automático relevante além da criação implícita de contato ao chegar uma nova mensagem de um canal.
**E-mails relacionados:** Conclusão (ou falha) de importação e conclusão de exportação disparam e-mail ao administrador que iniciou a ação (ver seção 13).
**Restrições ou condições:** Nenhuma feature flag bloqueando o acesso básico.
**Observações:** “Empresas” (Companies), que no Chatwoot original aparece vinculada a contatos, está oculta (APTUS-HIDDEN) — o backend continua funcionando, só não há caminho de navegação.

Referências para conferência:
- `app/models/contact.rb`, `app/controllers/api/v1/accounts/contacts_controller.rb`
- `app/javascript/dashboard/routes/dashboard/contacts/`

## Configurações → Agentes

**Como acessar:** Menu lateral → Configurações → “Agentes”.
**Rota:** `agent_list`.
**Quem pode acessar:** Somente administrador.
**Objetivo da tela:** Convidar, editar e remover agentes.
**Elementos disponíveis:** Tabela com busca (avatar, nome, e-mail, papel — padrão ou customizado, com tooltip mostrando as permissões — e selo de verificação de e-mail), botão “Add Agent” (nome, e-mail, papel), edição (nome, papel/papel customizado, disponibilidade, botão de resetar senha), exclusão com confirmação.
**Fluxo de uso:** Administrador convida um agente por e-mail → agente recebe e-mail de confirmação → define senha → acessa o sistema.
**Comportamentos automáticos:** Criação de agente dispara o e-mail de confirmação padrão do sistema de login (Devise), que também serve como “convite”.
**E-mails relacionados:** E-mail de confirmação de conta (ver seção 13) — é o mesmo mecanismo usado tanto para novo cadastro quanto para convite.
**Restrições ou condições:** Não é possível remover o único administrador confirmado da conta, nem a si mesmo.
**Observações:** Não existe uma tela dedicada de “convite” — o fluxo é reaproveitado do cadastro padrão do sistema de autenticação.

Referências para conferência:
- `app/controllers/api/v1/accounts/agents_controller.rb`
- `app/builders/agent_builder.rb`
- `app/javascript/dashboard/routes/dashboard/settings/agents/Index.vue`

---

# 5. Menu lateral completo

Ordem exata em que aparece para o usuário (`app/javascript/dashboard/components-next/sidebar/Sidebar.vue`):

| # | Item | Rota | Quem vê | Condição de exibição | Submenus/Filhos | Indicadores |
|---|---|---|---|---|---|---|
| 1 | **Inbox** | `inbox_view` | Todos | Sempre | — | Contador de não lidas |
| 2 | **Conversation** (ícone de balão) | — | Todos | Sempre | All, Mentions, Participating, Unattended, Folders (visões salvas), Teams (meus times), Channels (minhas inboxes), Labels | Contadores por item, quando aplicável |
| 3 | **CRM** (ícone aperto de mãos, desde 24/07 — antes usava o mesmo ícone kanban do submenu) | — | Todos (Funil); só Admin acessa Automações (rota tem `permissions: ['administrator']`, mas o item de menu aparece para ambos) | Sempre | **Funil** (`crm_kanban`, ícone kanban) e **Automações** (`crm_automations`, ícone workflow) — ver seção 8.7 | — |
| 4 | **Contacts** (ícone contato) | — | Todos | Sempre | All Contacts, Active, Segments, Tagged With | — |
| 5 | **Hub** (ícone a definir, adicionado 23/07) | — | Todos (mesma regra de acesso do resto: `administrator`/`agent`) | **Só aparece se a conta tiver `custom_attributes.aptus_hub.enabled = true` E `bot_id` preenchido** — configurado pelo Super Admin em Super Admin → Accounts (campo `AptusHubConfigField`); em nenhuma conta atual isso está confirmado como ligado por padrão | **Desempenho** (`hub_performance`, rota-raiz do grupo), **Testar** (`hub_tester`), **Pagamentos** (`hub_payments`, também cobre a subrota de detalhe `hub_payment_details`) | — |
| 6 | **Settings** (ícone engrenagem) | — | Depende do item (ver abaixo) | Sempre visível o grupo | 18 subitens (ver seção 14) | — |

> **Nota sobre o item Hub**: diferente de todos os outros itens do menu (que são incondicionais ou dependem de uma feature flag global), o Hub é **ligado individualmente por conta**, criado para o caso de uso de portal do cliente. Ver seção 28 para o detalhamento completo.

> **Nota sobre contas só-Hub**: a tabela acima descreve o menu de uma conta comum. Uma conta marcada como `hub_only` (ver 28.7) **não mostra nenhum dos itens 1 a 4 nem o item 6** — o menu inteiro se resume ao grupo Hub, e o grupo Agenda também some. É o único caso em que Inbox, Conversation, CRM, Contacts e Settings deixam de aparecer.

## Itens removidos do menu (APTUS-HIDDEN) — não fazem parte do catálogo de disponíveis

| Item removido | Local do bloco comentado | O que seria |
|---|---|---|
| **Reports** | `Sidebar.vue:604-637` | Relatórios de visão geral, conversa, agente, label, inbox, time, CSAT, SLA, bot |
| **Captain** | `Sidebar.vue:438-509` | Assistente de IA (respostas sugeridas, documentos, cenários, playground, tools) |
| **Companies** | `Sidebar.vue:585-602` | Empresas vinculadas a contatos |
| **Campaigns** | `Sidebar.vue:639-661` | Campanhas de disparo (Live chat, SMS, WhatsApp) |
| **Portals (Help Center)** | `Sidebar.vue:663-710` | Central de ajuda / base de artigos pública |

> **Importante para o time de produto**: mesmo ocultos do menu, os **backends de Reports, Campaigns e Help Center continuam rodando** (jobs agendados, processamento de eventos) porque as respectivas feature flags seguem `enabled: true` no arquivo de configuração — apenas a navegação foi removida. Ver seção 21 para o detalhamento e a recomendação de revisão.

## Submenu “Settings” — 18 itens (ordem exibida)

| # | Item | Rota | Ícone | Condição |
|---|---|---|---|---|
| 1 | Account Settings | `general_settings_index` | maleta | Sempre |
| 2 | Agents | `agent_list` | usuário | Sempre |
| 3 | Teams | `settings_teams_list` | usuários | Sempre |
| 4 | Agent Assignment | `assignment_policy_index` | engrenagem de usuário | **Só aparece se a feature `advanced_assignment` estiver ligada na conta** (desligada por padrão) |
| 5 | Inboxes | `settings_inbox_list` | caixa de entrada | Sempre |
| 6 | Labels | `labels_list` | etiquetas | Sempre |
| 7 | Custom Attributes | `attributes_list` | código | Sempre |
| 8 | Automation | `automation_list` | repetir | Sempre |
| 9 | Agent Bots | `agent_bots` | robô | Sempre |
| 10 | Macros | `macros_wrapper` | bloco | Sempre |
| 11 | Canned Responses | `canned_list` | mensagem | Sempre |
| 12 | Integrations | `settings_applications` | blocos | Sempre |
| 13 | Audit Logs | `auditlogs_list` | maleta | Sempre visível; conteúdo depende de `audit_logs` (desligada por padrão) |
| 14 | Custom Roles | `custom_roles_list` | escudo | Sempre visível; conteúdo com paywall se `custom_roles` desligada |
| 15 | SLA | `sla_list` | relógio | Sempre visível; conteúdo com paywall se `sla` desligada |
| 16 | Conversation Workflow | `conversation_workflow_index` | fluxo | Sempre |
| 17 | Security | `security_settings_index` | escudo | Sempre visível; funcionalidade (SSO) inerte sem configuração adicional |
| 18 | Billing | `billing_settings_index` | cartão | Sempre visível no menu, mas **a rota se auto-redireciona para a Inbox** neste ambiente self-hosted |

Referências para conferência:
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
- `config/features.yml`

---

# 6. Mensageria e conversas

## 6.1 Status e prioridade

- **Status possíveis**: `open` (aberta), `pending` (pendente), `resolved` (resolvida), `snoozed` (soneca/adiada).
- **Prioridade**: `low`, `medium`, `high`, `urgent`.
- Alternar entre aberto/resolvido é feito pelo botão “Resolve/Reopen” no cabeçalho da conversa; “Pendente” e “Soneca” ficam num menu de mais ações.
- Uma conversa nasce automaticamente **resolvida** se o contato estiver bloqueado, ou **pendente** se a inbox tiver um bot ativo (aguardando handoff para humano); do contrário, nasce **aberta**.

## 6.2 Lista de conversas, filtros e buscas

- Abas de atribuição: **Minhas / Não atribuídas / Todas** — a permissão de ver cada aba depende do papel do usuário. A ordem dessas abas pode ser reorganizada pelo próprio usuário e fica salva no navegador (personalização própria da Aptus, não padrão do Chatwoot).
- Filtro de status e ordenação (mais recente, não lidas primeiro) são persistidos nas preferências do usuário.
- **Filtro avançado** permite combinar atributos de conversa, contato e atributos personalizados.
- **Pastas (Folders / Custom Views)**: qualquer combinação de filtros pode ser salva como uma pasta, acessível depois no menu lateral em Conversation → Folders.
- **Busca global** cobre conversas (por ID, nome/e-mail/telefone do contato), mensagens (conteúdo), contatos e artigos.
- Paginação por página (25 conversas por vez), com atualização em tempo real via WebSocket — mensagens novas, mudanças de status/atribuição e novos contadores de não lidos chegam sem recarregar a página.

## 6.3 Ações em massa

Com seleção múltipla de conversas na lista, é possível: aplicar/remover labels em lote, atribuir agente em lote, atribuir time em lote, e mudar status em lote (resolver, reabrir, soneca — inclusive com soneca customizada).

## 6.4 Caixa de resposta

- Alternância entre **Resposta pública** e **Nota privada** (atalhos `Alt+L` / `Alt+P`).
- Suporte a anexos (múltiplos, condicionado por canal), áudio gravado na hora (formato do áudio varia por canal — ex: OGG para WhatsApp Cloud, MP3 para WhatsApp/Telegram/API), emojis, menções a outros agentes (`@`), respostas prontas (`/`), variáveis de template (`{{`), macros (executam uma sequência de ações pré-configuradas sobre a conversa).
- Rascunho é salvo automaticamente no navegador por conversa (não é sincronizado entre dispositivos).
- Diversos atalhos de teclado: enviar mensagem, abrir/fechar painel de contato, resolver conversa, abrir seletor de anexo, abrir busca de comandos, etc.

## 6.5 Painel lateral do contato (dentro da conversa)

Hoje só existe a aba **“Contato”** (a aba “Copilot” foi retirada do MVP). Dentro dela, seções reorganizáveis por drag-and-drop:
- Ações da conversa (atribuir agente/time, prioridade, labels da própria conversa)
- Participantes da conversa
- Informações da conversa (atributos adicionais)
- Atributos personalizados do contato
- Histórico de conversas anteriores do mesmo contato
- Macros
- Issues do Linear / pedidos do Shopify (só aparecem se essas integrações estiverem conectadas)
- Notas do contato
- Arquivos compartilhados

## 6.6 Menções, notas e activity log

- Menções (`@agente`) geram notificação em tempo real para o agente mencionado.
- Notas internas não são visíveis ao contato.
- Toda mudança relevante de estado (status, prioridade, labels, atribuição, SLA, time) gera uma mensagem de sistema (“activity log”) visível no histórico da conversa — ex.: “Fulano atribuiu a conversa para Ciclano”.

## 6.7 Presença e digitação

- Indicador de “digitando…” em tempo real.
- Indicador de presença (online/offline) do agente aparece nos avatares, tanto na conversa quanto na lista.
- Disponibilidade do agente também influencia a distribuição automática de novas conversas (ver seção 10).

## 6.8 Transferência, reabertura e exclusão

- Reatribuição de agente/time é feita dentro da própria conversa.
- **Não existe** funcionalidade de “transferir conversa para outra inbox” — comportamento herdado do Chatwoot original.
- Reabertura acontece automaticamente quando o contato responde a uma conversa em soneca ou resolvida (com regra diferente dependendo se a inbox tem bot ativo).
- **Exclusão de conversa existe**, mas é restrita a administradores (tanto a visibilidade do botão quanto a autorização no backend).

## 6.9 Diferenças entre canais dentro da conversa

- **E-mail**: campos de Para/CC/CCO aparecem só em conversas de canal de e-mail; suporte a “citar e-mail anterior”.
- **WhatsApp (Cloud/Twilio/360dialog)**: modal de templates aprovados (HSM) aparece quando a conversa está fora da janela de 24 horas de resposta livre.
- **Twilio WhatsApp (não-Meta)**: modal de “Content Templates” próprio da Twilio.
- **Instagram/TikTok**: texto e anexo nunca são enviados juntos na mesma mensagem (comportamento para evitar problemas nas respectivas APIs).
- Limite de caracteres varia por canal (Facebook, Instagram, Telegram, TikTok, Twilio WhatsApp, WhatsApp Cloud, SMS, e-mail — cada um com seu próprio limite).
- Chamada de voz via WhatsApp está disponível diretamente na conversa (botão no cabeçalho), com eventos de chamada recebida/conectada/aceita/encerrada em tempo real.

## 6.10 Recurso condicional específico da Aptus: atributos obrigatórios antes de resolver

Se a conta tiver essa configuração ligada (feature `conversation_required_attributes`, desligada por padrão), tentar resolver uma conversa sem preencher certos atributos personalizados abre um modal bloqueando a ação até que os campos sejam preenchidos (texto, número, link, data, lista ou caixa de seleção).

Referências para conferência:
- `app/models/conversation.rb`, `app/models/message.rb`
- `app/controllers/api/v1/accounts/conversations_controller.rb`, `.../conversations/*`
- `app/javascript/dashboard/components/ChatList.vue`, `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`
- `app/javascript/dashboard/composables/useConversationRequiredAttributes.js`

---

# 7. Contatos, empresas e clientes

## 7.1 Nomenclatura usada no sistema

- **Contato (`Contact`)**: qualquer pessoa que já enviou/recebeu mensagem por algum canal. É a entidade central de “cliente final” no sistema.
- **Empresa (`Company`)**: entidade para agrupar contatos por organização — **oculta do menu (APTUS-HIDDEN)**, mas o modelo, controller e rotas de API continuam existindo no backend (recurso Enterprise do Chatwoot original).
- **Lead / Negócio (`Deal`)**: conceito do módulo de CRM novo da Aptus (ver seção 8) — representa uma oportunidade de negócio, não deve ser confundido com “Contato”.
- **Usuário (`User`)**: qualquer pessoa da equipe da Aptus ou do cliente que acessa o painel (agente, administrador, super admin) — nunca é a mesma entidade que “Contato”.
- **Conta (`Account`)**: a empresa-cliente da Aptus dentro da plataforma (ex: um cliente que contratou o Aptus Chat) — o “tenant” do sistema.

## 7.2 Funcionalidades de contato

| Funcionalidade | Descrição | Quem acessa |
|---|---|---|
| Criar contato | Formulário com nome, telefone, e-mail, identificador externo | Agente/Admin |
| Editar contato | Mesmo formulário, em modo edição | Agente/Admin |
| Excluir/Bloquear contato | Bloqueio via campo próprio (`blocked`) | Admin para exclusão; bloqueio parece disponível a ambos |
| Importar contatos | Upload de CSV, com modelo de exemplo para download (`/downloads/import-contacts-sample.csv`) | Admin (exportar/importar restrito a admin pela policy) |
| Exportar contatos | Gera CSV em segundo plano | Admin |
| Buscar/filtrar | Por nome, e-mail, telefone, atributos | Agente/Admin |
| Mesclar duplicados | Tela dedicada de merge de dois contatos | Agente/Admin |
| Notas do contato | Anotações internas vinculadas ao contato | Agente/Admin |
| Histórico de conversas | Lista de todas as conversas já tidas com o contato | Agente/Admin |
| Atributos personalizados | Campos customizados por conta, atribuídos ao contato | Agente/Admin (visualizar); criação do campo em si é feita em Configurações → Atributos, restrito a admin |
| Segmentos | Filtros salvos (mesma tecnologia de “Folders” de conversa, aplicada a contatos) | Agente/Admin |
| Marcado com (labels) | Filtrar contatos por label aplicada | Agente/Admin |

## 7.3 Segmentação (“Segments”)

Tecnicamente, um “Segmento” é um filtro salvo (`CustomFilter`, com `filter_type: contact`) — o mesmo mecanismo usado para “Pastas” de conversa, só que aplicado à listagem de contatos. Criado pela tela de Contatos → “Criar segmento”, guardando a combinação de filtros escolhida pelo usuário.

## 7.4 Empresas (Companies) — presente no código, ausente da navegação

O Chatwoot original permite vincular contatos a uma empresa (CNPJ/nome/site/etc.), com tela própria de listagem e detalhe. Na Aptus, esse recurso está **totalmente oculto do menu lateral** (bloco `APTUS-HIDDEN` em `Sidebar.vue`). Confirmado que:
- O modelo (`Company`), o controller de API e a policy continuam existindo e funcionais no backend (parte do pacote Enterprise do Chatwoot).
- Os componentes de frontend das telas de Companies também continuam no repositório, só não há nenhum link que leve até eles.
- Há uma segunda camada de desativação: a feature flag `companies` também está desligada por padrão (`enabled: false, premium: true`), então mesmo sem o corte de menu, o recurso já viria bloqueado por plano.

## 7.5 Diferença Contato × CRM (Lead/Negócio)

Um erro comum de interpretação seria achar que “Contato” e “Lead” são a mesma coisa. No sistema atual:
- **Contato** é o registro de identidade da pessoa (nome, telefone, e-mail).
- **Negócio/Lead**, no novo módulo de CRM, é um card dentro de um funil, que **pode** estar vinculado a um contato (campo opcional), representando uma oportunidade de atendimento/venda em andamento. Toda conversa nova já cria um negócio automaticamente vinculado ao respectivo contato (ver seção 8).

Referências para conferência:
- `app/models/contact.rb`, `app/models/custom_filter.rb`
- `app/controllers/api/v1/accounts/contacts_controller.rb`, `.../actions/contact_merges_controller.rb`
- `enterprise/app/models/company.rb`, `enterprise/app/controllers/api/v1/accounts/companies_controller.rb`
- `config/features.yml` (chave `companies`)

---

# 8. CRM e funcionalidades adicionadas pela Aptus

Esta é a seção mais importante do ponto de vista de novidade funcional: o item “CRM” do menu lateral **não existe no Chatwoot original**. Foi confirmado, por meio do histórico de commits, que se trata de um módulo **construído do zero pela própria Aptus**, em dois commits recentes:

1. **`feat(crm): add CRM module with pipelines, stages, deals and automation rules`** (Eder Ambrósio) — cria toda a base: modelos, migrações, controllers, policies, serviços, jobs, store do frontend, componentes Vue, item de menu e documentação de API.
2. **`feat(crm): custom attributes for deals, contact linking, and lead sidebar UX`** (Tiago Cometti) — adiciona atributos personalizados por funil, corrige o vínculo automático do contato no negócio criado e refaz a experiência do painel lateral do negócio.

> **Classificação de origem: funcionalidade nova, 100% criada pela Aptus**, vivendo dentro da pasta `app/` (não dentro da pasta `enterprise/`, que é reservada ao código Enterprise original do Chatwoot).

## 8.1 Estrutura conceitual

- **Funil (Pipeline)**: um funil de vendas/atendimento. Tem nome, descrição, pode estar ativo/inativo, e pode ser marcado como “padrão” da conta.
- **Estágio (Stage)**: uma etapa dentro de um funil (ex: “Novo Lead”, “Em Atendimento”). Tem nome, cor, posição, e pode ser marcado como “ganho” ou “perdido” (mutuamente exclusivos).
- **Negócio (Deal)**: o “card” do Kanban. Tem nome, valor monetário, moeda (padrão BRL), data prevista de fechamento, probabilidade (0-100%), atributos personalizados, contato vinculado (opcional), responsável/agente vinculado (opcional), e a data em que entrou no estágio atual.
- **Vínculo com conversa**: um negócio pode estar ligado a uma ou mais conversas.

## 8.2 Criação automática do funil padrão

Ao criar uma conta nova, o sistema **cria automaticamente** um funil chamado “Funil de Atendimento” com 6 estágios padrão, já em português e adaptados ao negócio de atendimento via bots da Aptus:
1. Novo Lead
2. Qualificação Bot
3. Aguardando Humano
4. Em Atendimento
5. Ganho
6. Perdido

## 8.3 Criação automática de negócio por conversa

**Toda conversa nova, sem exceção, gera automaticamente um negócio** no funil padrão da conta, no primeiro estágio disponível (que não seja “ganho” nem “perdido”), já vinculado ao contato da conversa. Esse comportamento roda incondicionalmente — não há uma configuração para desligá-lo.

## 8.4 Uso do quadro Kanban

**Passo a passo:**
1. Acessar o menu lateral → CRM.
2. Escolher o funil (se houver mais de um) no seletor de funil.
3. Ver os cards organizados em colunas por estágio.
4. Arrastar um card entre colunas para mudar seu estágio (drag-and-drop com atualização otimista — a interface muda na hora, e reverte se a chamada ao servidor falhar).
5. Clicar em “+” no topo de uma coluna para criar um negócio manualmente (hoje só é possível definir **nome** e **estágio inicial** por essa via — ver limitação abaixo).
6. Clicar em um card abre o painel lateral do negócio, onde é possível: editar o nome, mudar o estágio, ver o contato vinculado (somente leitura), ver o responsável (somente leitura), criar/editar/excluir atributos personalizados do negócio, e excluir o negócio inteiro (com confirmação dupla).
7. Administradores podem, na mesma tela, abrir o painel de configuração para criar, editar ou excluir funis e estágios (definindo nome, cor e se o estágio representa "ganho" ou "perdido").

## 8.5 Regras de acesso

- **Qualquer agente vê todos os negócios da conta** — não existe hoje uma restrição de "só vejo os negócios que sou responsável". Isso está confirmado tanto na política de autorização quanto na consulta que a tela usa (não há filtro por usuário).
- Criar, editar e excluir **funis e estágios** é restrito a administradores.
- Criar, editar e mover **negócios** está liberado para qualquer agente.

## 8.6 Atributos personalizados por funil

É possível criar campos personalizados específicos para negócios de um determinado funil (ex: “Origem do lead”, apenas para o funil “Vendas”). Isso pode ser feito de duas formas: diretamente pelo painel lateral do negócio (criando o campo ali mesmo) ou pela tela geral de Configurações → Atributos Personalizados, escolhendo “Modelo = Negócio” e selecionando o funil.

## 8.7 Motor de automação do CRM — hoje com UI própria completa (atualizado 23–24/07)

> **Mudança relevante desde a versão anterior deste documento**: este recurso passou de "só configurável via banco de dados" para **totalmente utilizável pela interface**, em dois commits (`Add CRM automations builder`, 23/07, e `rework condition/action inputs and time-based idempotency`, 24/07).

**Como acessar:** Menu lateral → CRM → Automações. **Rota:** `crm_automations` (lista), `crm_automation_new`/`crm_automation_edit` (formulário). **Quem pode acessar:** **somente administrador** — a rota tem `permissions: ['administrator']`, diferente do resto do CRM (Funil), que agentes também acessam. O item de menu "Automações", porém, aparece para qualquer agente; ao clicar, um agente sem permissão é bloqueado pelo guard de rota (não há um "cadeado visual" no próprio item).

**Elementos disponíveis:**
- **Lista de automações**: nome do funil (ou "todos os funis"), tipo de gatilho, contagem de ações, data de atualização, toggle ativo/inativo, clonar, excluir (com confirmação).
- **Formulário** (reconstruído em cima dos componentes do design system — cards, radio cards, filtro, switch — em vez de `<select>` cru): gatilho, condições e ações.

**Gatilhos por evento**: negócio criado, negócio mudou de estágio, negócio entrou em um estágio específico, negócio atualizado, negócio ganho, negócio perdido.
**Gatilhos por tempo**: data de fechamento se aproximando, negócio parado há X dias sem movimentação — verificados por um job agendado que roda todos os dias às 8h.
**Condições**: sobre estágio, responsável, valor, probabilidade, data de fechamento, dias parado no estágio — com o **operador de comparação disponível agora dependente do tipo do atributo escolhido** (ex.: estágio só aceita "igual a"/"diferente de"; número aceita "maior que"/"menor que"; data aceita "antes de X dias"/"é hoje"/"passado"/"futuro"), combináveis.
**Ações disponíveis**: mudar de estágio, mudar de funil, atribuir agente responsável, atualizar um campo, disparar um webhook, e **enviar mensagem ao lead** (nova, real) — dispara uma mensagem (texto, mídia, botões ou template) na conversa vinculada ao negócio. As duas ações antigas que só existiam como stub ("enviar e-mail ao responsável" e "adicionar nota") foram **removidas do código** em vez de implementadas.

**Idempotência**: antes bastava uma janela fixa de 5 minutos para não repetir a mesma execução; agora a checagem é contra o `updated_at` do negócio — a regra só volta a disparar quando o negócio muda de novo, e não apenas porque o tempo passou.

**Restrições ou condições:** Nenhuma feature flag — depende só da role de administrador.
**Observações:** Continua sem testes automatizados no restante do módulo de CRM (ver 8.8), mas a suíte de specs de `action_service`, `processor` e o controller de automações foi ampliada nesses commits.

Referências para conferência:
- `app/controllers/api/v1/accounts/crm_automation_rules_controller.rb`, `app/policies/crm_automation_rule_policy.rb`
- `app/javascript/dashboard/components-next/Crm/automations/CrmAutomationsIndex.vue`, `CrmAutomationForm.vue`, `constants.js`
- `app/services/crm_automation_rules/action_service.rb`, `conditions_filter_service.rb`, `processor.rb`

## 8.8 Limitações confirmadas de implementação

| Recurso | Situação |
|---|---|
| Editar valor (`amount`), moeda, data de fechamento, probabilidade de um negócio pela interface | **Não existe tela para isso** — os campos existem no banco e na API, mas só podem ser preenchidos chamando a API diretamente |
| Definir/alterar o contato vinculado a um negócio pela interface | **Não existe** — só é preenchido automaticamente pela criação da conversa |
| Definir/alterar o responsável (assignee) de um negócio pela interface | **Não existe seletor** — o painel só mostra o nome do responsável, se já estiver preenchido via API |
| Ver o vínculo negócio↔conversa dentro da própria tela de conversa | **Não existe** — o vínculo existe só no banco de dados; não aparece no painel lateral da conversa |
| Testes automatizados cobrindo o módulo de CRM | Motor de automação (`action_service`, `processor`, `conditions_filter_service`, controller) tem specs; o restante do CRM (deals, pipelines, stages, componentes Vue) **continua sem nenhum teste automatizado** |

## 8.9 Nota de desambiguação importante

A palavra “CRM” aparece em **três lugares diferentes e não relacionados** no código, o que pode gerar confusão:
1. O módulo novo da Aptus (`CrmDeal`, `CrmPipeline`, `CrmStage` — objeto desta seção).
2. Uma feature flag antiga do próprio Chatwoot chamada `crm` que apenas controla a exibição da seção de Contatos (não tem relação com o Kanban).
3. Uma integração antiga e não relacionada do Chatwoot original com um CRM externo chamado **LeadSquared** (`app/services/crm/leadsquared/`), que fica disponível em Configurações → Integrações, desligada por padrão, e não tem nenhuma ligação com o módulo Kanban da Aptus.

Também não foi encontrada nenhuma integração com o **Kommo CRM** (usado pela Aptus com outros clientes) dentro deste módulo — a única menção a "Kommo" encontrada no código é um comentário estético sobre inspiração visual de design, sem relação funcional.

Referências para conferência:
- `app/models/crm_deal.rb`, `crm_pipeline.rb`, `crm_stage.rb`, `crm_deal_conversation.rb`, `crm_automation_rule.rb`, `crm_automation_execution.rb`
- `app/controllers/api/v1/accounts/crm_deals_controller.rb`, `crm_pipelines_controller.rb`, `crm_pipelines/stages_controller.rb`
- `app/policies/crm_deal_policy.rb`, `crm_pipeline_policy.rb`, `crm_stage_policy.rb`
- `app/services/crm/conversation_deal_service.rb`, `default_pipeline_setup_service.rb`
- `app/services/crm_automation_rules/*.rb`, `app/jobs/crm_deal_time_check_job.rb`, `config/schedule.yml`
- `app/javascript/dashboard/components-next/Crm/*`, `app/javascript/dashboard/store/modules/crmDeals/`
- `lib/tasks/crm.rake`

---

# 9. Inboxes e canais de comunicação

## 9.1 Canais disponíveis no assistente de criação de inbox

| Canal | Disponível no assistente? | Credenciais/config necessárias |
|---|---|---|
| Website (Web Widget) | Sim | Nenhuma externa — gerado internamente |
| WhatsApp (Meta Cloud API) | Sim (opção principal) | ID da conta business, chave de API, ID do número; suporta cadastro guiado (“embedded signup”) se configurado, ou manual |
| WhatsApp via Twilio | Sim | `account_sid`, `auth_token` da Twilio |
| WhatsApp via 360dialog | **Só acessível manualmente pela URL** (`?provider=360dialog`) — não aparece como opção no assistente | Mesma estrutura de credenciais do WhatsApp Cloud |
| SMS | Sim | Twilio ou Bandwidth |
| E-mail | Sim | IMAP + SMTP completos |
| API (genérico, ex.: usado com Z-API) | Sim | Identificador e token HMAC gerados automaticamente |
| Telegram | Sim | Token do bot |
| Line | Sim | ID/segredo/token do canal Line |
| Instagram | Sim | Token OAuth (fluxo de conexão via Meta) |
| TikTok | Sim, condicional (só se a instalação tiver App ID do TikTok configurado) | Token OAuth |
| Voz (Voice) | Sim, mas **funcionalidade travada por plano** — feature `channel_voice`, desligada por padrão | Reaproveita credenciais Twilio |
| Facebook | Existe no backend (`Channel::FacebookPage`) | — |
| **Twitter** | **Não aparece mais no assistente** — o backend e as rotas continuam existindo, mas o item foi removido da lista de opções em uma atualização anterior do próprio Chatwoot (não é uma remoção da Aptus) | — |

## 9.2 Fluxo de entrada e saída de mensagens (visão de alto nível)

- **WhatsApp**: mensagens chegam por um endpoint de webhook dedicado, validado por assinatura da Meta, e são processadas em fila de segundo plano; respostas saem por um serviço específico do provedor configurado (Cloud API ou 360dialog).
- **Canal API (genérico)**: não há webhook de entrada dentro do sistema — o sistema externo (ex: uma integração própria da Aptus tipo Z-API) faz uma chamada HTTP diretamente ao endpoint público do Aptus Chat, autenticado por um identificador e token gerados na criação do canal; saída de mensagens pode ser configurada para disparar um webhook de volta ao sistema externo.
- **Chamada de voz via WhatsApp**: pode ser habilitada/desabilitada por inbox; ativa o recurso de ligação dentro da própria tela de conversa.

## 9.3 Indicador de status de conexão

- Canais que dependem de token OAuth (Facebook, Instagram, TikTok, WhatsApp, E-mail via OAuth) mostram um banner vermelho de “reconexão necessária” quando o token expira ou é revogado.
- Para WhatsApp Cloud especificamente, existe uma tela própria de "saúde da conta" mostrando qualidade da conta no WhatsApp, status do nome de exibição, limite de mensagens e se o webhook está configurado corretamente.

## 9.4 Limitações confirmadas

- Canal Twitter existe no backend mas não é oferecido na criação de novas inboxes (decisão já tomada antes da Aptus, relacionada a mudanças na API do X/Twitter).
- WhatsApp 360dialog só é alcançável manualmente digitando a URL — não é uma opção visível.
- Canal de Voz precisa de uma feature paga (desligada por padrão).

Referências para conferência:
- `app/models/channel/*.rb`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/*`
- `app/controllers/webhooks/*.rb`
- `config/features.yml` (`channel_voice`)

---

# 10. Equipes, agentes e distribuição de atendimento

## 10.1 Agentes

- **Criação/convite**: só administrador, pela tela Configurações → Agentes. Não existe limite prático de número de agentes nesta instalação self-hosted.
- **Remoção**: administrador remove o vínculo do agente com a conta; se o usuário não pertencer a nenhuma outra conta na mesma instalação, o registro de usuário inteiro é removido.
- **Mudança de papel**: feita na mesma tela de edição do agente (agente ↔ administrador, ou atribuição de papel customizado, se habilitado).
- **Disponibilidade** (online/offline/ausente): controlada pelo próprio agente; afeta diretamente a distribuição automática de conversas (agentes offline não recebem novas conversas automaticamente).

## 10.2 Times (Teams)

- Criados via assistente de 3 passos: dados do time (nome, ícone/emoji, descrição, opção “permitir atribuição automática”) → adicionar agentes → concluir.
- **Não existe associação direta entre um time e uma inbox** — essa ligação não faz parte do modelo de dados. A forma real de um time “receber” conversas de uma inbox específica é por meio de uma **regra de automação** que, ao detectar uma conversa nova em determinada inbox, executa a ação “atribuir a um time”.

## 10.3 Distribuição automática de conversas

Existem, na prática, **duas gerações de mecanismo de atribuição automática coexistindo no código**, escolhidas automaticamente conforme a configuração da conta:

### Mecanismo simples (legado)
- Ativado por padrão em qualquer inbox com a opção “atribuição automática” ligada.
- Mantém uma fila de round-robin (revezamento) por inbox, alimentada pelos agentes membros daquela inbox.
- Só considera agentes **online** no momento.
- Se a conversa já tiver um time definido, só revezam agentes daquele time.

### Assignment V2 + Política de Atribuição (ativo por padrão nesta instalação)
- Motor mais sofisticado, confirmado como **ativado por padrão** em contas novas (uma migração do banco de dados forçou esse valor).
- Permite configurar, por conta, uma "Política de Atribuição": ordem de atribuição (revezamento simples, ou balanceada — esta última só em plano Enterprise), prioridade de qual conversa atribuir primeiro (mais antiga primeiro, ou tempo de espera), limite de "distribuição justa" (quantas conversas por agente em uma janela de tempo), e idade máxima da conversa a considerar.
- Uma política pode ser vinculada a uma ou mais inboxes.
- **Tela de configuração** (“Agent Assignment”, no menu Configurações) só aparece se a feature `advanced_assignment` estiver ligada na conta — que é uma feature **paga, desligada por padrão**. Ou seja, embora o motor avançado de atribuição já esteja ativo "por baixo dos panos", a tela onde se configuraria manualmente uma política customizada **normalmente não aparece** no menu, a menos que habilitada manualmente.

### Política de Capacidade de Agente (Enterprise, depende de `advanced_assignment`)
- Permite limitar quantas conversas simultâneas um agente pode receber, por inbox.
- Sem uma política de capacidade definida, o agente não tem limite.

## 10.4 Redistribuição

- Quando um agente é removido de uma inbox/time, ele sai imediatamente da fila de revezamento — mas **não foi encontrado** nenhum mecanismo que force a reatribuição de conversas que já estavam com aquele agente. A "redistribuição" automática existente só vale para conversas novas ainda não atribuídas, ou para conversas que voltam a abrir depois de resolvidas/em soneca.

## 10.5 SLA (Acordo de Nível de Serviço)

- Recurso **Enterprise**, com feature flag `sla` **desligada por padrão** (paga).
- Permite definir, por política de SLA: tempo máximo para primeira resposta, tempo máximo para próxima resposta, tempo máximo de resolução, e se isso vale só em horário comercial.
- Quando descumprido, gera notificações internas para os administradores e para quem está na conversa, além de disparar e-mails específicos (ver seção 13).
- Vinculação de uma política de SLA a uma conversa acontece por meio de uma ação de automação/macro — não é vinculada diretamente a inbox ou time.

## 10.6 Horário de atendimento (Business Hours)

Diferente do que o nome da tela “Conversation Workflow” sugere, **horário de atendimento é configurado em outro lugar**: dentro da tela de edição de cada Inbox (Configurações → Inboxes → editar → aba de disponibilidade semanal), não na tela “Conversation Workflow” (ver seção 14 para o que essa tela faz de fato).

Referências para conferência:
- `app/models/team.rb`, `team_member.rb`, `inbox_member.rb`
- `app/services/auto_assignment/*.rb`
- `app/models/assignment_policy.rb`, `inbox_assignment_policy.rb`
- `enterprise/app/models/agent_capacity_policy.rb`, `sla_policy.rb`
- `config/features.yml` (`advanced_assignment`, `assignment_v2`, `sla`)

---

# 11. Automações e regras

## 11.1 Regras de automação (Automation Rules)

**Onde configurar:** Configurações → Automation. **Quem configura:** somente administrador.

**Eventos que podem iniciar uma automação:**
- Conversa criada
- Conversa atualizada
- Conversa aberta
- Conversa resolvida
- Nova mensagem criada

**Condições disponíveis:** conteúdo da mensagem, e-mail do contato, país, status da conversa, tipo de mensagem, idioma do navegador, referenciador (referer), cidade, nome da empresa, inbox, assunto do e-mail, telefone, prioridade, idioma da conversa, labels, nota privada, além de qualquer atributo personalizado criado na conta.

**Ações disponíveis:** enviar mensagem, adicionar/remover label, enviar e-mail para o time, atribuir/remover time, atribuir/remover agente, disparar webhook, silenciar conversa, enviar anexo, mudar status (resolvida/aberta/pendente/soneca), mudar prioridade, enviar transcript por e-mail, adicionar nota privada.

**Execução:** assíncrona (processada por um worker em segundo plano) — se esse worker parar de rodar, nenhuma automação, webhook, notificação ou integração é processada.

**Auto-desativação:** se uma regra referenciar algo que deixou de existir (ex: um atributo personalizado apagado), depois de 2 falhas consecutivas a regra é **desativada automaticamente** e um e-mail de aviso é enviado ao(s) administrador(es).

**Nenhuma automação vem pré-configurada** por padrão em uma conta nova.

## 11.2 Macros

Sequência de ações pré-configurada que o agente executa manualmente sobre uma conversa (via painel lateral ou pelo editor de resposta). Ações suportadas: atribuir time/agente, adicionar/remover label, remover agente/time atribuído, enviar transcript por e-mail, silenciar/soneca/resolver conversa, enviar anexo, enviar mensagem, adicionar nota privada, mudar prioridade, disparar webhook.

## 11.3 Motor de automação do CRM (ver também seção 8.7)

Roda em paralelo ao motor de automação de conversas, mas é **específico dos negócios do CRM**. Desde 23–24/07 tem **tela própria de configuração** (Menu → CRM → Automações, restrita a administrador). Gatilhos por evento (negócio criado/mudou de estágio/entrou em estágio/atualizado/ganho/perdido) e por tempo (data de fechamento próxima, negócio parado), com ações como mudar estágio/funil, atribuir agente, atualizar campo, disparar webhook e enviar mensagem ao lead (texto/mídia/botões/template) na conversa vinculada.

## 11.4 Webhooks de conta/inbox

Configurados em Configurações → Integrações → Webhooks. Eventos disponíveis: mudança de status de conversa, conversa atualizada/criada, contato criado/atualizado, mensagem criada/atualizada, widget acionado, inbox criada/atualizada, digitação ligada/desligada. Cada disparo é assinado digitalmente (HMAC) para o receptor poder validar a origem. **Falhas de entrega não geram retry nem notificação** para webhooks comuns de conta/inbox (diferente dos webhooks de Agent Bot, que têm 3 tentativas automáticas).

Referências para conferência:
- `app/models/automation_rule.rb`, `app/services/automation_rules/*.rb`, `app/listeners/automation_rule_listener.rb`
- `app/models/macro.rb`, `app/services/action_service.rb`
- `app/models/webhook.rb`, `app/listeners/webhook_listener.rb`, `lib/webhooks/trigger.rb`
- `app/services/crm_automation_rules/*.rb`, `app/jobs/crm_deal_time_check_job.rb`

---

# 12. Notificações

## 12.1 Tipos de notificação existentes

| Tipo | Evento que dispara |
|---|---|
| `conversation_creation` | Nova conversa criada em inbox/time do usuário |
| `conversation_assignment` | Conversa atribuída ao usuário |
| `conversation_mention` | Usuário mencionado (`@`) em uma conversa |
| `assigned_conversation_new_message` | Nova mensagem em conversa atribuída ao usuário (só dispara se o agente **não** estiver online) |
| `participating_conversation_new_message` | Nova mensagem em conversa na qual o usuário participa (mesma regra de "não estar online") |
| `sla_missed_first_response` / `sla_missed_next_response` / `sla_missed_resolution` | Descumprimento de SLA (Enterprise, só relevante se SLA estiver habilitado) |

Toda notificação sempre gera um registro interno (in-app), independente da preferência do usuário. E-mail e push são opcionais, configuráveis individualmente por tipo.

## 12.2 Canais de notificação

- **Dentro da plataforma**: contador de não lidas exibido como selo no item “Inbox” do menu (não há mais um sino dedicado — ver seção 2).
- **E-mail**: um e-mail por notificação, respeitando a preferência do usuário (ver seção 13 para a tabela completa).
- **Push no navegador**: funciona via Web Push (chaves geradas automaticamente pelo próprio sistema, sem necessidade de configuração externa).
- **Push mobile (Firebase/FCM)**: depende de configuração externa (projeto e credenciais do Firebase) que **não está configurada** nesta instalação — portanto push mobile não funciona até essa configuração ser feita pelo Super Admin.
- **Som**: configurável por usuário (tom, evento que dispara, se toca só quando a aba está inativa ou só quando há conversas não lidas).

## 12.3 Onde o usuário configura suas preferências

Configurações Pessoais → Notificações (ver seção 15), com uma matriz de Email × Push para cada tipo de notificação. As três categorias de SLA só aparecem nessa tela se a conta tiver a funcionalidade de SLA habilitada.

Referências para conferência:
- `app/models/notification.rb`, `app/models/notification_setting.rb`
- `app/javascript/dashboard/routes/dashboard/settings/profile/NotificationPreferences.vue`
- `lib/vapid_service.rb`, `app/services/notification/fcm_service.rb`

---

# 13. Relatório completo de disparos de e-mail

> **Observação geral crítica**: praticamente **todo** e-mail do sistema passa por uma verificação central que só permite o envio se houver um servidor SMTP configurado (`SMTP_ADDRESS`) — ou se o ambiente for de desenvolvimento. **Em produção, sem SMTP configurado, nenhum e-mail é enviado, silenciosamente** (a falha é apenas registrada em log, não gera alerta). Além disso, **todos os e-mails do sistema saem em português (pt_BR), independentemente do idioma configurado na conta** — é uma customização específica desta instalação (o mecanismo original de escolher o idioma pela conta ficou sem uso).

| E-mail | Evento que dispara | Destinatário | Condições | Pode ser desativado? | Onde configurar | Referência |
|---|---|---|---|---|---|---|
| Confirmação de conta / “convite” de agente | Agente cadastrado (por convite do admin) ou signup | O próprio agente/usuário | Requer SMTP configurado | Não há preferência do usuário — é obrigatório para ativar a conta | — | `app/models/user.rb`, mecanismo padrão de confirmação de e-mail |
| Redefinição de senha | Usuário solicita “esqueci minha senha” | O próprio usuário | Requer SMTP | Não | — | `app/controllers/devise_overrides/passwords_controller.rb` |
| Nova conversa | Conversa criada em inbox/time do usuário | Agente/administrador (conforme preferência) | Preferência de notificação por e-mail ligada | Sim, por tipo | Configurações Pessoais → Notificações | `AgentNotifications::ConversationNotificationsMailer#conversation_creation` |
| Atribuição de conversa | Conversa atribuída ao usuário | Agente | Preferência ligada | Sim | Config. Pessoais → Notificações | `#conversation_assignment` |
| Menção | Usuário mencionado em uma conversa | Agente mencionado | Preferência ligada | Sim | Config. Pessoais → Notificações | `#conversation_mention` |
| Nova mensagem (conversa atribuída) | Nova mensagem em conversa do usuário | Agente | Preferência ligada + agente **não** estar online | Sim | Config. Pessoais → Notificações | `#assigned_conversation_new_message` |
| Nova mensagem (participando) | Nova mensagem em conversa que o usuário participa | Agente | Preferência ligada + não estar online | Sim | Config. Pessoais → Notificações | `#participating_conversation_new_message` |
| SLA descumprido (1ª resposta / próxima resposta / resolução) | Descumprimento de política de SLA | Participantes da conversa + administradores + responsável | Requer SLA habilitado (Enterprise, off por padrão) | Sim | Config. Pessoais → Notificações (categoria SLA) | `enterprise/.../conversation_notifications_mailer.rb` |
| Resposta por e-mail ao contato | Agente responde em conversa de canal de e-mail | O contato (cliente final) | Requer SMTP ou IMAP configurado | Não (é a própria função do canal) | — | `ConversationReplyMailer#email_reply` |
| Resposta com resumo (contato offline, Widget/API) | Nova mensagem outgoing, contato não visualizou | O contato, se tiver e-mail cadastrado | Contato não visualizou a mensagem; aguarda 2 minutos antes de enviar | Depende da config. do canal | Config. da inbox (continuidade por e-mail) | `#reply_with_summary` / `#reply_without_summary` |
| Transcript de conversa por e-mail | Agente/contato solicita envio do histórico | E-mail informado | Requer `email_transcript_enabled` na conta | — | — | `#conversation_transcript` |
| Importação de contatos concluída/falhou | Fim do processamento de import CSV | Quem iniciou a importação | Requer SMTP | Não | — | `AccountNotificationMailer#contact_import_complete/_failed` |
| Exportação de contatos concluída | Fim do processamento de export CSV | Quem iniciou a exportação | Requer SMTP | Não | — | `#contact_export_complete` |
| Automação desativada automaticamente | Regra de automação falhou 2x seguidas | Administradores | Requer SMTP | Não | — | `#automation_rule_disabled` |
| Canal desconectado (Facebook/Instagram/TikTok/WhatsApp/E-mail) | Token/autorização do canal expirou | Administradores | Requer SMTP | Não | — | `ChannelNotificationsMailer#*_disconnect` |
| Integração desconectada (Slack/Dialogflow) | Hook perdeu autorização | Administradores | Requer SMTP | Não | — | `IntegrationsNotificationMailer#slack_disconnect/dialogflow_disconnect` |
| Integração OpenAI desconectada | Chave de API do OpenAI inválida | Administradores | **Só dispara se alguém rodar manualmente um job de migração** — não há gatilho automático | Não | — | `#openai_disconnect`, `app/jobs/migration/validate_openai_hooks_job.rb` |
| Instruções de domínio (CNAME) da Central de Ajuda | Configuração de domínio customizado do Portal | Quem solicitou | **Tela de origem está oculta do menu (Portals/Help Center — APTUS-HIDDEN)** — backend ainda ativo, mas não há caminho de navegação até ele | — | — | `PortalInstructionsMailer#send_cname_instructions` |
| Solicitação de exclusão de conta | Conta marcada para exclusão | Administrador que solicitou | Requer SMTP | Não | — | `AccountNotificationMailer#account_deletion_user_initiated/_for_inactivity` |
| Conta efetivamente excluída | Job diário processa contas marcadas há 7+ dias | E-mail do administrador da instalação (`CHATWOOT_INSTANCE_ADMIN_EMAIL`) | **Não configurado nesta instalação — e-mail não é enviado até essa variável ser definida** | — | Painel Super Admin | `AccountComplianceMailer#account_deleted` |

## Ações que parecem importantes, mas não disparam e-mail

- **Convite de agente**: não existe um e-mail de "convite" dedicado e personalizado — o sistema reaproveita o e-mail padrão de confirmação de cadastro. Não foi identificado um segundo e-mail avisando "você foi convidado para a conta X".
- **Mudança de papel de um agente** (de agente para administrador, por exemplo): não foi identificado disparo de e-mail avisando o próprio agente sobre a mudança.
- **Movimentação de um negócio no CRM** (mudança de estágio, ganho, perdido): existe notificação interna prevista no motor de automação do CRM, mas a ação "enviar e-mail" dessa automação **não foi implementada** — apenas registra um aviso de "não implementado" no log. **Não foi identificado disparo de e-mail relacionado.**
- **Webhook de conta/inbox com falha de entrega**: o código apenas registra a falha em log; **não foi encontrado envio de e-mail de alerta**.
- **Exclusão de conversa**: não dispara e-mail a ninguém.
- **Alteração de senha pelo próprio usuário (dentro da conta logada)**: não foi encontrada uma notificação por e-mail confirmando a alteração.
- **Criação/edição/exclusão de negócio, funil ou estágio no CRM**: nenhum e-mail identificado.

Referências para conferência:
- `app/mailers/*.rb`, `enterprise/app/mailers/**/*.rb`
- `app/mailers/application_mailer.rb` (gate universal de SMTP + locale fixo em pt_BR)
- `app/services/notification/email_notification_service.rb`
- `app/models/concerns/reauthorizable.rb`

---

# 14. Configurações da conta

## 14.1 Account Settings (dados gerais)

**Como acessar:** Configurações → Account Settings. **Quem acessa:** somente administrador.
Campos: nome da conta, idioma (afeta a interface, não os e-mails — ver seção 13), domínio de resposta customizado (condicional a feature paga), e-mail de suporte customizado (condicional a feature paga). Seções adicionais: ID da conta (exibição), transcrição de áudio (só aparece com integração Captain ativa — praticamente nunca, já que Captain está oculto/desligado), exclusão de conta (só em Chatwoot Cloud — nunca aparece neste self-hosted), informações de versão/build.
**Não existe campo de fuso horário** nesta tela.

## 14.2 Demais telas de Configurações (tabela consolidada)

| Tela | O que permite configurar | Quem acessa | Condição |
|---|---|---|---|
| Agents | Convidar/editar/remover agentes, papel, disponibilidade | Admin | — |
| Teams | Criar/editar/excluir times e seus membros | Admin | — |
| Agent Assignment | Política de atribuição (ordem, prioridade, limites) e capacidade de agente | Admin | Item de menu só visível com `advanced_assignment` ligada (off por padrão) |
| Inboxes | Criar/editar/excluir inboxes, credenciais de canal, agentes por inbox, horário de atendimento (por inbox) | Admin | — |
| Labels | Criar/editar/excluir etiquetas, cor, se aparece no menu lateral | Admin (visualizar liberado a agente) | — |
| Custom Attributes | Criar campos personalizados para Conversa / Contato / Negócio (aba "Empresa" existe no backend mas não tem aba na UI, coerente com Companies oculto) | Admin (visualizar liberado a agente) | — |
| Automation | Criar/editar/clonar/ativar-desativar/excluir regras de automação | Admin | — |
| Agent Bots | Criar bots que respondem via webhook (nome, descrição, URL, token/segredo) | Admin (visualizar liberado a agente) | — |
| Macros | Criar sequências de ações reutilizáveis | Agente (próprias) / Admin (globais) | — |
| Canned Responses | Respostas prontas com atalho | Admin (visualizar liberado a agente) | — |
| Integrations | Conectar/configurar integrações externas (ver seção 19) | Admin | — |
| Audit Logs | Ver trilha de auditoria de mudanças na conta | Admin | Depende de `audit_logs` (off por padrão) — sem essa flag, a tela fica vazia |
| Custom Roles | Criar papéis customizados com permissões granulares | Admin | Depende de `custom_roles` (off por padrão) — mostra tela de bloqueio sem a flag |
| SLA | Criar políticas de SLA (tempos de resposta/resolução) | Admin | Depende de `sla` (off por padrão) — mostra tela de bloqueio sem a flag |
| Conversation Workflow | **Auto-resolução de conversas inativas** (tempo de inatividade, mensagem automática, label ao resolver) + **Atributos obrigatórios antes de resolver conversa** | Admin | Auto-resolução ativa por padrão; atributos obrigatórios dependem de feature paga (off por padrão) |
| Security | Configuração de login único corporativo (SSO/SAML) | Admin | Depende de `saml` (off por padrão) e do plano da instalação (hoje "community") — na prática mostra mensagem de indisponibilidade |
| Billing | Assinatura/plano (Stripe), créditos | Admin | **Só funciona em Chatwoot Cloud** — nesta instalação self-hosted, a tela redireciona sozinha de volta para a Inbox assim que é aberta |

Referências para conferência:
- `app/javascript/dashboard/routes/dashboard/settings/*/Index.vue`
- `config/features.yml`

---

# 15. Configurações pessoais do usuário

**Como acessar:** Menu de perfil (avatar) → Profile Settings.

| Item | O que faz | Consequência da alteração |
|---|---|---|
| Nome, foto de perfil | Dados básicos exibidos para outros agentes/contatos | Some se a instalação desabilitar edição de perfil |
| Idioma da interface | Muda o idioma do painel para o próprio usuário | Não afeta os e-mails, que sempre saem em pt_BR |
| Tamanho de fonte | Preferência visual | — |
| **Assinatura de mensagem** | — | **Escondido (APTUS-HIDDEN)** — a coluna ainda existe no banco, mas não há mais campo para editá-la |
| Atalho de envio de mensagem (Enter vs. Cmd+Enter) | Preferência de digitação | — |
| Alterar senha | Troca a senha de acesso | — |
| Autenticação em duas etapas (2FA) | Ativação de segundo fator | **Presente no código, mas inativo nesta instalação** — depende de variáveis de ambiente de criptografia que não estão configuradas; a seção fica invisível até isso ser corrigido |
| Sessões ativas | Lista dispositivos/navegadores logados, com localização/última atividade; permite revogar sessões individualmente | Revogar desconecta aquele dispositivo imediatamente |
| Notificações (Email/Push por tipo) | Matriz de preferências (ver seção 12) | Afeta quais e-mails/pushes o usuário recebe |
| Notificações de áudio | Som, evento que dispara, condição (aba inativa, não lidas) | — |
| Token de API pessoal | Mostra e permite resetar o token pessoal de acesso à API | Resetar invalida integrações que usavam o token antigo |
| Disponibilidade (online/offline/ausente) | Controlada por um seletor separado (não fica dentro desta tela de perfil) | Afeta se o usuário recebe novas conversas por atribuição automática |

Referências para conferência:
- `app/javascript/dashboard/routes/dashboard/settings/profile/*.vue`
- `app/models/concerns/access_tokenable.rb`, `app/models/user_session.rb`

---

# 16. Área administrativa global (Super Admin)

**Como acessar:** URL `/super_admin`, com um login próprio (mesmo mecanismo de autenticação, rota e sessão separadas do painel de conta).
**Quem acessa:** Usuários com a coluna de tipo marcada como Super Admin (não é uma role de conta — é um nível acima, da instalação inteira).
**Tecnologia:** construído com a gem `administrate` (não é ActiveAdmin nem RailsAdmin).

| Área | O que permite |
|---|---|
| Dashboard | Contagem total de contas/usuários/inboxes/conversas + gráfico dos últimos 30 dias |
| Accounts | CRUD de contas; **popular conta com dados de exemplo** (ação "Seed"); resetar cache; excluir conta; editar limites; **ligar/desligar qualquer feature flag por conta específica** (inclusive as pagas, como Custom Roles, SLA, SAML, Audit Logs, Advanced Assignment) |
| Users | CRUD de usuários; **promover/rebaixar um usuário a Super Admin**; remover avatar |
| Account Users | Criar/remover vínculo usuário↔conta; definir papel diretamente |
| Access Tokens | Visualização (somente leitura) dos tokens de API pessoais de todos os usuários da instalação |
| Agent Bots | CRUD de Agent Bots globais |
| App Configs | Configurar credenciais globais de integrações sensíveis (Facebook, Shopify, Microsoft, E-mail, Linear, Slack, Instagram, TikTok, WhatsApp embedded, Notion, Google, Captain) |
| Installation Configs | CRUD genérico de qualquer configuração chave/valor da instalação |
| Instance Status | Edição atual (Community/Enterprise/Custom), versão, hash do git, status do banco Postgres, métricas do Redis, migrações pendentes |
| Platform Apps | CRUD de aplicativos OAuth de terceiros que consomem a API da plataforma |
| Platform Banners | **Só funciona em Chatwoot Cloud** — bloqueado neste self-hosted |
| Push Diagnostics | Testar/apagar inscrições de notificação push de um usuário específico |
| Settings | Ver status e forçar verificação de novas versões |
| Sidekiq | Painel de monitoramento das filas de processamento em segundo plano (`/super_admin/monitoring/sidekiq`) |

**Impersonação de usuário**: um Super Admin pode "logar como" qualquer usuário da instalação (função de suporte/depuração), gerando um token de sessão de curta duração — confirmado ativo no código.

Referências para conferência:
- `app/controllers/super_admin/*.rb`, `app/models/super_admin.rb`, `app/dashboards/*.rb`
- `config/routes.rb` (bloco `/super_admin`)

---

# 17. Busca, filtros e organização

- **Campos pesquisáveis globalmente**: conversas (por número, e por nome/e-mail/telefone/identificador do contato), mensagens (conteúdo), contatos, artigos de central de ajuda (mesmo com a seção de Central de Ajuda oculta do menu, a busca por artigos continua no componente).
- **Filtros combináveis**: sim — o filtro avançado de conversas e contatos permite combinar múltiplas condições (status, atributos, labels, etc.).
- **Filtros salvos**: sim, chamados de "Pastas" (conversas) ou "Segmentos" (contatos) — ficam disponíveis permanentemente no menu lateral depois de criados, por usuário/conta.
- **Filtros rápidos**: abas fixas (Minhas/Não atribuídas/Todas em conversas; Todos/Ativos em contatos).
- **Ordenação**: por atividade mais recente ou por não lidas primeiro (conversas); customizável em outras listagens.
- **Paginação**: 25 itens por página nas principais listagens (conversas, contatos, audit logs).
- **Limpar filtros**: cada tela de filtro avançado tem sua opção de reset, dentro do próprio componente de filtro.

Referências para conferência:
- `app/services/search_service.rb`
- `app/models/custom_filter.rb`

---

# 18. Importação, exportação e relatórios

## 18.1 Importação e exportação

| Recurso | Formato | Como acessar | Notificação |
|---|---|---|---|
| Importação de contatos | CSV (com modelo de exemplo para download) | Contatos → Importar | E-mail de conclusão/falha |
| Exportação de contatos | CSV | Contatos → Exportar | E-mail de conclusão |
| Exportação de conversas | **Não foi encontrada** uma funcionalidade de exportação de conversas na navegação ativa | — | — |

## 18.2 Relatórios (Reports)

A seção de Relatórios do Chatwoot original (visão geral, conversas, agentes, labels, inboxes, times, CSAT, SLA, bot) está **oculta do menu (APTUS-HIDDEN)**. Importante registrar: o backend de relatórios continua com a feature flag ligada por padrão, e as rotas do frontend continuam registradas no roteador — ou seja, tecnicamente alguém navegando direto para a URL, ou usando a paleta de comandos (`Cmd/Ctrl+K`), ainda consegue abrir essas telas mesmo sem link no menu (ver seção 21). Isso deve ser validado/decidido pelo time de produto.

## 18.3 Métricas e produtividade

Como Relatórios está oculto, não há hoje um caminho de navegação normal para métricas de tempo de resposta, volume de conversas, produtividade por agente/time, etc., mesmo que o motor de cálculo desses números continue ativo no backend.

Referências para conferência:
- `app/controllers/api/v1/accounts/contacts_controller.rb` (`import`/`export`)
- `app/jobs/data_import_job.rb`, `app/jobs/account/contacts_export_job.rb`
- `app/javascript/dashboard/routes/dashboard/settings/reports/reports.routes.js`

---

# 19. Integrações disponíveis

| Integração | Disponível por padrão? | O que faz | Dependências |
|---|---|---|---|
| Webhook genérico | Sim | Dispara eventos HTTP para uma URL configurada | Nenhuma |
| Dashboard Apps | Sim | Exibe um aplicativo externo em iframe no painel lateral da conversa | Nenhuma |
| Google Translate | Sim | Traduz mensagens dentro da conversa | Credenciais próprias inseridas no formulário |
| Dialogflow | Sim | Conecta um agente conversacional do Google Dialogflow à inbox | Credenciais próprias no formulário |
| Dyte | Sim | Chamadas de vídeo | Credenciais próprias |
| OpenAI | Aparece disponível, mas **funcionalmente inerte** | Antes usada para sugestão de labels; essa função foi migrada para o recurso "Captain", que está oculto (APTUS-HIDDEN) — hoje aceitar a chave de API não gera nenhuma ação real | — |
| Slack | Precisa de configuração global ausente | Espelha conversas em canais do Slack | Requer credencial global configurada pelo Super Admin (ausente nesta instalação) |
| Linear | Desligada por padrão (feature paga) | Cria/vincula issues do Linear a partir de conversas | Feature flag + credencial global |
| Notion | Desligada por padrão (feature paga) | Integração com Notion | Feature flag + credencial global; **nenhum processamento de evento foi encontrado no código**, sugerindo funcionalidade incompleta mesmo se habilitada |
| Shopify | Desligada por padrão (feature interna do Chatwoot Cloud) | Mostra pedidos do Shopify no painel da conversa | Uso interno do Chatwoot Cloud, não relevante para self-hosted |
| LeadSquared (CRM externo) | Desligada por padrão | Sincroniza contatos/leads com o CRM LeadSquared | Feature flag; **não tem relação com o módulo de CRM Kanban da Aptus** (ver seção 8.9) |
| Agent Bots (bots via webhook) | Sim | Mecanismo para conectar um bot externo (ex: um bot próprio da Aptus) que recebe eventos de mensagem via webhook e responde através da API do sistema | Nenhuma configuração externa fixa — cada bot define sua própria URL de webhook |

Referências para conferência:
- `config/integration/apps.yml`
- `app/models/integrations/app.rb`, `app/models/integrations/hook.rb`
- `app/models/agent_bot.rb`, `app/jobs/agent_bots/webhook_job.rb`

---

# 20. Comportamentos automáticos e processos em segundo plano

| Comportamento | Evento inicial | Resultado |
|---|---|---|
| Criação automática de negócio no CRM | Nova conversa criada | Card criado no funil padrão, vinculado ao contato |
| Criação automática do funil padrão | Nova conta criada | Funil "Funil de Atendimento" com 6 estágios em português |
| Auto-resolução de conversas inativas | Conversa sem atividade por X tempo (configurável) | Conversa marcada como resolvida, com mensagem automática e label opcional |
| Reabertura de conversa | Contato responde a conversa em soneca ou resolvida | Volta para aberta (ou pendente, se a inbox tiver bot ativo) |
| Atribuição automática de conversa | Nova conversa sem responsável, em inbox com atribuição automática ligada | Atribuída a um agente disponível via revezamento (round-robin) |
| Verificação periódica de SLA | A cada execução do job agendado | Marca SLA como cumprido/descumprido, dispara notificações se descumprido (se habilitado) |
| Verificação de negócios parados/data de fechamento próxima (CRM) | Job diário às 8h | Executa regras de automação do CRM baseadas em tempo |
| Sincronização de e-mails IMAP | A cada 1 minuto | Busca novas mensagens em inboxes de e-mail configuradas |
| Limpeza de notificações antigas | Diariamente | Remove notificações com mais de 1 mês; limita a 300 por usuário |
| Limpeza de contatos/chaves órfãs | Diariamente | Remove vínculos de contato-inbox obsoletos e chaves antigas do Redis |
| Exclusão efetiva de conta marcada | Diariamente, 7 dias após solicitação | Remove a conta e dispara e-mail de confirmação (se configurado) |
| Desativação automática de regra de automação | 2 falhas consecutivas de validação | Regra desativada + e-mail de aviso ao(s) administrador(es) |
| Reconexão de canal necessária | Token OAuth expira/é revogado | Banner de aviso na tela de Inboxes + e-mail ao(s) administrador(es) |
| Sincronização de templates do WhatsApp | Periodicamente (job agendado) | Atualiza a lista de templates HSM aprovados disponíveis para uso |

Referências para conferência:
- `config/schedule.yml`
- `app/jobs/*.rb`, `enterprise/app/jobs/**/*.rb`

---

# 21. Funcionalidades condicionais

| Funcionalidade | Tipo de condição | Estado atual nesta instalação |
|---|---|---|
| Papéis Customizados | Feature flag paga (`custom_roles`) | **Inativa** por padrão |
| SLA | Feature flag paga (`sla`) | **Inativa** por padrão |
| SSO/SAML (Security) | Feature flag paga (`saml`) + plano da instalação | **Inativa** por padrão |
| Audit Logs | Feature flag paga (`audit_logs`) | **Inativa** por padrão (tela some vazia) |
| Política de Capacidade de Agente / item de menu "Agent Assignment" | Feature flag paga (`advanced_assignment`) | **Inativa** por padrão — o item de menu correspondente costuma ficar totalmente invisível |
| Assignment V2 (motor de atribuição mais avançado) | Feature flag (`assignment_v2`) | **Ativa** por padrão (forçada por uma migração de banco) |
| Canal de Voz | Feature flag paga (`channel_voice`) | **Inativa** por padrão |
| Atributos obrigatórios antes de resolver conversa | Feature flag paga (`conversation_required_attributes`) | **Inativa** por padrão |
| Autenticação em duas etapas (2FA) | Configuração de ambiente (chaves de criptografia) | **Inativa** — variáveis não configuradas |
| Push mobile (Firebase) | Configuração externa (projeto/credenciais Firebase) | **Inativa** — não configurado |
| Slack (integração) | Configuração global (Super Admin) | **Inativa** — credencial ausente |
| Linear / Notion / Shopify / LeadSquared (integrações) | Feature flag paga | **Inativas** por padrão |
| Billing | Tipo de instalação (só Chatwoot Cloud) | **Inativa/rota morta** neste self-hosted |
| Reports / Campaigns / Companies / Portals (Help Center) / Captain | Removidos da navegação (APTUS-HIDDEN) | **Escondidos** — mas os backends de Reports, Campaigns e Help Center continuam com feature flag `enabled: true`, e as rotas do frontend continuam registradas no roteador |
| Webhook de instalação (eventos globais) | Configuração ausente (`INSTALLATION_EVENTS_WEBHOOK_URL`) | **Inativa** |
| E-mail de conta excluída definitivamente | Configuração ausente (`CHATWOOT_INSTANCE_ADMIN_EMAIL`) | **Inativa** |
| Envio de qualquer e-mail em produção | Configuração de SMTP (`SMTP_ADDRESS`) | **Necessita validação** — depende do ambiente de produção real, não verificável só pelo código |

> **Observação de segurança/produto a destacar**: como a ocultação de Reports, Campaigns, Companies, Portais e Captain foi feita **apenas removendo os links do menu lateral**, e não desativando as respectivas feature flags nem removendo as rotas do roteador do frontend, essas telas continuam **tecnicamamente alcançáveis** por quem souber a URL direta ou usar a paleta de comandos (`Cmd/Ctrl+K`). Isso deve ser considerado no planejamento de segurança/produto — ver recomendação na seção 27.

Referências para conferência:
- `config/features.yml`
- `app/javascript/dashboard/helper/routeHelpers.js`
- `app/javascript/dashboard/composables/commands/useGoToCommandHotKeys.js`

---

# 22. Funcionalidades parcialmente implementadas

| Funcionalidade | O que está pronto | O que falta |
|---|---|---|
| Edição completa de um negócio do CRM | Nome, estágio e atributos personalizados editáveis pela interface | Valor, moeda, data de fechamento, probabilidade, contato vinculado e responsável **não têm campo na interface** (só acessíveis via chamada direta à API) |
| Vínculo negócio↔conversa | Existe no banco de dados (toda conversa gera um negócio) | Não aparece em nenhum lugar da tela de conversa — só é visível entrando pelo card do CRM |
| Ação "enviar e-mail ao responsável" e "adicionar nota" (automação do CRM) | Estrutura da ação existe | Implementação real ausente — apenas grava um aviso de "não implementado" |
| Integração OpenAI | Tela de configuração de API key existe e aceita salvar | Não dispara nenhuma ação real (dependia do recurso Captain, que está oculto) |
| Integração Notion | Tela existe, aceita credenciais | Não foi encontrado nenhum processamento de evento no backend |
| Segurança (SSO/SAML) | Tela e lógica de configuração completas | Inoperante sem configuração adicional de backend e mudança de plano da instalação |
| Autenticação em duas etapas (2FA) | Modelo de dados, serviços e tela completos | Invisível/inoperante até configurar variáveis de ambiente de criptografia |
| Rascunho de mensagem via API dedicada | Endpoint de backend existe (salva rascunho em Redis por conversa) | O painel web não usa esse endpoint — salva o rascunho só localmente no navegador; parece destinado a outro cliente (app mobile?), não confirmado |
| Draft channel Twitter / WhatsApp 360dialog no assistente de inbox | Backend e componentes de configuração existem e funcionam | Removidos da lista de opções do assistente — só acessíveis manipulando a URL manualmente |
| Auditoria de mudanças no próprio usuário (nome/e-mail/disponibilidade) | Configuração de auditoria presente no código | Uma condição no código sempre bloqueia o registro — na prática, essas mudanças nunca são auditadas mesmo com a feature ligada |

Referências para conferência:
- `app/services/crm_automation_rules/*.rb`
- `app/javascript/dashboard/components-next/Crm/components/CrmDealForm.vue`
- `enterprise/app/models/enterprise/audit/user.rb`
- `app/models/integrations/hook.rb`

---

# 23. Glossário do sistema

| Termo | Significado |
|---|---|
| **Conta (Account)** | A empresa-cliente dentro da plataforma; cada conta tem seus próprios agentes, inboxes, contatos e configurações. |
| **Usuário (User)** | Pessoa da equipe que acessa o painel (agente, administrador ou super admin). |
| **Agente (Agent)** | Papel padrão de quem atende conversas. |
| **Administrador (Administrator)** | Papel com controle total sobre a conta. |
| **Super Admin** | Administra a instalação inteira (todas as contas), não uma conta específica. |
| **Contato (Contact)** | Pessoa (cliente final) que troca mensagens pelos canais — não acessa o painel. |
| **Empresa (Company)** | Entidade para agrupar contatos por organização — hoje oculta do menu. |
| **Negócio/Lead (Deal)** | Card do quadro de CRM, representando uma oportunidade em andamento. |
| **Funil (Pipeline)** | Conjunto de estágios pelos quais um negócio passa. |
| **Estágio (Stage)** | Etapa dentro de um funil (ex: "Em Atendimento"). |
| **Conversa (Conversation)** | Uma troca de mensagens entre um contato e a equipe, dentro de uma inbox. |
| **Inbox** | Um canal configurado (ex: um número de WhatsApp, uma caixa de e-mail). |
| **Canal (Channel)** | O tipo de meio de comunicação (WhatsApp, e-mail, site, etc.). |
| **Time (Team)** | Agrupamento de agentes para fins de atribuição de conversas. |
| **Label (Etiqueta)** | Marcação aplicável a conversas ou contatos, para organização. |
| **Atributo Personalizado (Custom Attribute)** | Campo extra criado pela conta, aplicável a conversa, contato ou negócio. |
| **Automação (Automation Rule)** | Regra que reage a um evento de conversa e executa ações automaticamente. |
| **Macro** | Sequência de ações pré-configurada, executada manualmente pelo agente. |
| **Webhook** | Mecanismo de notificação HTTP automática para um sistema externo, quando um evento ocorre. |
| **Integração (Integration)** | Conexão com um serviço externo (Slack, Dialogflow, etc.). |
| **Status** | Estado da conversa: aberta, pendente, resolvida ou em soneca. |
| **Prioridade** | Nível de urgência de uma conversa: baixa, média, alta, urgente. |
| **SLA** | Acordo de nível de serviço — tempos máximos de resposta/resolução esperados. |
| **Agent Bot** | Bot conectado via webhook que pode responder automaticamente a conversas. |

---

# 24. Fluxos práticos por tipo de usuário

## Fluxo do administrador

1. Entrar na plataforma pela tela de login.
2. Acessar Configurações → Account Settings e ajustar nome/idioma da conta.
3. Ir em Configurações → Agentes e convidar os membros da equipe.
4. Ir em Configurações → Teams e criar um time, adicionando os agentes.
5. Ir em Configurações → Inboxes e configurar um canal (ex: WhatsApp).
6. Associar agentes à inbox recém-criada.
7. Ir em Configurações → Labels e Custom Attributes para organizar a operação.
8. Acompanhar as conversas pela tela “Inbox”/“Conversation”.
9. Acessar o menu “CRM” para acompanhar os negócios gerados automaticamente pelas conversas.
10. Revisar Configurações → Automation para reduzir trabalho manual, e Configurações → Audit Logs/Security conforme necessidade (lembrando que várias dessas dependem de habilitar a feature correspondente).

## Fluxo do atendente (agente)

1. Entrar na plataforma.
2. Abrir “Inbox” ou a aba “Minhas” em Conversas.
3. Abrir uma conversa atribuída a ele.
4. Consultar as informações do contato no painel lateral “Contato”.
5. Responder a mensagem (texto, anexo, áudio, resposta pronta ou macro).
6. Inserir uma nota interna, se precisar registrar algo só para a equipe.
7. Ir até o menu “CRM” e atualizar o estágio do negócio vinculado, se aplicável.
8. Transferir a conversa para outro agente/time, se necessário.
9. Resolver a conversa (preenchendo atributos obrigatórios, se a conta exigir).

## Fluxo do super administrador (instalação)

1. Entrar em `/super_admin` com o login de super admin.
2. Consultar o Dashboard para visão geral da instalação.
3. Acessar “Accounts” para criar uma nova conta-cliente, ou popular uma conta existente com dados de exemplo (“Seed”).
4. Habilitar manualmente, se necessário, alguma feature paga para uma conta específica (Custom Roles, SLA, SAML, Audit Logs, etc.).
5. Configurar credenciais globais de integrações (Slack, Linear, Notion, etc.) em “App Configs”.
6. Monitorar filas de processamento em segundo plano pelo painel Sidekiq.

Referências para conferência:
- Ver referências já citadas nas seções 3, 6, 8, 10 e 16.

---

# 25. Inventário geral de funcionalidades

| Área | Funcionalidade | Como acessar | Usuários autorizados | Status | Dispara e-mail? | Observações |
|---|---|---|---|---|---|---|
| Conversas | Atendimento multicanal | Menu → Inbox/Conversation | Agente/Admin | Disponível | Sim (canais de e-mail) | — |
| Conversas | Exclusão de conversa | Botão no card/menu de ações | Admin | Disponível | Não | Restrito por policy + UI |
| Conversas | Atributos obrigatórios antes de resolver | Automático ao resolver | Agente/Admin | Disponível com condição | Não | Feature paga, off por padrão |
| Contatos | CRUD, import/export, merge, segmentos | Menu → Contacts | Agente (CRUD)/Admin (import/export) | Disponível | Sim (import/export) | — |
| Empresas (Companies) | Vínculo contato-empresa | — | — | Escondido (APTUS-HIDDEN) | — | Backend intacto |
| CRM | Kanban de negócios/funis/estágios | Menu → CRM → Funil | Agente (negócios)/Admin (funis) | Disponível | Não | Funcionalidade nova da Aptus |
| CRM | Automação de negócios (motor + UI) | Menu → CRM → Automações | Admin | Disponível | Não | UI completa desde 23–24/07 (ver 8.7) |
| Hub | Portal do bot/cliente (desempenho, teste, pagamentos) | Menu → Hub | Agente/Admin, só se habilitado por conta | Disponível com condição | Não | Módulo novo, 23–24/07 (ver seção 28) |
| Hub | Conta só-Hub (`hub_only`) — cliente sem mensageria | Super Admin → Accounts → Aptus Hub | Configurado pelo Super Admin; conta com 1 admin | Disponível com condição | Não | Esconde e bloqueia todo o resto do produto (ver 3.4 e 28.7) |
| Inboxes | Canais (WhatsApp, e-mail, site, etc.) | Configurações → Inboxes | Admin | Disponível | — | Twitter/360dialog fora do assistente |
| Inboxes | Canal de voz | Configurações → Inboxes | Admin | Disponível com condição | — | Feature paga, off por padrão |
| Times/Agentes | Convite, papéis, times, distribuição automática | Configurações → Agents/Teams | Admin | Disponível | Sim (confirmação) | — |
| Times/Agentes | Política de Atribuição avançada / Capacidade | Configurações → Agent Assignment | Admin | Disponível com condição | Não | Item de menu geralmente invisível (feature paga) |
| Automação | Regras de automação de conversas | Configurações → Automation | Admin | Disponível | Sim (desativação automática) | — |
| Automação | Macros | Configurações → Macros / dentro da conversa | Agente/Admin | Disponível | Não | — |
| Notificações | In-app, e-mail, push navegador | Config. Pessoais → Notificações | Todos | Disponível | Sim | Push mobile depende de config. externa ausente |
| E-mails | Ver seção 13 | — | — | Disponível com condição | Sim | Depende de SMTP configurado |
| Configurações da conta | Dados gerais, canais, labels, atributos, automações, integrações | Configurações | Admin | Disponível | — | — |
| Configurações pessoais | Perfil, senha, 2FA, sessões, notificações, token de API | Config. Pessoais | Todos | Disponível com condição | — | 2FA inativo por falta de config. |
| Super Admin | Gestão global da instalação | `/super_admin` | Super Admin | Disponível | Sim (algumas ações) | — |
| Busca | Busca global multi-entidade | Cmd/Ctrl+K ou campo de busca | Todos | Disponível | Não | — |
| Relatórios | Métricas e dashboards | — | — | Não acessível pela interface | Não | Backend ativo, sem link no menu; acessível via URL/Command Bar |
| Campanhas | Disparo em massa | — | — | Não acessível pela interface | — | Backend/cron ainda ativos (APTUS-HIDDEN) |
| Central de Ajuda/Portais | Base de artigos pública | — | — | Não acessível pela interface | Sim (CNAME, backend ativo) | APTUS-HIDDEN |
| Captain (IA) | Sugestões de IA, resumo, respostas | — | — | Não acessível pela interface | — | APTUS-HIDDEN |
| Assinatura de mensagem | Assinatura pessoal em respostas | — | — | Não acessível pela interface | — | APTUS-HIDDEN |
| Papéis Customizados | Permissões granulares | Configurações → Custom Roles | Admin | Disponível com condição | Não | Feature paga, off por padrão |
| SLA | Políticas de tempo de resposta | Configurações → SLA | Admin | Disponível com condição | Sim (descumprimento) | Feature paga, off por padrão |
| SSO/SAML | Login corporativo único | Configurações → Security | Admin | Necessita validação manual | Não | Inoperante sem config. adicional |
| Audit Logs | Trilha de auditoria | Configurações → Audit Logs | Admin | Disponível com condição | Não | Feature paga, off por padrão |
| Billing | Assinatura/plano | Configurações → Billing | Admin | Não acessível pela interface | — | Só Chatwoot Cloud |
| Integrações | Slack, Dialogflow, Linear, Notion, Shopify, LeadSquared, Google Translate, Dyte, OpenAI, Webhook, Agent Bots | Configurações → Integrations | Admin | Disponível com condição | Depende | Ver seção 19 |

---

# 26. Pontos que precisam de validação manual

```text
1. Confirmar se e-mails são de fato enviados em produção
   - Verificar se a variável SMTP_ADDRESS está configurada no ambiente de produção (fora do escopo desta leitura de código, que analisou apenas .env/.env.example locais).
   - Enviar um convite de agente de teste e confirmar recebimento do e-mail de confirmação.

2. Validar se as telas ocultas (Reports, Campaigns, Companies, Portais, Captain) são de fato alcançáveis por URL direta ou pela Command Bar
   - Entrar como agente ou administrador.
   - Tentar navegar diretamente para as rotas dessas áreas (ex: via Cmd/Ctrl+K, digitando "Reports").
   - Confirmar se a tela realmente renderiza dados, e decidir se isso é aceitável para o MVP ou se precisa de um bloqueio adicional no roteador.

3. Confirmar comportamento de custom roles via API direta
   - Como administrador, com a feature `custom_roles` desligada na conta, tentar criar uma role customizada chamando a API diretamente (não pela tela).
   - Confirmar se a criação é aceita mesmo com a tela bloqueada.

4. Validar o fluxo completo de criação de negócio manual no CRM
   - Entrar como agente.
   - Ir em CRM, clicar em "+" numa coluna e criar um negócio.
   - Confirmar que só nome e estágio são realmente os únicos campos disponíveis nessa tela.

5. Validar se o webhook de instalação e o e-mail de conta excluída funcionam quando configurados
   - Como Super Admin, configurar `INSTALLATION_EVENTS_WEBHOOK_URL` e `CHATWOOT_INSTANCE_ADMIN_EMAIL`.
   - Criar uma conta de teste e marcar para exclusão, aguardando o job diário.
   - Confirmar recebimento do webhook e do e-mail.

6. Validar o comportamento de push mobile (Firebase) e Slack
   - Configurar as credenciais ausentes (Firebase, Slack) via Super Admin → App Configs.
   - Confirmar se as respectivas notificações passam a funcionar.

7. Confirmar se o item de menu "Agent Assignment" aparece para alguma conta real da Aptus hoje
   - Verificar, pelo Super Admin, se a feature `advanced_assignment` está ligada em alguma conta em uso.
   - Se estiver desligada em todas, confirmar que o item de menu está de fato ausente na prática (não só na teoria do código).

8. Validar a real necessidade e uso da integração LeadSquared/CRM (Chatwoot original) frente ao novo módulo CRM da Aptus
   - Confirmar com o time se há intenção de manter as duas coisas coexistindo, dado o risco de confusão de nomenclatura.

9. Confirmar com o time se a auditoria de mudanças de usuário (nome/e-mail/disponibilidade) deveria estar funcionando
   - O código tem uma condição que sempre bloqueia esse registro específico, mesmo com Audit Logs habilitado — validar se isso é um bug do Chatwoot original ou comportamento aceito.

10. Validar em ambiente real se o "Assignment V2" (ativo por padrão) está de fato distribuindo conversas automaticamente como esperado
   - Testar criando conversas novas em uma inbox com atribuição automática ligada e observar a distribuição entre agentes online.

11. Decidir o destino do projeto `aptus-hub` (Angular, porta 4200) frente ao novo módulo Hub dentro do aptus-chat
   - O `CLAUDE.md` do workspace principal descreve `aptus-hub` como "painel admin, em desenvolvimento", destinado a analytics do bot para o cliente operador — exatamente o que o novo módulo Hub do aptus-chat (seção 28) já entrega.
   - Confirmar com o time se um dos dois será descontinuado, se vão coexistir com propósitos diferentes, ou se o Hub do aptus-chat é a nova direção e o projeto Angular separado deve ser abandonado.

12. ~~Validar se a policy do Hub (`administrator?` ou `agent?` da própria conta) é o modelo de acesso pretendido para clientes~~
   - **RESOLVIDO em 2026-08-12.** A decisão foi que existem os dois modelos: o cliente que atende pelo próprio Chatwoot continua sendo agente/admin de uma conta comum, e o cliente que só quer a gestão do bot recebe uma conta marcada como `hub_only`, com um único usuário `administrator`. A `AptusHubPolicy` não mudou. Ver 3.4 e 28.7.

13. Validar o gate de conta só-Hub numa conta real antes de entregar ao cliente
   - Criar a conta pelo Super Admin com `hub_only` ligado, logar como o usuário e confirmar: pouso em `/hub`, menu só com Hub, e rotas digitadas na mão (`/dashboard`, `/crm`, `/settings/inboxes`, `/hub/agenda`) caindo em `hub_performance`.
   - Com o log do Rails aberto, recarregar o Hub e confirmar que nenhuma chamada responde 404 — um 404 inesperado significa controller faltando na allowlist de `ensure_hub_only_scope!`.
```

---

# 27. Conclusão e próximos passos recomendados

## Resumo das principais áreas disponíveis

O Aptus Chat, hoje, entrega de forma sólida e funcional: atendimento multicanal (conversas), gestão de contatos, administração de agentes/times com distribuição automática, automações de atendimento, um módulo de CRM em Kanban com motor de automação já configurável pela interface, e um novo portal por conta (Aptus Hub) para acompanhar desempenho, custo e testar o bot. Por trás, existe uma quantidade relevante de funcionalidades do Chatwoot original que foram cuidadosamente removidas da navegação para focar o escopo do MVP (Reports, Central de Ajuda, Campanhas, Empresas, IA Captain), mas que continuam presentes e, em vários casos, ainda rodando em segundo plano.

## Funcionalidades mais importantes para o MVP

- Conversas multicanal + distribuição automática (núcleo do produto).
- Contatos (cadastro, histórico, atributos).
- CRM Kanban + automações configuráveis (diferencial competitivo, já com motor e UI completos).
- Automações básicas de atendimento.
- Aptus Hub — provisionamento e faturamento por cliente, com portal de acompanhamento (ver seção 28).

## Funcionalidades que parecem secundárias neste momento

- Papéis Customizados, SLA, SSO/SAML, Audit Logs, Canal de Voz — todas Enterprise, desligadas por padrão, sem uso confirmado hoje.
- Integrações Slack/Linear/Notion/Shopify/LeadSquared — nenhuma configurada ativamente nesta instalação.

## Funcionalidades parcialmente implementadas que merecem decisão de produto

- Edição incompleta de campos do negócio (valor, responsável, contato) pela interface.
- Integração OpenAI e Notion, hoje inertes.
- Aptus Hub: métricas e webchat de teste funcionam de ponta a ponta; mas não existe hoje um fluxo de onboarding guiado — habilitar o Hub para um cliente novo depende de um Super Admin preencher manualmente ~14 campos em Super Admin → Accounts (bot_id, hub_only, monthly_fee, bot_fixed_cost, markup, tax, etc.), sem validação cruzada com o que está de fato configurado no Botpress Cloud/Firestore do `aws-backend`. O modo `hub_only` (28.7) reduz o esforço de decisão, mas não o de digitação.

## Lacunas que merecem atenção antes do primeiro cliente real (não bloqueiam o piloto interno, mas bloqueiam produção)

Esta análise foi encomendada para responder "o que falta de essencial para usarmos como MVP com os primeiros clientes" — as próximas quatro são as lacunas mais diretamente ligadas a essa pergunta, e nenhuma delas é sobre uma tela faltando (o produto, tela por tela, já está bem coberto):

1. **Decisão de arquitetura pendente: dois "Hub" concorrentes.** O workspace tem um projeto `aptus-hub` (Angular, porta 4200, "em desenvolvimento") descrito no `CLAUDE.md` principal como o painel onde o cliente operador verá analytics do próprio bot — e agora existe um módulo `Hub` dentro do próprio aptus-chat que já faz exatamente isso (e mais: pagamentos, teste ao vivo), rodando em produção real (Rails, não maquete). Levar os primeiros clientes ao ar sem decidir qual dos dois é "o produto" arrisca investimento duplicado.
2. ~~**Modelo de acesso do cliente ainda não diferenciado do modelo de acesso do agente de atendimento.**~~ **Fechado em 2026-08-12** pelo modo conta só-Hub (`hub_only`): a restrição foi resolvida no nível da **conta**, não do papel — uma conta marcada como `hub_only` esconde e bloqueia todo o resto do produto (menu, rota e API), com um único usuário `administrator`. Contas comuns seguem com o modelo antigo, em que o cliente é agente/admin e atende pelo próprio Chatwoot. Ver 3.4 e 28.7.
3. **Provisionamento do Hub é 100% manual e sem validação.** Ativar o Hub para uma conta nova depende de um humano preencher campos de texto livre no Super Admin (inclusive o `bot_id` do Botpress) sem nenhuma checagem de que aquele bot existe, pertence ao workspace certo, ou está de fato integrado com a inbox WhatsApp daquela conta. Um erro de digitação silenciosamente mostra dados errados ou nenhum dado.
4. **Credenciais do Botpress usadas pelo Hub são globais**, não por cliente (`BOTPRESS_API_URL`/`API_KEY`/`WORKSPACE_ID` do `.env`, decisão explícita registrada no commit `0803853e8`) — coerente com o resto do ecossistema Aptus (mesmo padrão do `aws-backend`), mas vale confirmar que o token global tem escopo para ler analytics de todos os bots de todos os clientes, incluindo os que ainda não existem.

## Áreas com maior complexidade

- O motor de distribuição automática de conversas (duas gerações coexistindo — legado e V2 — mais capacidade de agente).
- O cruzamento entre três motores de automação distintos: conversas, CRM e (indiretamente) o Hub, que também dispara mensagens via CRM.

## Áreas com maior risco de dependências ocultas

- Telas ocultas do menu (Reports, Campaigns, Portais, Companies, Captain) cujos backends continuam ativos e cujas rotas de frontend continuam alcançáveis — risco de exposição não intencional de funcionalidades fora do escopo do MVP.
- E-mails que dependem de configuração de ambiente ausente (SMTP, e-mail do admin da instalação, Firebase) — risco de "funcionalidade parece existir mas nunca dispara" em produção.
- Cotação de câmbio do Hub (`AptusHub::ExchangeRateClient`, API pública `awesomeapi.com.br`) sem cache/circuit breaker próprio — se a API externa cair no dia em que um cliente abre "Detalhes" do mês corrente, a tela quebra (ver seção 28).

## Sugestão de ordem para a futura revisão funcional

1. Usuários, contas e permissões (papéis, custom roles, super admin) — a decisão de acesso do cliente no Hub já foi tomada (conta `hub_only`, ver 3.4/28.7); resta o resto.
2. Menu e navegação (decidir o destino definitivo das áreas ocultas: remover de vez, ou manter prontas para reativação futura).
3. Conversas e mensageria (núcleo do produto).
4. Contatos e empresas (decidir o destino de "Companies").
5. CRM (completar a UI de edição de negócio).
6. Aptus Hub (decidir frente ao projeto `aptus-hub` Angular; desenhar onboarding validado de cliente novo).
7. Inboxes e canais (revisar canais fora do assistente — Twitter, 360dialog).
8. Notificações e e-mails (garantir configuração de SMTP/Firebase/webhook de instalação em produção).
9. Automações (unificar mentalmente os três motores — conversas, CRM e Hub).
10. Relatórios (decidir se serão reativados, e quando).
11. Configurações e integrações (revisar quais integrações fazem sentido para o negócio da Aptus).

Este documento não alterou nenhuma funcionalidade do sistema — é exclusivamente um retrato do estado atual, para orientar as próximas decisões de produto.

---

# 28. Aptus Hub — portal de desempenho, teste e faturamento por cliente (módulo novo, 23–24/07)

> Seção adicionada nesta atualização de 24/07 — não existia na versão anterior deste documento porque o módulo inteiro (`AptusHub::*`) foi criado depois da leitura de código original, nos commits `4f34c9c27` e `0803853e8`.

## 28.1 O que é

Um portal, dentro da própria conta do Chatwoot, para acompanhar o bot Botpress vinculado àquela conta-cliente: métricas de uso, custo de LLM, um teste ao vivo do bot via webchat embutido, e o detalhamento financeiro mensal (custo + mensalidade) que o cliente deve à Aptus. Tecnicamente é 100% Aptus (`app/services/aptus_hub/`, `app/controllers/api/v1/accounts/aptus_hub_controller.rb`, `app/javascript/dashboard/components-next/Hub/`) — não existe equivalente no Chatwoot original.

**Como acessar:** Menu lateral → “Hub” (ícone de robô). **Rota:** `hub` → redireciona para `hub_performance`; filhos `hub_tester`, `hub_payments`, e a rota solta `hub_payment_details` (`/hub/payments/:month`, fora do `HubLayout`, acessível a partir de um card do histórico de pagamentos).
**Quem pode acessar:** Qualquer agente ou administrador da conta (`AptusHubPolicy` — mesma regra do resto do Chatwoot, sem role específica de “cliente”).
**Condição de exibição:** Só aparece no menu, e só responde na API (`ensure_hub_available!`), se a conta tiver `custom_attributes.aptus_hub.enabled = true` **e** `bot_id` preenchido. Ambos são configurados pelo Super Admin da instalação (ver 28.5) — não há self-service para o próprio cliente habilitar.

> Uma conta pode ainda ser marcada como **só-Hub** (`hub_only`), caso em que o Hub deixa de ser mais um item do menu e passa a ser o produto inteiro daquela conta. Ver 28.7.

## 28.2 Aba “Desempenho” (`hub_performance`)

**Objetivo:** visão consolidada do uso do bot no período (padrão: mês corrente, sem seletor de período visível na versão atual).
**Elementos disponíveis:** nome/status/modelo de IA do bot; seis indicadores (sessões, mensagens de usuário, mensagens do bot, usuários — com detalhamento novos/recorrentes, eventos, tokens de LLM); lista de canais (inboxes) da conta; um gráfico de histórico de uso (barras por dia/período, com base no maior valor de mensagens totais do período).
**Fonte de dados:** `AptusHub::BotpressClient#analytics` — chamada em tempo real à API do Botpress Cloud (`GET /admin/bots/:bot_id/analytics`) usando credenciais **globais** da instalação (`BOTPRESS_API_URL`/`BOTPRESS_API_KEY`/`BOTPRESS_WORKSPACE_ID` do `.env`), não por cliente.
**Observações:** esta aba absorveu a antiga aba “Meu Bot”/“Visão Geral” (componente `HubOverview.vue`, existente no commit de 23/07) — removida no rework de 24/07 e mesclada aqui, junto com a exposição de métricas de token/custo de LLM que a API do Botpress já devolvia mas que antes eram descartadas.

## 28.3 Aba “Testar” (`hub_tester`)

**Objetivo:** permitir que quem acessa o Hub converse com o próprio bot, sem precisar abrir o Botpress Cloud.
**Como funciona:** busca a URL do script de webchat configurada para a conta (`webchat_script_url`); se presente, injeta dinamicamente o loader oficial do Botpress (`cdn.botpress.cloud/webchat/v3.7/inject.js`) mais o script específico do bot, e embute o widget dentro da própria página (modo `embeddedChatId`) em vez do balão flutuante padrão.
**Se não configurado:** mostra um estado vazio (“bot não configurado para testes”) em vez de erro.
**Ponto de atenção — funcionalidade órfã**: existe um endpoint completo de **feedback** (`POST .../aptus_hub/feedback`, `AptusHub::CustomerPortalService#create_feedback!`, testado em `HubTester.spec.js`) para registrar um comentário sobre uma conversa de teste (associado a `conversation_id`, usuário e timestamp, guardado em `custom_attributes.aptus_hub.feedback`). O componente `HubTester.vue` atual **não tem mais nenhum campo ou botão que chame esse endpoint** — foi retirado da tela no rework de 24/07 (o componente caiu de 225 para ~142 linhas). Ou seja, é o caso inverso do habitual neste documento: um backend funcional sem nenhuma tela que o acione.

## 28.4 Aba “Pagamentos” (`hub_payments`) e tela “Detalhes” (`hub_payment_details`)

**Objetivo:** mostrar o plano contratado e o histórico de faturamento dos últimos 6 meses, com um detalhamento de custo real por mês.
**Lista de pagamentos:** mensalidade, moeda e dia de vencimento configurados (ver 28.5); para cada um dos 6 meses mais recentes, status (`paid`/`pending`/`overdue`, calculado comparando a data de vencimento com hoje, ou lido de um registro de pagamento salvo), data de vencimento, e (desde 24/07) o valor total já calculado — clicar em um mês abre a página de detalhes.
**Tela de Detalhes (por mês):** indicadores de uso do mês (mesmas 6 métricas da aba Desempenho) e um **breakdown de custo real**: custo de LLM em USD (vindo direto do Botpress), custo fixo do bot em USD (configurável, ver 28.5), soma dos dois convertida para BRL usando uma cotação USD→BRL — **ao vivo** (API pública AwesomeAPI) se o mês for o corrente, ou **congelada** (gravada em `custom_attributes` na primeira vez que o mês é consultado) se for um mês passado — acrescida de um markup e um imposto configuráveis por conta, mais a mensalidade fixa da Aptus, resultando no total do mês.
**Ponto de atenção — custo de performance/robustez**: carregar a aba “Pagamentos” dispara, para cada um dos 6 meses do histórico, uma chamada aos analytics do Botpress **e potencialmente uma chamada à cotação de câmbio** (`AptusHub::ExchangeRateClient`, sem cache) — até 12 chamadas HTTP externas síncronas numa única carga de tela, sem nenhum cache/circuit breaker. Se o Botpress ou a AwesomeAPI estiverem lentos ou fora do ar, a tela inteira falha (`rescue_from ... :render_hub_error`) em vez de degradar parcialmente.

## 28.5 Provisionamento pelo Super Admin

Desde `0803853e8`, todo o Hub é configurável por conta (antes só via SQL/console), em Super Admin → Accounts → editar conta → campo “Aptus Hub” (`AptusHubConfigField`, reaproveitando o padrão de campo customizado do Administrate já usado por `AccountLimitsField`): habilitado (sim/não), **só-Hub (sim/não, ver 28.7)**, ID/nome/status/modelo de IA do bot, mensalidade, custo fixo do bot em USD (padrão US$10 — bate com o valor de referência já usado internamente pela Aptus), moeda, dia de vencimento, taxa de markup (padrão 14%), taxa de imposto (padrão 7%), URL do script de webchat. Tudo fica armazenado em `Account#aptus_hub` (`store_accessor` sobre `custom_attributes`), preservando o histórico de pagamentos/feedback já gravado.
**Limitação confirmada:** o formulário aceita qualquer texto no campo `bot_id` — não há validação contra o Botpress Cloud (não confirma se o bot existe, se pertence ao workspace configurado, ou se está de fato ligado à inbox WhatsApp daquela conta). Um erro de digitação some silenciosamente atrás de um erro genérico "Não foi possível buscar os dados do bot agora" na tela do cliente.

## 28.6 Relação com o restante do ecossistema Aptus

- As credenciais do Botpress usadas aqui são as mesmas variáveis de ambiente globais (`BOTPRESS_API_URL`, `BOTPRESS_API_KEY`, `BOTPRESS_WORKSPACE_ID`) citadas no `CLAUDE.md` do workspace principal como usadas pelo `aws-backend` — decisão explícita registrada no próprio commit (“Botpress credentials remain global (.env) for now, by explicit decision”), não uma lacuna desta análise.
- O valor padrão de custo fixo do bot (US$10) e o conceito de mensalidade por cliente batem com a precificação padrão já usada internamente pela Aptus para seus bots.
- **Sobreposição a resolver**: o `CLAUDE.md` do workspace descreve `aptus-hub` (projeto Angular separado, porta 4200) como "em desenvolvimento", destinado a que "o cliente operador acessará para ver analytics do próprio bot, quando em produção" — a mesma proposta de valor que este módulo, dentro do aptus-chat, já entrega funcionando hoje. Não há, nesta análise, evidência de que essa sobreposição já tenha sido resolvida (ver seção 27).

## 28.7 Conta só-Hub (`hub_only`)

**O que é:** um recorte de conta para o cliente que contrata apenas o bot e não usa nada da plataforma de atendimento — caso da Izzy Cannabis, que já opera CRM e mensageria no Kommo. A conta existe só para acompanhar e pagar o bot.

**Como é ligado:** um campo booleano **Hub only** no mesmo formulário de provisionamento do Hub (Super Admin → Accounts → editar conta → “Aptus Hub”), gravado em `custom_attributes.aptus_hub.hub_only`. Não há migração nem tabela nova — é mais uma chave do `store_accessor` já existente. Nasce desligado, então nenhuma conta atual muda de comportamento.

**O que muda, em quatro camadas:**

| Camada | Onde | Comportamento |
|---|---|---|
| Menu | `Sidebar.vue` (`isHubOnly`) | O menu inteiro vira apenas o grupo Hub. Agenda, Settings, Inbox, Conversation, CRM e Contacts somem |
| Rota | `routeHelpers.js` (`isAHubRoute`) | Qualquer rota fora do Hub, inclusive digitada na barra de endereço, redireciona para `hub_performance` |
| Entrada | `routes/index.js` | O pouso pós-login é o Hub em vez da home de conversas, e o wizard de onboarding é pulado (é setup de inbox, inútil aqui) |
| API | `Api::V1::Accounts::BaseController` (`ensure_hub_only_scope!`) | Todo controller com escopo de conta responde 404, exceto `aptus_hub`. O payload que o dashboard carrega no boot vem de `Api::V1::AccountsController`, que herda de `Api::BaseController` e não passa por esse gate |

O corte na sidebar também suprime as seis chamadas de boot (`labels`, `inboxes`, `teams`, `attributes`, `customViews` ×2, `notifications/unReadCount`) — é o que permite que a allowlist da API tenha um controller só.

**Modelo de acesso pretendido:** um único usuário por conta, com papel `administrator`. O papel admin é o que libera a aba Pagamentos (`AptusHubPolicy#payments?`), e o `hub_only` é o que impede que esse mesmo papel abra Settings. A `AptusHubPolicy` não foi alterada, então contas comuns que já usam o Hub seguem com o comportamento anterior.

**Provisionamento (replicável para qualquer cliente futuro):**

1. **Super Admin → Accounts → New.** Nome do cliente, locale `pt_BR`, status `active`. Usar o formulário do Super Admin, **não** o `AccountBuilder` via console: o builder grava `onboarding_step`, e embora contas `hub_only` pulem o wizard, a conta criada pelo Administrate já nasce limpa.
2. **Seção “Aptus Hub” do mesmo formulário:** `enabled` ✓, `hub_only` ✓, `bot_id`, `bot_name`, `status`, `ai_model`, `go_live_on`, `monthly_fee`, `bot_fixed_cost` (US$ 10), `currency`, `payment_day`, `markup_rate` (0.14), `tax_rate` (0.07), `webchat_script_url` — sem esta última a aba Testar mostra estado vazio.
3. **Super Admin → Account Users:** vincular o usuário único com papel `administrator` (criar antes em Super Admin → Users, se necessário).
4. **Senha:** o cliente recebe o e-mail de confirmação do Devise, que depende de `SMTP_ADDRESS` configurado — sem SMTP nada é enviado e a falha é silenciosa (ver seção 13). Alternativa: definir a senha pelo Super Admin.
5. **Conferir antes de entregar:** logar como o cliente e confirmar o pouso em `/app/accounts/:id/hub`, o menu só com Hub, e **dados reais na aba Desempenho** — é a única forma de saber se o `bot_id` está correto, já que ele não é validado contra o Botpress Cloud (ver 28.5).

**Limitação herdada:** os pontos de atenção de 28.4 e 28.5 continuam valendo — `bot_id` sem validação, credenciais globais do Botpress, e a aba Pagamentos disparando até 12 chamadas HTTP externas sem cache.

Referências para conferência:
- `app/controllers/api/v1/accounts/aptus_hub_controller.rb`, `app/policies/aptus_hub_policy.rb`
- `app/controllers/api/v1/accounts/base_controller.rb` (`ensure_hub_only_scope!`, `HUB_ONLY_CONTROLLERS`)
- `app/services/aptus_hub/account_config.rb` (`hub_only?`, `serialized_for_account`), `botpress_client.rb`, `customer_portal_service.rb`, `payment_cost_calculator.rb`, `exchange_rate_client.rb`
- `app/fields/aptus_hub_config_field.rb`, `app/dashboards/account_dashboard.rb`, `app/views/fields/aptus_hub_config_field/`
- `app/views/api/v1/models/_user.json.jbuilder` (expõe `hub_only` no array `accounts`, lido pelo guard do roteador)
- `app/javascript/dashboard/components-next/Hub/*.vue`, `app/javascript/dashboard/routes/dashboard/hub/routes.js`
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` (blocos `hasAptusHub` e `isHubOnly`)
- `app/javascript/dashboard/helper/routeHelpers.js` (`isAHubRoute`), `app/javascript/dashboard/routes/index.js`
