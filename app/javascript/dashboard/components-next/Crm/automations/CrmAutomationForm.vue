<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import FilterSelect from 'dashboard/components-next/filter/inputs/FilterSelect.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useAlert } from 'dashboard/composables';
import {
  ACTIONS,
  CONDITION_ATTRIBUTES,
  MESSAGE_KINDS,
  OPERATORS,
  TRIGGERS,
} from './constants';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const pipelines = useMapGetter('crmDeals/pipelines');
const agents = useMapGetter('agents/getAgents');
const uiFlags = useMapGetter('crmAutomations/uiFlags');

const error = ref('');
const fileInputs = ref({});

const form = reactive({
  name: '',
  active: true,
  crm_pipeline_id: '',
  trigger_type: 'deal_entered_stage',
  trigger_stage_id: '',
  trigger_days: 1,
  conditions: [],
  actions: [],
});

const isEdit = computed(() => route.name === 'crm_automation_edit');
const automationId = computed(() => route.params.automationId);
const accountId = computed(() => route.params.accountId);

const allStages = computed(() =>
  pipelines.value.flatMap(pipeline =>
    (pipeline.stages || []).map(stage => ({
      ...stage,
      pipeline_name: pipeline.name,
    }))
  )
);

const selectedPipeline = computed(
  () =>
    pipelines.value.find(pipeline => pipeline.id === form.crm_pipeline_id) ||
    null
);

const stageOptions = computed(() => {
  if (selectedPipeline.value) return selectedPipeline.value.stages || [];
  return allStages.value;
});

const customAttributes = computed(() =>
  store.getters['attributes/getAttributesByModel']('deal_attribute').filter(
    attribute =>
      !form.crm_pipeline_id ||
      attribute.crm_pipeline_id === form.crm_pipeline_id
  )
);

const conditionAttributes = computed(() => [
  ...CONDITION_ATTRIBUTES.map(attribute => ({
    ...attribute,
    label: t(attribute.labelKey),
  })),
  ...customAttributes.value.map(attribute => ({
    id: `custom_attributes.${attribute.attribute_key}`,
    label: attribute.attribute_display_name,
    input: attribute.attribute_display_type,
    values: attribute.attribute_values || [],
  })),
]);

const fieldOptions = computed(() => [
  { id: 'name', label: t('CRM.AUTOMATIONS.FIELDS.NAME'), input: 'text' },
  { id: 'amount', label: t('CRM.AUTOMATIONS.FIELDS.AMOUNT'), input: 'number' },
  {
    id: 'close_date',
    label: t('CRM.AUTOMATIONS.FIELDS.CLOSE_DATE'),
    input: 'date',
  },
  {
    id: 'probability',
    label: t('CRM.AUTOMATIONS.FIELDS.PROBABILITY'),
    input: 'number',
  },
  ...customAttributes.value.map(attribute => ({
    id: `custom_attributes.${attribute.attribute_key}`,
    label: attribute.attribute_display_name,
    input: attribute.attribute_display_type,
    values: attribute.attribute_values || [],
  })),
]);

const selectedTrigger = computed(() =>
  TRIGGERS.find(trigger => trigger.id === form.trigger_type)
);

function conditionAttribute(condition) {
  return conditionAttributes.value.find(
    attribute => attribute.id === condition.attribute_key
  );
}

const pipelineOptions = computed(() => [
  { value: '', label: t('CRM.AUTOMATIONS.ALL_PIPELINES') },
  ...pipelines.value.map(pipeline => ({
    value: pipeline.id,
    label: pipeline.name,
  })),
]);

const pipelineSelectOptions = computed(() =>
  pipelines.value.map(pipeline => ({
    value: pipeline.id,
    label: pipeline.name,
  }))
);

const stageSelectOptions = computed(() =>
  stageOptions.value.map(stage => ({ value: stage.id, label: stage.name }))
);

const agentSelectOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);

