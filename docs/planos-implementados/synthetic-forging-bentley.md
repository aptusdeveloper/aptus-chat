# Reformular o construtor de Automações do CRM (aptus-chat) — múltiplos gatilhos com parâmetros independentes

## Contexto

O motor de automação do CRM (`Menu → CRM → Automações`, `CrmAutomationForm.vue`) ganhou UI própria em 23–24/07, mas hoje uma regra só aceita **um** gatilho (`form.trigger_type` é string única, `RadioCard` é radio puro — clicar num ativo não desmarca). Além disso, os parâmetros de cada gatilho estão errados/incompletos: nenhum gatilho mostra seletor de funil (nem `deal_created`, que deveria depender dele), a lista de etapas mistura todas as pipelines, só se escolhe 1 etapa para "lead entrou em etapa", e falta o gatilho `deal_updated` (existe no backend, nunca aparece na UI).

O usuário pediu:
1. Poder adicionar quantos **gatilhos** quiser numa mesma regra (hoje é só 1).
2. Poder adicionar quantas **etapas** quiser no gatilho "lead entrou em etapa" (hoje é só 1).
3. Cada gatilho mostrar exatamente os parâmetros que lhe cabem (funil sempre; funil+etapa(s) para "entrou em etapa"; etc.) — hoje "está quase tudo errado".
4. Clicar num gatilho já selecionado deve desmarcá-lo.
5. **Decisão já confirmada com o usuário**: cada gatilho ativo tem parâmetros **independentes** — não é um funil único para a regra inteira. Um mesmo tipo de gatilho pode inclusive se repetir na mesma regra com parâmetros diferentes (ex.: "entrou na etapa X do Funil A" **e** "entrou na etapa Y do Funil B" na mesma automação).

Isso não cabe nos campos escalares atuais (`trigger_type` string, `crm_pipeline_id` FK única). A raiz do problema é arquitetural: o "parâmetro do gatilho" hoje é sintetizado pelo **frontend** como uma condição genérica escondida dentro do array `conditions` (`systemConditions()`/`hydrateConditions()` em `CrmAutomationForm.vue`) — daí a fragilidade. A correção estrutural é: `trigger_type`/`crm_pipeline_id` (colunas escalares) → `triggers` (coluna jsonb, array de objetos), cada um com seus próprios `trigger_type` + `crm_pipeline_id` + `stage_ids` + `days`, resolvidos no **backend**, não mais sintetizados no frontend.

Este plano foi validado por dois agentes de exploração (leitura completa do frontend e do backend atuais) e por um agente de planejamento; os pontos críticos (assinatura de `action_service.rb`, timestamp de migração, usos de `RadioCard`) foram conferidos diretamente no código.

## Achado crítico adicional (não fazia parte do pedido, mas quebra se ignorado)

`app/services/crm_automation_rules/action_service.rb:207` grava `trigger_type: @rule.trigger_type` no log de execução. Isso vai quebrar assim que a coluna escalar for removida — precisa mudar a assinatura de `ActionService.new(rule, deal)` para `ActionService.new(rule, deal, trigger_type:)`, passando o trigger_type que efetivamente casou (só 2 call sites em produção: `processor.rb`, `crm_deal_time_check_job.rb`).

## Decisão de dados

Cada item de `triggers` (array jsonb):
```json
{ "trigger_type": "deal_entered_stage", "crm_pipeline_id": "uuid|null", "stage_ids": ["uuid", ...], "days": null }
```
`crm_pipeline_id`/`stage_ids`/`days` só são relevantes conforme o tipo (todos aceitam `crm_pipeline_id`; `stage_ids` só para `deal_entered_stage`; `days` só para `deal_stagnant`/`deal_close_date_approaching`). Repetir o mesmo `trigger_type` no array é válido (não há unicidade).

## Backend — ordem de implementação

