<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
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

const operatorOptions = computed(() =>
  OPERATORS.map(operator => ({ ...operator, label: t(operator.labelKey) }))
);

const actionOptions = computed(() =>
  ACTIONS.map(action => ({ ...action, label: t(action.labelKey) }))
);

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
  attribute_key: 'crm_stage_id',
  filter_operator: 'equal_to',
  values: [''],
  query_operator: 'AND',
});

function defaultActionParams(actionName) {
  if (actionName === 'send_lead_message') {
    return {
      message_kind: 'text',
      content: '',
      attachments: [],
      file_name: '',
      buttons: [
        {
          title: t('CRM.AUTOMATIONS.MESSAGE.BUTTON_DEFAULT'),
          value: 'option_1',
        },
      ],
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

function conditionAttribute(condition) {
  return conditionAttributes.value.find(
    attribute => attribute.id === condition.attribute_key
  );
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
  action.action_params.buttons.push({
    title: t('CRM.AUTOMATIONS.MESSAGE.BUTTON_DEFAULT'),
    value: `option_${action.action_params.buttons.length + 1}`,
  });
}

function removeButton(action, index) {
  action.action_params.buttons.splice(index, 1);
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
        .filter(button => button.title.trim())
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
  return {
    message_kind: leadMessageKind(params),
    content: params.content || '',
    attachments: params.attachments || [],
    file_name: params.file_name || '',
    buttons: params.buttons ||
      params.content_attributes?.items ||
      params.content_attributes?.items_attributes || [
        {
          title: t('CRM.AUTOMATIONS.MESSAGE.BUTTON_DEFAULT'),
          value: 'option_1',
        },
      ],
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

      <div class="flex items-center gap-2">
        <label class="inline-flex items-center gap-2 text-sm text-n-slate-11">
          <input v-model="form.active" type="checkbox" class="rounded" />
          {{ t('CRM.AUTOMATIONS.STATUS.ACTIVE') }}
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
        <p
          v-if="error"
          class="rounded-lg border border-n-ruby-8 bg-n-ruby-9/10 px-3 py-2 text-sm text-n-ruby-11"
        >
          {{ error }}
        </p>

        <section
          class="rounded-lg border border-n-weak bg-white p-4 dark:bg-n-solid-2"
        >
          <div class="mb-4 flex items-center gap-2">
            <i class="i-lucide-badge-info w-4 h-4 text-n-slate-9" />
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('CRM.AUTOMATIONS.FORM.SECTIONS.IDENTITY') }}
            </h3>
          </div>
          <div class="grid gap-3 md:grid-cols-[1fr_16rem]">
            <label class="block">
              <span class="mb-1 block text-xs text-n-slate-9">
                {{ t('CRM.AUTOMATIONS.FORM.NAME') }}
              </span>
              <input
                v-model="form.name"
                type="text"
                class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              />
            </label>
            <label class="block">
              <span class="mb-1 block text-xs text-n-slate-9">
                {{ t('CRM.AUTOMATIONS.FORM.PIPELINE') }}
              </span>
              <select
                v-model="form.crm_pipeline_id"
                class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option value="">
                  {{ t('CRM.AUTOMATIONS.ALL_PIPELINES') }}
                </option>
                <option
                  v-for="pipeline in pipelines"
                  :key="pipeline.id"
                  :value="pipeline.id"
                >
                  {{ pipeline.name }}
                </option>
              </select>
            </label>
          </div>
        </section>

        <section
          class="rounded-lg border border-n-weak bg-white p-4 dark:bg-n-solid-2"
        >
          <div class="mb-4 flex items-center gap-2">
            <i class="i-lucide-zap w-4 h-4 text-n-slate-9" />
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('CRM.AUTOMATIONS.FORM.SECTIONS.TRIGGER') }}
            </h3>
          </div>
          <div class="grid gap-3 md:grid-cols-[1fr_16rem]">
            <label class="block">
              <span class="mb-1 block text-xs text-n-slate-9">
                {{ t('CRM.AUTOMATIONS.FORM.TRIGGER') }}
              </span>
              <select
                v-model="form.trigger_type"
                class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option
                  v-for="trigger in TRIGGERS"
                  :key="trigger.id"
                  :value="trigger.id"
                >
                  {{ t(trigger.labelKey) }}
                </option>
              </select>
            </label>

            <label v-if="triggerNeedsStage" class="block">
              <span class="mb-1 block text-xs text-n-slate-9">
                {{ t('CRM.AUTOMATIONS.FORM.STAGE') }}
              </span>
              <select
                v-model="form.trigger_stage_id"
                class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option value="">
                  {{ t('CRM.AUTOMATIONS.FORM.SELECT_STAGE') }}
                </option>
                <option
                  v-for="stage in stageOptions"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </select>
            </label>

            <label v-if="triggerNeedsDays" class="block">
              <span class="mb-1 block text-xs text-n-slate-9">
                {{ t('CRM.AUTOMATIONS.FORM.DAYS') }}
              </span>
              <input
                v-model.number="form.trigger_days"
                min="1"
                type="number"
                class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              />
            </label>
          </div>
        </section>

        <section
          class="rounded-lg border border-n-weak bg-white p-4 dark:bg-n-solid-2"
        >
          <div class="mb-4 flex items-center justify-between gap-3">
            <div class="flex items-center gap-2">
              <i class="i-lucide-filter w-4 h-4 text-n-slate-9" />
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CRM.AUTOMATIONS.FORM.SECTIONS.CONDITIONS') }}
              </h3>
            </div>
            <Button
              faded
              slate
              sm
              type="button"
              icon="i-lucide-plus"
              :label="t('CRM.AUTOMATIONS.FORM.ADD_CONDITION')"
              @click="addCondition"
            />
          </div>

          <div v-if="!form.conditions.length" class="text-sm text-n-slate-10">
            {{ t('CRM.AUTOMATIONS.FORM.NO_CONDITIONS') }}
          </div>

          <div v-else class="flex flex-col gap-2">
            <div
              v-for="(condition, index) in form.conditions"
              :key="index"
              class="grid gap-2 rounded-lg border border-n-weak p-3 md:grid-cols-[6rem_1fr_11rem_1fr_2rem]"
            >
              <select
                v-model="condition.query_operator"
                class="rounded-lg border border-n-weak bg-white px-2 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option value="AND">
                  {{ t('CRM.AUTOMATIONS.CONDITIONS.AND') }}
                </option>
                <option value="OR">
                  {{ t('CRM.AUTOMATIONS.CONDITIONS.OR') }}
                </option>
              </select>
              <select
                v-model="condition.attribute_key"
                class="rounded-lg border border-n-weak bg-white px-2 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
                @change="updateConditionAttribute(condition)"
              >
                <option
                  v-for="attribute in conditionAttributes"
                  :key="attribute.id"
                  :value="attribute.id"
                >
                  {{ attribute.label }}
                </option>
              </select>
              <select
                v-model="condition.filter_operator"
                class="rounded-lg border border-n-weak bg-white px-2 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option
                  v-for="operator in operatorOptions"
                  :key="operator.id"
                  :value="operator.id"
                >
                  {{ operator.label }}
                </option>
              </select>
              <select
                v-if="conditionAttribute(condition)?.input === 'stage'"
                v-model="condition.values[0]"
                class="rounded-lg border border-n-weak bg-white px-2 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option
                  v-for="stage in stageOptions"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </select>
              <select
                v-else-if="conditionAttribute(condition)?.input === 'agent'"
                v-model="condition.values[0]"
                class="rounded-lg border border-n-weak bg-white px-2 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option
                  v-for="agent in agents"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>
              <select
                v-else-if="conditionAttribute(condition)?.input === 'list'"
                v-model="condition.values[0]"
                class="rounded-lg border border-n-weak bg-white px-2 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option
                  v-for="value in conditionAttribute(condition)?.values"
                  :key="value"
                  :value="value"
                >
                  {{ value }}
                </option>
              </select>
              <input
                v-else
                v-model="condition.values[0]"
                :type="conditionInputType(condition)"
                class="rounded-lg border border-n-weak bg-white px-2 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              />
              <Button
                ghost
                ruby
                sm
                type="button"
                icon="i-lucide-trash-2"
                @click="removeCondition(index)"
              />
            </div>
          </div>
        </section>

        <section
          class="rounded-lg border border-n-weak bg-white p-4 dark:bg-n-solid-2"
        >
          <div class="mb-4 flex items-center justify-between gap-3">
            <div class="flex items-center gap-2">
              <i class="i-lucide-workflow w-4 h-4 text-n-slate-9" />
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CRM.AUTOMATIONS.FORM.SECTIONS.ACTIONS') }}
              </h3>
            </div>
            <Button
              faded
              slate
              sm
              type="button"
              icon="i-lucide-plus"
              :label="t('CRM.AUTOMATIONS.FORM.ADD_ACTION')"
              @click="addAction"
            />
          </div>

          <div class="flex flex-col gap-3">
            <div
              v-for="(action, index) in form.actions"
              :key="index"
              class="rounded-lg border border-n-weak p-3"
            >
              <div class="mb-3 flex items-center gap-2">
                <select
                  v-model="action.action_name"
                  class="min-w-64 rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
                  @change="updateActionType(action)"
                >
                  <option
                    v-for="item in actionOptions"
                    :key="item.id"
                    :value="item.id"
                  >
                    {{ item.label }}
                  </option>
                </select>
                <Button
                  class="ml-auto"
                  ghost
                  ruby
                  sm
                  type="button"
                  icon="i-lucide-trash-2"
                  @click="removeAction(index)"
                />
              </div>

              <div
                v-if="action.action_name === 'send_lead_message'"
                class="grid gap-3"
              >
                <div class="flex flex-wrap gap-2">
                  <button
                    v-for="kind in messageKindOptions"
                    :key="kind.id"
                    type="button"
                    class="inline-flex h-8 items-center gap-2 rounded-lg px-3 text-sm font-medium transition-colors"
                    :class="
                      action.action_params.message_kind === kind.id
                        ? 'bg-n-brand/10 text-n-blue-11'
                        : 'bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3'
                    "
                    @click="action.action_params.message_kind = kind.id"
                  >
                    <i class="w-4 h-4" :class="[kind.icon]" />
                    {{ kind.label }}
                  </button>
                </div>

                <textarea
                  v-model="action.action_params.content"
                  rows="4"
                  class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
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
                    class="grid gap-2 md:grid-cols-[1fr_1fr_2rem]"
                  >
                    <input
                      v-model="button.title"
                      type="text"
                      class="rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
                    />
                    <input
                      v-model="button.value"
                      type="text"
                      class="rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
                    />
                    <Button
                      ghost
                      ruby
                      sm
                      type="button"
                      icon="i-lucide-trash-2"
                      @click="removeButton(action, buttonIndex)"
                    />
                  </div>
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

                <textarea
                  v-if="action.action_params.message_kind === 'template'"
                  v-model="action.action_params.template_json"
                  rows="7"
                  class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 font-mono text-xs text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
                />

                <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-3">
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
                      class="rounded-md bg-white px-2 py-1 text-xs text-n-slate-11 ring-1 ring-n-weak dark:bg-n-solid-3"
                    >
                      {{ button.title }}
                    </span>
                  </div>
                </div>
              </div>

              <select
                v-else-if="action.action_name === 'change_stage'"
                v-model="action.action_params.stage_id"
                class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option
                  v-for="stage in stageOptions"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </select>

              <select
                v-else-if="action.action_name === 'change_pipeline'"
                v-model="action.action_params.pipeline_id"
                class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option
                  v-for="pipeline in pipelines"
                  :key="pipeline.id"
                  :value="pipeline.id"
                >
                  {{ pipeline.name }}
                </option>
              </select>

              <select
                v-else-if="action.action_name === 'assign_agent'"
                v-model="action.action_params.agent_id"
                class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              >
                <option value="">
                  {{ t('CRM.AUTOMATIONS.ACTIONS.UNASSIGNED') }}
                </option>
                <option
                  v-for="agent in agents"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>

              <div
                v-else-if="action.action_name === 'update_field'"
                class="grid gap-2 md:grid-cols-[1fr_1fr]"
              >
                <select
                  v-model="action.action_params.field"
                  class="rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
                >
                  <option
                    v-for="field in fieldOptions"
                    :key="field.id"
                    :value="field.id"
                  >
                    {{ field.label }}
                  </option>
                </select>
                <input
                  v-model="action.action_params.value"
                  type="text"
                  class="rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
                />
              </div>

              <input
                v-else-if="action.action_name === 'send_webhook_event'"
                v-model="action.action_params.url"
                type="url"
                class="w-full rounded-lg border border-n-weak bg-white px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-1 focus:ring-woot-500 dark:bg-n-solid-3"
              />
            </div>
          </div>
        </section>
      </div>
    </div>
  </form>
</template>