const assignAgentSelectOptions = computed(() => [
  { value: '', label: t('CRM.AUTOMATIONS.ACTIONS.UNASSIGNED') },
  ...agentSelectOptions.value,
]);

const queryOperatorSelectOptions = computed(() => [
  { value: 'AND', label: t('CRM.AUTOMATIONS.CONDITIONS.AND') },
  { value: 'OR', label: t('CRM.AUTOMATIONS.CONDITIONS.OR') },
]);

const conditionAttributeSelectOptions = computed(() =>
  conditionAttributes.value.map(attribute => ({
    value: attribute.id,
    label: attribute.label,
  }))
);

const fieldSelectOptions = computed(() =>
  fieldOptions.value.map(field => ({ value: field.id, label: field.label }))
);

function conditionValueSelectOptions(condition) {
  const attribute = conditionAttribute(condition);
  if (attribute?.input === 'stage') return stageSelectOptions.value;
  if (attribute?.input === 'agent') return agentSelectOptions.value;
  if (attribute?.input === 'list') {
    return (attribute.values || []).map(value => ({
      value,
      label: value,
    }));
  }
  return [];
}

function conditionValueUsesSelect(condition) {
  const input = conditionAttribute(condition)?.input;
  return input === 'stage' || input === 'agent' || input === 'list';
}

function conditionOperatorHidesValue(condition) {
  return Boolean(
    OPERATORS.find(operator => operator.id === condition.filter_operator)
      ?.hidesValue
  );
}

const OPERATOR_IDS_BY_INPUT = {
  stage: ['equal_to', 'not_equal_to', 'is_present', 'is_not_present'],
  agent: ['equal_to', 'not_equal_to', 'is_present', 'is_not_present'],
  list: ['equal_to', 'not_equal_to', 'is_present', 'is_not_present'],
  checkbox: ['equal_to', 'not_equal_to', 'is_present', 'is_not_present'],
  number: [
    'equal_to',
    'not_equal_to',
    'greater_than',
    'less_than',
    'gte',
    'lte',
    'is_present',
    'is_not_present',
  ],
  date: [
    'equal_to',
    'not_equal_to',
    'days_before',
    'is_today',
    'is_past',
    'is_future',
    'is_present',
    'is_not_present',
  ],
};
const DEFAULT_OPERATOR_IDS = [
  'equal_to',
  'not_equal_to',
  'contains',
  'is_present',
  'is_not_present',
];

function operatorOptionsFor(condition) {
  const allowedIds =
    OPERATOR_IDS_BY_INPUT[conditionAttribute(condition)?.input] ||
    DEFAULT_OPERATOR_IDS;
  return OPERATORS.filter(operator => allowedIds.includes(operator.id)).map(
    operator => ({ value: operator.id, label: t(operator.labelKey) })
  );
}

const actionTypeSelectOptions = computed(() =>
  ACTIONS.map(action => ({ value: action.id, label: t(action.labelKey) }))
);

function actionMeta(action) {
  return ACTIONS.find(item => item.id === action.action_name);
}

const messageKindOptions = computed(() =>
  MESSAGE_KINDS.map(kind => ({ ...kind, label: t(kind.labelKey) }))
);

const cardTitle = computed(() =>
  isEdit.value
    ? t('CRM.AUTOMATIONS.FORM.EDIT_TITLE')
    : t('CRM.AUTOMATIONS.FORM.NEW_TITLE')
);

const saveLabel = computed(() =>
  uiFlags.value.isCreating || uiFlags.value.isUpdating
    ? t('CRM.FORM.SAVING')
    : t('CRM.FORM.SAVE')
);

const triggerNeedsStage = computed(() => selectedTrigger.value?.needsStage);
const triggerNeedsDays = computed(() => selectedTrigger.value?.needsDays);

const createCondition = () => ({
  attribute_key: triggerNeedsStage.value ? 'amount' : 'crm_stage_id',
  filter_operator: 'equal_to',
  values: [''],
  query_operator: 'AND',
});