1. **Migração** `db/migrate/20260731010000_restructure_crm_automation_rule_triggers.rb` (última existente é `20260730100500`, timestamp confere):
   - `add_column :crm_automation_rules, :triggers, :jsonb, null: false, default: []` + índice GIN.
   - Backfill via SQL: para cada linha, ler `trigger_type`/`crm_pipeline_id`/`conditions`; se `conditions[0]` bater exatamente com a assinatura sintética conhecida (`deal_entered_stage`→`crm_stage_id equal_to`; `deal_stagnant`→`days_in_stage gte`; `deal_close_date_approaching`→`close_date days_before`), extrair `stage_ids`/`days` dali e remover esse item de `conditions` (casar por `attribute_key` **e** `filter_operator` juntos, já que `crm_stage_id` também é um atributo de condição manual legítimo — não confundir). Montar `triggers = [{trigger_type, crm_pipeline_id, stage_ids, days}]`.
   - **Antes de rodar em produção**, executar a query de diagnóstico abaixo e comunicar quantas regras `deal_entered_stage` ficarão sem etapa (situação hoje possível pois o backend não valida isso) — a migração deve marcá-las `active: false` durante o backfill em vez de falhar ou inventar valor:
     ```sql
     SELECT id, trigger_type FROM crm_automation_rules
     WHERE trigger_type = 'deal_entered_stage'
       AND NOT (conditions->0->>'attribute_key' = 'crm_stage_id' AND conditions->0->>'filter_operator' = 'equal_to');
     ```
   - Remover colunas antigas `trigger_type`, `crm_pipeline_id` (+ índices/FK) só depois do backfill, na mesma migração.
   - Usar `ActiveRecord::Base.connection.exec_query` com binds parametrizados no backfill (não interpolar string em JSON/UPDATE).

2. **`app/models/crm_automation_rule.rb`**: remover `belongs_to :crm_pipeline`; trocar `validates :trigger_type, inclusion:` por uma validação `triggers_shape` (array não-vazio; cada item com `trigger_type` ∈ `TRIGGER_TYPES`; `deal_entered_stage` exige `stage_ids` não-vazio; `deal_stagnant`/`deal_close_date_approaching` exigem `days > 0`). Adicionar `DAYS_SCOPED_TRIGGERS = %w[deal_stagnant deal_close_date_approaching]`. Scopes `event_based`/`time_based`/novo `with_trigger_type` via containment jsonb (`triggers @> ?`).

3. **Novo `app/services/crm_automation_rules/trigger_matcher.rb`**: único lugar que sabe casar um item de `triggers` contra `(trigger_type dedetectado, deal)` — checa `crm_pipeline_id` (nil = qualquer), `stage_ids` (quando `deal_entered_stage`, `deal.crm_stage_id` precisa estar na lista) e `days` (quando `deal_stagnant`/`deal_close_date_approaching`, replicando a mesma conta de `days_in_stage`/`days_before` que já existe em `conditions_filter_service.rb`, sem duplicar lógica de negócio nova). `ConditionsFilterService` **não muda** — continua avaliando só as condições genuinamente manuais do usuário (não precisa de operador `in` novo).

4. **`processor.rb`**: `rules` passa a usar `CrmAutomationRule.active.where(account_id:).with_trigger_type(@trigger_type)` (pré-filtro SQL via GIN); `process_rule` chama `TriggerMatcher.matching_item(rule, trigger_types: [@trigger_type], deal: @deal)` antes de `ConditionsFilterService`/`ActionService`, e passa `trigger_type:` explícito pro `ActionService.new`.

5. **`crm_deal_time_check_job.rb`**: mesma ideia, usando `TriggerMatcher.matching_item(rule, trigger_types: CrmAutomationRule::TIME_TRIGGERS, deal:)`; idempotência diária (`already_executed_today?`) inalterada.

6. **`action_service.rb`**: `initialize(rule, deal, trigger_type:)` guardando `@trigger_type`; `log_execution` usa `@trigger_type` em vez de `@rule.trigger_type`. Nenhuma outra linha muda.

7. **`crm_automation_rules_controller.rb`** + jbuilders (`index/show/create/update/clone.json.jbuilder` + `partials/_crm_automation_rule.json.jbuilder`): `permitted_rule_attributes` perde `trigger_type`/`crm_pipeline_id`; `assign_json_attributes` ganha `rule.triggers = normalize_triggers(payload[:triggers])` (reaproveita `normalize_collection` já existente); `index` perde `.includes(:crm_pipeline)`. Adicionar um `set_lookups` (chamado nas 5 actions) que resolve, em lote, nome do funil e das etapas de todos os `triggers` das regras carregadas, e repassar esses hashes (`pipelines_by_id`, `stages_by_id`) como locals pro partial jbuilder — evita N+1 e permite a listagem mostrar "Funil X · Etapas Y, Z" sem lookup extra no frontend. Partial passa a serializar `triggers` (array completo, com `crm_pipeline_name`/`stage_names` resolvidos) no lugar de `trigger_type`/`crm_pipeline_id`/`crm_pipeline{}`.

## Frontend — `CrmAutomationForm.vue` (arquivo único, hoje 1076 linhas)