const createDefaultButton = index => ({
  title: t('CRM.AUTOMATIONS.MESSAGE.BUTTON_DEFAULT'),
  value: `option_${index + 1}`,
});

function defaultActionParams(actionName) {
  if (actionName === 'send_lead_message') {
    return {
      message_kind: 'text',
      content: '',
      attachments: [],
      file_name: '',
      buttons: [createDefaultButton(0)],
      template_json:
        '{\n  "name": "",\n  "language": "",\n  "processed_params": {}\n}',
    };
  }

  if (actionName === 'change_stage') return { stage_id: '' };
  if (actionName === 'change_pipeline') return { pipeline_id: '' };
  if (actionName === 'assign_agent') return { agent_id: '' };
  if (actionName === 'update_field') return { field: 'name', value: '' };
  if (actionName === 'send_webhook_event') return { url: '' };
  return {};
}

const createAction = (actionName = 'send_lead_message') => ({
  action_name: actionName,
  action_params: defaultActionParams(actionName),
});

function resetForm() {
  Object.assign(form, {
    name: '',
    active: true,
    crm_pipeline_id: '',
    trigger_type: 'deal_entered_stage',
    trigger_stage_id: '',
    trigger_days: 1,
    conditions: [],
    actions: [createAction()],
  });
}

function updateConditionAttribute(condition) {
  condition.values = [''];
  condition.filter_operator = 'equal_to';
}

function updateActionType(action) {
  action.action_params = defaultActionParams(action.action_name);
}

function addCondition() {
  form.conditions.push(createCondition());
}

function removeCondition(index) {
  form.conditions.splice(index, 1);
}

function addAction() {
  form.actions.push(createAction());
}

function removeAction(index) {
  form.actions.splice(index, 1);
}

function addButton(action) {
  action.action_params.buttons.push(
    createDefaultButton(action.action_params.buttons.length)
  );
}

function removeButton(action, index) {
  action.action_params.buttons.splice(index, 1);
}

function setLeadMessageKind(action, kindId) {
  action.action_params.message_kind = kindId;

  if (
    kindId === 'buttons' &&
    (!action.action_params.buttons || !action.action_params.buttons.length)
  ) {
    action.action_params.buttons = [createDefaultButton(0)];
  }
}

async function handleFileChange(action, event) {
  const file = event.target.files?.[0];
  if (!file) return;

  const uploaded = await store.dispatch(
    'crmAutomations/uploadAttachment',
    file
  );
  action.action_params.attachments = [uploaded.blobId];
  action.action_params.file_name = file.name;
  event.target.value = null;
}

function parseTemplateParams(action) {
  try {
    return JSON.parse(action.action_params.template_json || '{}');
  } catch {
    throw new Error(t('CRM.AUTOMATIONS.MESSAGE.INVALID_TEMPLATE_JSON'));
  }
}

function normalizeLeadMessageAction(action) {
  const params = action.action_params;
  const payload = {
    message_kind: params.message_kind,
    content: params.content,
    content_type: params.message_kind === 'buttons' ? 'input_select' : 'text',
    attachments: params.message_kind === 'media' ? params.attachments : [],
  };

  if (params.message_kind === 'buttons') {
    payload.content_attributes = {
      items: params.buttons
        .filter(button => button.title?.trim())
        .map(button => ({
          title: button.title,
          value: button.value || button.title,
        })),
    };
  }

  if (params.message_kind === 'template') {
    payload.template_params = parseTemplateParams(action);
  }

  return {
    action_name: action.action_name,
    action_params: payload,
  };
}

function hasValidButtonOptions(action) {
  return action.action_params.buttons?.some(button => button.title?.trim());
}

function validateActions() {
  const invalidButtonsAction = form.actions.find(
    action =>
      action.action_name === 'send_lead_message' &&
      action.action_params.message_kind === 'buttons' &&
      !hasValidButtonOptions(action)
  );

  if (invalidButtonsAction) {
    error.value = t('CRM.AUTOMATIONS.MESSAGE.BUTTON_REQUIRED');
    return false;
  }

  const missingStage = form.actions.find(
    action =>
      action.action_name === 'change_stage' && !action.action_params.stage_id
  );

  if (missingStage) {
    error.value = t('CRM.AUTOMATIONS.FORM.STAGE_REQUIRED');
    return false;
  }

  const missingPipeline = form.actions.find(
    action =>
      action.action_name === 'change_pipeline' &&
      !action.action_params.pipeline_id
  );

  if (missingPipeline) {
    error.value = t('CRM.AUTOMATIONS.FORM.PIPELINE_REQUIRED');
    return false;
  }

  const missingWebhookUrl = form.actions.find(
    action =>
      action.action_name === 'send_webhook_event' && !action.action_params.url
  );

  if (missingWebhookUrl) {
    error.value = t('CRM.AUTOMATIONS.FORM.WEBHOOK_URL_REQUIRED');
    return false;
  }

  return true;
}

function normalizeAction(action) {
  if (action.action_name === 'send_lead_message') {
    return normalizeLeadMessageAction(action);
  }

  return {
    action_name: action.action_name,
    action_params: action.action_params,
  };
}

function systemConditions() {
  const conditions = [];

  if (triggerNeedsStage.value && form.trigger_stage_id) {
    conditions.push({
      attribute_key: 'crm_stage_id',
      filter_operator: 'equal_to',
      values: [form.trigger_stage_id],
      query_operator: 'AND',
    });
  }

  if (form.trigger_type === 'deal_stagnant' && form.trigger_days) {
    conditions.push({
      attribute_key: 'days_in_stage',
      filter_operator: 'gte',
      values: [Number(form.trigger_days)],
      query_operator: 'AND',
    });
  }

  if (
    form.trigger_type === 'deal_close_date_approaching' &&
    form.trigger_days
  ) {
    conditions.push({
      attribute_key: 'close_date',
      filter_operator: 'days_before',
      values: [Number(form.trigger_days)],
      query_operator: 'AND',
    });
  }

  return conditions;
}

function normalizeConditions() {
  const manualConditions = form.conditions
    .filter(condition => condition.attribute_key && condition.filter_operator)
    .map(condition => {
      const operator = OPERATORS.find(
        item => item.id === condition.filter_operator
      );
      return {
        attribute_key: condition.attribute_key,
        filter_operator: condition.filter_operator,
        values: operator?.hidesValue ? [] : condition.values,
        query_operator: condition.query_operator || 'AND',
      };
    });

  return [...systemConditions(), ...manualConditions];
}

function buildPayload() {
  return {
    name: form.name.trim(),
    active: form.active,
    crm_pipeline_id: form.crm_pipeline_id || null,
    trigger_type: form.trigger_type,
    conditions: normalizeConditions(),
    actions: form.actions.map(normalizeAction),
  };
}

function leadMessageKind(params) {
  if (params.message_kind) return params.message_kind;
  if (params.template_params) return 'template';
  if (params.content_type === 'input_select') return 'buttons';
  if (params.attachments?.length) return 'media';
  return 'text';
}

function hydrateLeadMessageParams(params) {
  const hydratedButtons =
    params.buttons ||
    params.content_attributes?.items ||
    params.content_attributes?.items_attributes ||
    [];

  return {
    message_kind: leadMessageKind(params),
    content: params.content || '',
    attachments: params.attachments || [],
    file_name: params.file_name || '',
    buttons: hydratedButtons.length
      ? hydratedButtons
      : [createDefaultButton(0)],
    template_json: JSON.stringify(params.template_params || {}, null, 2),
  };
}

function conditionInputType(condition) {
  const input = conditionAttribute(condition)?.input;
  if (input === 'date') return 'date';
  if (input === 'number') return 'number';
  return 'text';
}