**Modelo de UI (resolve o conflito entre "grade de cards" e "repetir o mesmo tipo")**: a grade de cards de tipo de gatilho (visual atual mantida) vira um **toggle de presença**, não um radio:
- Clicar num tipo sem nenhuma instância ativa → adiciona 1 instância com parâmetros default.
- Clicar num tipo que já tem instância(s) ativa(s) → remove todas as instâncias daquele tipo (isso satisfaz literalmente "clicar no ativo desmarca").
- Assim que um tipo tem ≥1 instância, aparece abaixo da grade um bloco daquele tipo com cada instância (funil sempre; + lista repetível de etapas com "+ Adicionar etapa" se `deal_entered_stage`; + input de dias se `deal_stagnant`/`deal_close_date_approaching`) e um botão "+ Adicionar outro `<Tipo>`" para repetir o mesmo tipo com parâmetros diferentes.
- Dentro de uma instância `deal_entered_stage`, a lista de etapas é repetível e independente das etapas de outras instâncias — reaproveita o padrão de lista já existente no arquivo (`addCondition`/`removeCondition`, `addAction`/`removeAction`).

**Mudanças de estado**:
- `form.trigger_type`/`trigger_stage_id`/`trigger_days` (escalares) → `form.triggers` (array de `{ _key, trigger_type, crm_pipeline_id, stage_ids?, days? }`, `_key` só para `:key` do Vue).
- `systemConditions()` e a hidratação reversa em `hydrateConditions()` (linhas ~448-482, ~564-603 atuais) são **eliminadas por completo** — o parâmetro do gatilho deixa de ser sintetizado dentro de `conditions`; `conditions` volta a ser só o que o usuário adicionar manualmente.
- Novas funções: `toggleTriggerType`, `addTriggerEntry`, `removeTriggerEntry`, `addTriggerStage`/`removeTriggerStage`, `triggersByType` (computed agrupando `form.triggers` por tipo), `stageOptionsForPipeline(pipelineId)` (filtra etapas pelo funil escolhido **daquela instância**, corrigindo o achado de que hoje a lista mistura todas as pipelines).
- `buildPayload()`: `triggers: normalizeTriggers()` no lugar do `trigger_type`/`crm_pipeline_id: null` hardcodado hoje.
- `hydrateForm()`/`hydrateTriggers()`: populam `form.triggers` diretamente do array vindo da API (sem re-engenharia de `conditions`).
- Nova `validateTriggers()` (mesmo padrão de `validateActions()` já existente): erro se nenhum gatilho ativo; erro se `deal_entered_stage` sem nenhuma etapa; erro se `deal_stagnant`/`deal_close_date_approaching` com `days <= 0`. Chamada em `saveAutomation()` antes de `validateActions()`.

**`constants.js`**: adicionar o gatilho faltante `deal_updated` (existe em `EVENT_TRIGGERS` no backend e é sempre disparado em updates — hoje invisível na UI, cai no fallback de texto cru na listagem).

**`RadioCard.vue`**: adicionar prop opt-in `toggleable` (default `false`) em vez de criar componente novo — confirmado via grep que há só 5 outros usos (`PortalLayoutContentSettings.vue`, `LockToSingleConversationPreview.vue`, `SenderNameExamplePreview.vue`, `AgentAssignmentPolicyForm.vue`, `profile/Index.vue`), todos seleções verdadeiramente exclusivas onde deseleção quebraria a UX. Com `toggleable=false` o comportamento desses 5 fica byte-a-byte idêntico (risco zero de regressão). Mudança em `handleChange`: emite `select` quando `!isActive || toggleable` (hoje só emite quando `!isActive`).

**`CrmAutomationsIndex.vue`**: remover a coluna "Pipeline" de nível de regra (não faz mais sentido, cada trigger tem seu próprio funil); a célula de "Trigger" vira uma lista de badges, um por item de `triggers`, mostrando tipo + funil + etapas/dias resumidos (usa os campos já resolvidos `crm_pipeline_name`/`stage_names` que o backend passa a serializar).

**i18n** (`app/javascript/dashboard/i18n/locale/en/settings.json`, bloco `CRM.AUTOMATIONS` — só `en.json`/`en.yml`, conforme convenção do projeto): adicionar `TRIGGERS.DEAL_UPDATED(_DESCRIPTION)`, `FORM.TRIGGER_REQUIRED`, `FORM.TRIGGER_STAGE_REQUIRED`, `FORM.TRIGGER_DAYS_REQUIRED`, `FORM.ADD_STAGE`, `FORM.ADD_ANOTHER_TRIGGER`, `FORM.ALL_PIPELINES_OPTION`, `LIST.DAYS_SUFFIX`; remover `LIST.COLUMNS.PIPELINE` (não mais usado).