function hydrateAction(action) {
  const actionName = action.action_name;
  const params = action.action_params || {};

  if (actionName === 'send_lead_message') {
    return {
      action_name: actionName,
      action_params: hydrateLeadMessageParams(params),
    };
  }

  return {
    action_name: actionName,
    action_params: { ...defaultActionParams(actionName), ...params },
  };
}

function hydrateConditions(conditions = []) {
  const manualConditions = [];

  conditions.forEach(condition => {
    if (
      triggerNeedsStage.value &&
      condition.attribute_key === 'crm_stage_id' &&
      !form.trigger_stage_id
    ) {
      form.trigger_stage_id = condition.values?.[0] || '';
      return;
    }

    if (
      form.trigger_type === 'deal_stagnant' &&
      condition.attribute_key === 'days_in_stage'
    ) {
      form.trigger_days = condition.values?.[0] || 1;
      return;
    }

    if (
      form.trigger_type === 'deal_close_date_approaching' &&
      condition.attribute_key === 'close_date' &&
      condition.filter_operator === 'days_before'
    ) {
      form.trigger_days = condition.values?.[0] || 1;
      return;
    }

    manualConditions.push({
      attribute_key: condition.attribute_key,
      filter_operator: condition.filter_operator,
      values: condition.values?.length ? condition.values : [''],
      query_operator: condition.query_operator || 'AND',
    });
  });

  form.conditions = manualConditions;
}

function hydrateForm(record) {
  Object.assign(form, {
    name: record.name || '',
    active: record.active,
    crm_pipeline_id: record.crm_pipeline_id || '',
    trigger_type: record.trigger_type || 'deal_entered_stage',
    trigger_stage_id: '',
    trigger_days: 1,
    actions: record.actions?.length
      ? record.actions.map(hydrateAction)
      : [createAction()],
  });
  hydrateConditions(record.conditions || []);
}

async function loadAutomation() {
  if (!isEdit.value) {
    resetForm();
    return;
  }

  const record =
    store.getters['crmAutomations/byId'](automationId.value) ||
    (await store.dispatch('crmAutomations/fetchOne', automationId.value));
  hydrateForm(record);
}

async function saveAutomation() {
  error.value = '';
  if (!form.name.trim()) {
    error.value = t('CRM.AUTOMATIONS.FORM.NAME_REQUIRED');
    return;
  }

  if (!form.actions.length) {
    error.value = t('CRM.AUTOMATIONS.FORM.ACTION_REQUIRED');
    return;
  }

  if (!validateActions()) return;

  try {
    const payload = buildPayload();
    if (isEdit.value) {
      await store.dispatch('crmAutomations/update', {
        id: automationId.value,
        ...payload,
      });
    } else {
      await store.dispatch('crmAutomations/create', payload);
    }
    useAlert(t('CRM.AUTOMATIONS.FORM.SAVE_SUCCESS'));
    router.push({
      name: 'crm_automations',
      params: { accountId: accountId.value },
    });
  } catch (saveError) {
    error.value = saveError.message || t('CRM.AUTOMATIONS.FORM.SAVE_ERROR');
  }
}

function goBack() {
  router.push({
    name: 'crm_automations',
    params: { accountId: accountId.value },
  });
}

watch(
  () => form.crm_pipeline_id,
  () => {
    if (
      form.trigger_stage_id &&
      !stageOptions.value.some(stage => stage.id === form.trigger_stage_id)
    ) {
      form.trigger_stage_id = '';
    }
  }
);

onMounted(async () => {
  await Promise.all([
    pipelines.value.length
      ? Promise.resolve()
      : store.dispatch('crmDeals/fetchPipelines'),
    store.dispatch('agents/get'),
    store.dispatch('attributes/get'),
    store.dispatch('crmAutomations/fetch'),
  ]);
  await loadAutomation();
});
</script>

<template>
  <form
    class="flex flex-col flex-1 min-h-0 overflow-hidden"
    @submit.prevent="saveAutomation"
  >
    <div
      class="flex items-center justify-between gap-3 px-4 py-3 border-b border-n-weak bg-white dark:bg-n-solid-2 shrink-0"
    >
      <div class="flex items-center gap-3 min-w-0">
        <Button
          ghost
          slate
          sm
          type="button"
          icon="i-lucide-arrow-left"
          @click="goBack"
        />
        <div class="min-w-0">
          <h2 class="text-base font-semibold text-n-slate-12 truncate">
            {{ cardTitle }}
          </h2>
          <p class="mt-0.5 text-xs text-n-slate-10">
            {{ t('CRM.AUTOMATIONS.FORM.SUBTITLE') }}
          </p>
        </div>
      </div>

      <div class="flex items-center gap-3">
        <label class="inline-flex items-center gap-2 text-sm text-n-slate-11">
          <Switch v-model="form.active" />
          {{
            form.active
              ? t('CRM.AUTOMATIONS.STATUS.ACTIVE')
              : t('CRM.AUTOMATIONS.STATUS.INACTIVE')
          }}
        </label>
        <Button
          type="submit"
          icon="i-lucide-save"
          :label="saveLabel"
          :is-loading="uiFlags.isCreating || uiFlags.isUpdating"
        />
      </div>
    </div>

    <div class="flex-1 overflow-auto p-4">
      <div class="mx-auto flex max-w-5xl flex-col gap-4">
        <Banner v-if="error" color="ruby">
          {{ error }}
        </Banner>

        <CardLayout>
          <div class="flex items-center gap-2">
            <i class="i-lucide-badge-info w-4 h-4 text-n-slate-9" />
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('CRM.AUTOMATIONS.FORM.SECTIONS.IDENTITY') }}
            </h3>
          </div>
          <div class="grid gap-3 md:grid-cols-[1fr_16rem]">
            <Input
              v-model="form.name"
              :label="t('CRM.AUTOMATIONS.FORM.NAME')"
            />
            <label class="block">
              <span class="mb-1 block text-xs text-n-slate-11">
                {{ t('CRM.AUTOMATIONS.FORM.PIPELINE') }}
              </span>
              <FilterSelect
                v-model="form.crm_pipeline_id"
                :options="pipelineOptions"
              />
            </label>
          </div>
        </CardLayout>

        <CardLayout>
          <div class="flex items-center gap-2">
            <i class="i-lucide-zap w-4 h-4 text-n-slate-9" />
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('CRM.AUTOMATIONS.FORM.SECTIONS.TRIGGER') }}
            </h3>
          </div>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <RadioCard
              v-for="trigger in TRIGGERS"
              :id="trigger.id"
              :key="trigger.id"
              :is-active="form.trigger_type === trigger.id"
              :label="t(trigger.labelKey)"
              :description="t(trigger.descriptionKey)"
              @select="value => (form.trigger_type = value)"
            />
          </div>

          <div
            v-if="triggerNeedsStage || triggerNeedsDays"
            class="grid gap-3 md:grid-cols-[16rem_16rem]"
          >
            <label v-if="triggerNeedsStage" class="block">
              <span class="mb-1 block text-xs text-n-slate-11">
                {{ t('CRM.AUTOMATIONS.FORM.STAGE') }}
              </span>
              <FilterSelect
                v-model="form.trigger_stage_id"
                :options="stageSelectOptions"
                :label="
                  !form.trigger_stage_id
                    ? t('CRM.AUTOMATIONS.FORM.SELECT_STAGE')
                    : null
                "
              />
            </label>

            <Input
              v-if="triggerNeedsDays"
              v-model.number="form.trigger_days"
              type="number"
              min="1"
              :label="t('CRM.AUTOMATIONS.FORM.DAYS')"
            />
          </div>
        </CardLayout>

        <CardLayout>
          <div class="flex items-center gap-2">
            <i class="i-lucide-filter w-4 h-4 text-n-slate-9" />
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('CRM.AUTOMATIONS.FORM.SECTIONS.CONDITIONS') }}
            </h3>
          </div>

          <ul
            class="grid list-none gap-3 rounded-xl p-3 outline outline-1 -outline-offset-1 outline-n-weak dark:outline-n-strong"
          >
            <li
              v-for="(condition, index) in form.conditions"
              :key="index"
              class="flex flex-wrap items-center gap-2"
            >
              <FilterSelect
                v-if="index > 0"
                v-model="condition.query_operator"
                variant="faded"
                hide-icon
                :options="queryOperatorSelectOptions"
              />
              <FilterSelect
                v-model="condition.attribute_key"
                variant="faded"
                :options="conditionAttributeSelectOptions"
                @update:model-value="updateConditionAttribute(condition)"
              />
              <FilterSelect
                v-model="condition.filter_operator"
                variant="ghost"
                :options="operatorOptionsFor(condition)"
              />
              <template v-if="!conditionOperatorHidesValue(condition)">
                <FilterSelect
                  v-if="conditionValueUsesSelect(condition)"
                  v-model="condition.values[0]"
                  variant="faded"
                  :options="conditionValueSelectOptions(condition)"
                />
                <Input
                  v-else
                  v-model="condition.values[0]"
                  :type="conditionInputType(condition)"
                  size="sm"
                  class="min-w-40 [&>input]:h-8"
                />
              </template>
              <Button
                sm
                solid
                slate
                type="button"
                icon="i-lucide-trash"
                class="flex-shrink-0"
                @click="removeCondition(index)"
              />
            </li>
            <li>
              <Button
                icon="i-lucide-plus"
                blue
                faded
                sm
                type="button"
                :label="t('CRM.AUTOMATIONS.FORM.ADD_CONDITION')"
                @click="addCondition"
              />
            </li>
          </ul>
        </CardLayout>

        <CardLayout>
          <div class="flex items-center gap-2">
            <i class="i-lucide-workflow w-4 h-4 text-n-slate-9" />
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('CRM.AUTOMATIONS.FORM.SECTIONS.ACTIONS') }}
            </h3>
          </div>

          <div class="flex flex-col gap-3">
            <CardLayout v-for="(action, index) in form.actions" :key="index">
              <div class="flex items-center gap-2">
                <i
                  v-if="actionMeta(action)"
                  class="h-4 w-4 flex-shrink-0 text-n-slate-9"
                  :class="actionMeta(action).icon"
                />
                <FilterSelect
                  v-model="action.action_name"
                  variant="faded"
                  :options="actionTypeSelectOptions"
                  @update:model-value="updateActionType(action)"
                />
                <Button
                  class="ml-auto flex-shrink-0"
                  sm
                  solid
                  slate
                  type="button"
                  icon="i-lucide-trash"
                  @click="removeAction(index)"
                />
              </div>

              <div
                v-if="action.action_name === 'send_lead_message'"
                class="grid gap-3"
              >
                <div class="flex flex-wrap gap-2">
                  <Button
                    v-for="kind in messageKindOptions"
                    :key="kind.id"
                    type="button"
                    sm
                    :solid="action.action_params.message_kind === kind.id"
                    :blue="action.action_params.message_kind === kind.id"
                    :faded="action.action_params.message_kind !== kind.id"
                    :slate="action.action_params.message_kind !== kind.id"
                    :icon="kind.icon"
                    :label="kind.label"
                    @click="setLeadMessageKind(action, kind.id)"
                  />
                </div>

                <textarea
                  v-model="action.action_params.content"
                  rows="4"
                  class="w-full rounded-lg bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand dark:outline-n-strong"
                />

                <div
                  v-if="action.action_params.message_kind === 'media'"
                  class="flex items-center gap-2"
                >
                  <input
                    :ref="el => (fileInputs[index] = el)"
                    type="file"
                    class="hidden"
                    @change="handleFileChange(action, $event)"
                  />
                  <Button
                    faded
                    slate
                    sm
                    type="button"
                    icon="i-lucide-paperclip"
                    :label="t('CRM.AUTOMATIONS.MESSAGE.UPLOAD')"
                    :is-loading="uiFlags.isUploading"
                    @click="fileInputs[index]?.click()"
                  />
                  <span class="text-sm text-n-slate-10">
                    {{ action.action_params.file_name }}
                  </span>
                </div>

                <div
                  v-if="action.action_params.message_kind === 'buttons'"
                  class="grid gap-2"
                >
                  <div
                    v-for="(button, buttonIndex) in action.action_params
                      .buttons"
                    :key="buttonIndex"
                    class="grid items-end gap-2 md:grid-cols-[1fr_1fr_2rem]"
                  >
                    <Input v-model="button.title" size="sm" />
                    <Input v-model="button.value" size="sm" />
                    <Button
                      sm
                      solid
                      slate
                      type="button"
                      icon="i-lucide-trash"
                      @click="removeButton(action, buttonIndex)"
                    />
                  </div>
                  <div>
                    <Button
                      faded
                      slate
                      sm
                      type="button"
                      icon="i-lucide-plus"
                      :label="t('CRM.AUTOMATIONS.MESSAGE.ADD_BUTTON')"
                      @click="addButton(action)"
                    />
                  </div>
                </div>

                <textarea
                  v-if="action.action_params.message_kind === 'template'"
                  v-model="action.action_params.template_json"
                  rows="7"
                  class="w-full rounded-lg bg-n-alpha-black2 px-3 py-2 font-mono text-xs text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand dark:outline-n-strong"
                />

                <div
                  class="rounded-lg bg-n-alpha-1 p-3 outline outline-1 -outline-offset-1 outline-n-weak dark:outline-n-strong"
                >
                  <p class="whitespace-pre-wrap text-sm text-n-slate-12">
                    {{
                      action.action_params.content ||
                      t('CRM.AUTOMATIONS.MESSAGE.EMPTY_PREVIEW')
                    }}
                  </p>
                  <div
                    v-if="action.action_params.message_kind === 'buttons'"
                    class="mt-3 flex flex-wrap gap-2"
                  >
                    <span
                      v-for="button in action.action_params.buttons"
                      :key="button.value"
                      class="rounded-md bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-11"
                    >
                      {{ button.title }}
                    </span>
                  </div>
                </div>
              </div>

              <FilterSelect
                v-else-if="action.action_name === 'change_stage'"
                v-model="action.action_params.stage_id"
                :options="stageSelectOptions"
              />

              <FilterSelect
                v-else-if="action.action_name === 'change_pipeline'"
                v-model="action.action_params.pipeline_id"
                :options="pipelineSelectOptions"
              />

              <FilterSelect
                v-else-if="action.action_name === 'assign_agent'"
                v-model="action.action_params.agent_id"
                :options="assignAgentSelectOptions"
              />

              <div
                v-else-if="action.action_name === 'update_field'"
                class="grid gap-2 md:grid-cols-[1fr_1fr]"
              >
                <FilterSelect
                  v-model="action.action_params.field"
                  :options="fieldSelectOptions"
                />
                <Input v-model="action.action_params.value" size="sm" />
              </div>

              <Input
                v-else-if="action.action_name === 'send_webhook_event'"
                v-model="action.action_params.url"
                type="url"
                size="sm"
              />
            </CardLayout>

            <div>
              <Button
                icon="i-lucide-plus"
                blue
                faded
                sm
                type="button"
                :label="t('CRM.AUTOMATIONS.FORM.ADD_ACTION')"
                @click="addAction"
              />
            </div>
          </div>
        </CardLayout>
      </div>
    </div>
  </form>
</template>