## Arquivos críticos
- `db/migrate/20260731010000_restructure_crm_automation_rule_triggers.rb` (novo)
- `app/models/crm_automation_rule.rb`
- `app/services/crm_automation_rules/trigger_matcher.rb` (novo)
- `app/services/crm_automation_rules/processor.rb`
- `app/services/crm_automation_rules/action_service.rb`
- `app/jobs/crm_deal_time_check_job.rb`
- `app/controllers/api/v1/accounts/crm_automation_rules_controller.rb` + `app/views/api/v1/accounts/crm_automation_rules/**/*.jbuilder`
- `app/javascript/dashboard/components-next/Crm/automations/CrmAutomationForm.vue`
- `app/javascript/dashboard/components-next/Crm/automations/constants.js`
- `app/javascript/dashboard/components-next/Crm/automations/CrmAutomationsIndex.vue`
- `app/javascript/dashboard/components-next/radioCard/RadioCard.vue`
- `app/javascript/dashboard/i18n/locale/en/settings.json`

`ConditionsFilterService` não muda. Não há override em `enterprise/` para nenhum desses arquivos (confirmado via busca).

## Specs a atualizar/criar (não escrever ainda, só apontar)
- `spec/factories/crm.rb` — trocar `trigger_type`/`crm_pipeline` por `triggers`.
- `spec/models/crm_automation_rule_spec.rb` — **criar do zero** (não existe hoje): validações de `triggers`, repetição do mesmo tipo é válida, scopes.
- `spec/services/crm_automation_rules/trigger_matcher_spec.rb` — **criar do zero**: pipeline nil vs definido, múltiplas etapas, múltiplos itens do mesmo tipo com thresholds diferentes.
- `spec/services/crm_automation_rules/processor_spec.rb`, `spec/jobs/crm_deal_time_check_job_spec.rb`, `spec/services/crm_automation_rules/action_service_spec.rb`, `spec/requests/api/v1/accounts/crm_automation_rules_controller_spec.rb` — adaptar para `triggers:` e nova assinatura do `ActionService`.
- `spec/services/crm_automation_rules/conditions_filter_service_spec.rb` — sem mudanças (não referencia trigger_type/pipeline).

## Ordem de execução e riscos
1. Backend primeiro, nesta ordem interna: migração → model → `TriggerMatcher` (+ spec) → `action_service.rb` (assinatura) → `processor.rb` → `crm_deal_time_check_job.rb` → controller/jbuilders → specs de request. `action_service.rb` precisa mudar **antes** de `processor.rb`/`crm_deal_time_check_job.rb`, senão ficam com chamada quebrada.
2. **Risco de janela de deploy**: assim que o backend novo subir, `permitted_rule_attributes` ignora silenciosamente `trigger_type`/`crm_pipeline_id` enviados por um frontend antigo — criar/editar pelo form antigo passaria a dar erro 422 ("triggers must have at least one trigger") até o frontend novo subir. Backend e frontend devem ir na mesma janela de deploy.
3. Rodar a query de diagnóstico de `deal_entered_stage` sem etapa em produção antes da migração e avisar quantas regras serão desativadas.
4. Frontend por último (depende do formato de payload/response já estabilizado).
5. Ao final: `bundle exec rubocop -a`, `pnpm eslint`, e rodar `bundle exec rspec spec/models/crm_automation_rule_spec.rb spec/services/crm_automation_rules spec/jobs/crm_deal_time_check_job_spec.rb spec/requests/api/v1/accounts/crm_automation_rules_controller_spec.rb`.

## Verificação
1. Specs acima passando (`bundle exec rspec ...`).
2. Rodar `./dev.sh` e, em `CRM → Automações`, criar uma regra com **dois gatilhos diferentes** (ex.: "Lead criado" restrito ao Funil A + "Lead entrou em etapa" restrito ao Funil B com 2 etapas escolhidas) e confirmar: os dois blocos de parâmetro aparecem corretamente; clicar de novo no card de um gatilho ativo remove o bloco inteiro; "+ Adicionar etapa" e "+ Adicionar outro gatilho" funcionam; salvar e reabrir a regra reidrata tudo igual.
3. Testar o fluxo real: criar/mover um `CrmDeal` que bate com um dos gatilhos configurados e confirmar no log/`CrmAutomationExecution` que a ação disparou; testar também um deal que **não** bate (funil errado) e confirmar que não dispara.
4. Conferir a listagem (`CrmAutomationsIndex.vue`) mostrando os badges de múltiplos gatilhos com funil/etapas resolvidos, sem N+1 visível.
