<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  useStore,
  useStoreGetters,
  useMapGetter,
} from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { convertToAttributeSlug } from 'dashboard/helper/commons.js';
import CrmStageProgressBar from './components/CrmStageProgressBar.vue';
import CustomAttribute from 'dashboard/components/CustomAttribute.vue';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'deleted']);
const isEditing = ref(false);

const activePipeline = useMapGetter('crmDeals/activePipeline');
const stages = computed(() => activePipeline.value?.stages ?? []);

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();
const isDeleting = ref(false);
const confirmDelete = ref(false);
const customFieldMode = ref(null);
const editingCustomFieldId = ref(null);
const isSavingCustomField = ref(false);
const customFieldForm = ref({
  name: '',
  type: 'text',
  options: '',
});

const customFieldTypes = [
  { id: 'text', labelKey: 'ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.TEXT' },
  { id: 'number', labelKey: 'ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.NUMBER' },
  { id: 'currency', labelKey: 'ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.CURRENCY' },
  { id: 'percent', labelKey: 'ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.PERCENT' },
  { id: 'date', labelKey: 'ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.DATE' },
  { id: 'list', labelKey: 'ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.LIST' },
  { id: 'checkbox', labelKey: 'ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.CHECKBOX' },
  { id: 'link', labelKey: 'ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.LINK' },
];

onMounted(() => {
  store.dispatch('attributes/get');
});

// Soft tint derived from the current stage color, used to give the header
// the same "colored by stage" emphasis the reference design (Kommo) has,
// without hardcoding a fixed palette (stage.color is a free hex value).
function hexToRgba(hex, alpha) {
  if (!hex) return null;
  const value = hex.replace('#', '');
  const r = parseInt(value.substring(0, 2), 16);
  const g = parseInt(value.substring(2, 4), 16);
  const b = parseInt(value.substring(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

const currentStage = computed(
  () => stages.value.find(stage => stage.id === props.deal.crm_stage_id) ?? null
);

const headerStyle = computed(() => {
  const tint = hexToRgba(currentStage.value?.color, 0.14);
  return tint ? { backgroundColor: tint } : {};
});

const editableName = ref(props.deal.name);

watch(
  () => props.deal.name,
  value => {
    if (!isEditing.value) {
      editableName.value = value;
    }
  }
);

watch(isEditing, value => {
  if (!value) {
    confirmDelete.value = false;
  }
});

async function saveName() {
  const trimmed = editableName.value.trim();
  if (!trimmed || trimmed === props.deal.name) {
    editableName.value = props.deal.name;
    return;
  }
  try {
    await store.dispatch('crmDeals/updateDeal', {
      id: props.deal.id,
      name: trimmed,
    });
  } catch (error) {
    editableName.value = props.deal.name;
  }
}

// Same luminance-based pick as CrmStageProgressBar, duplicated locally since
// that helper isn't exported and the stage select needs it for its options.
function readableTextColor(hex) {
  if (!hex) return '#0B1C2C';
  const value = hex.replace('#', '');
  const r = parseInt(value.substring(0, 2), 16);
  const g = parseInt(value.substring(2, 4), 16);
  const b = parseInt(value.substring(4, 6), 16);
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return luminance > 0.6 ? '#0B1C2C' : '#FFFFFF';
}

const stageSelectStyle = computed(() => {
  if (!currentStage.value?.color) return {};
  return {
    backgroundColor: currentStage.value.color,
    color: readableTextColor(currentStage.value.color),
  };
});

async function updateStage(event) {
  const stageId = event.target.value;
  try {
    await store.dispatch('crmDeals/updateDeal', {
      id: props.deal.id,
      crm_stage_id: stageId,
    });
  } catch (error) {
    // The select reverts once `deal.crm_stage_id` refreshes from the store.
  }
}

const dealCustomAttributes = computed(() => props.deal.custom_attributes || {});

const customAttributeDefinitions = computed(() =>
  getters['attributes/getDealAttributesByPipeline'].value(
    props.deal.crm_pipeline_id
  )
);

const customFields = computed(() =>
  customAttributeDefinitions.value.map(definition => ({
    ...definition,
    value: dealCustomAttributes.value[definition.attribute_key] ?? '',
  }))
);

const isCustomFieldList = computed(() => customFieldForm.value.type === 'list');

function resetCustomFieldForm() {
  customFieldMode.value = null;
  editingCustomFieldId.value = null;
  customFieldForm.value = {
    name: '',
    type: 'text',
    options: '',
  };
}

function startEditCustomField(field) {
  customFieldMode.value = 'edit';
  editingCustomFieldId.value = field.id;
  customFieldForm.value = {
    name: field.attribute_display_name,
    type: field.attribute_display_type,
    options: (field.attribute_values || []).join(', '),
  };
}

function customFieldValues() {
  if (!isCustomFieldList.value) return [];

  return customFieldForm.value.options
    .split(',')
    .map(option => option.trim())
    .filter(Boolean);
}

async function saveCustomField() {
  if (!customFieldForm.value.name.trim()) return;

  const attributeValues = customFieldValues();
  if (isCustomFieldList.value && !attributeValues.length) return;

  isSavingCustomField.value = true;
  try {
    const payload = {
      attribute_display_name: customFieldForm.value.name.trim(),
      attribute_description: customFieldForm.value.name.trim(),
      attribute_model: 'deal_attribute',
      attribute_display_type: customFieldForm.value.type,
      attribute_values: attributeValues,
      crm_pipeline_id: props.deal.crm_pipeline_id,
    };

    if (customFieldMode.value === 'edit') {
      await store.dispatch('attributes/update', {
        id: editingCustomFieldId.value,
        ...payload,
      });
    } else {
      await store.dispatch('attributes/create', {
        ...payload,
        attribute_key: convertToAttributeSlug(customFieldForm.value.name),
      });
    }

    resetCustomFieldForm();
  } finally {
    isSavingCustomField.value = false;
  }
}

async function deleteCustomField(field) {
  isSavingCustomField.value = true;
  try {
    await store.dispatch('attributes/delete', field.id);
  } finally {
    isSavingCustomField.value = false;
  }
}

async function persistCustomAttributes(updatedAttributes) {
  await store.dispatch('crmDeals/updateDeal', {
    id: props.deal.id,
    custom_attributes: updatedAttributes,
  });
}

async function handleAttributeUpdate(key, value) {
  try {
    await persistCustomAttributes({
      ...dealCustomAttributes.value,
      [key]: value,
    });
    useAlert(t('CRM.CUSTOM_FIELDS.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.CUSTOM_FIELDS.UPDATE_ERROR'));
  }
}

async function handleAttributeDelete(key) {
  try {
    const { [key]: _removed, ...rest } = dealCustomAttributes.value;
    await persistCustomAttributes(rest);
    useAlert(t('CRM.CUSTOM_FIELDS.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.CUSTOM_FIELDS.UPDATE_ERROR'));
  }
}

async function handleDelete() {
  if (!confirmDelete.value) {
    confirmDelete.value = true;
    return;
  }
  isDeleting.value = true;
  try {
    await store.dispatch('crmDeals/deleteDeal', props.deal.id);
    emit('deleted', props.deal.id);
    emit('close');
  } finally {
    isDeleting.value = false;
  }
}
</script>

<template>
  <div
    class="flex flex-col h-full bg-white dark:bg-n-solid-2 border-r border-n-weak w-80 shrink-0 overflow-y-auto"
  >
    <div
      class="flex flex-col gap-3 px-4 py-3 border-b border-n-weak"
      :style="headerStyle"
    >
      <div class="flex items-center justify-between">
        <input
          v-if="isEditing"
          v-model="editableName"
          type="text"
          class="text-sm font-semibold text-n-slate-12 truncate flex-1 mr-2 px-2 py-1 rounded-md border border-n-weak bg-white dark:bg-n-solid-3 focus:outline-none focus:ring-1 focus:ring-woot-500"
          @blur="saveName"
          @keyup.enter="$event.target.blur()"
        />
        <h2
          v-else
          class="text-sm font-semibold text-n-slate-12 truncate flex-1 mr-2"
        >
          {{ deal.name }}
        </h2>
        <div class="flex items-center gap-1">
          <button
            class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            @click="isEditing = !isEditing"
          >
            <i class="i-lucide-pencil w-4 h-4" />
          </button>
          <button
            class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            @click="emit('close')"
          >
            <i class="i-lucide-x w-4 h-4" />
          </button>
        </div>
      </div>
      <select
        v-if="isEditing"
        :value="deal.crm_stage_id"
        class="text-sm font-medium px-2 py-1 rounded-md border-none focus:outline-none focus:ring-2 focus:ring-woot-500 cursor-pointer w-fit"
        :style="stageSelectStyle"
        @change="updateStage"
      >
        <option
          v-for="stage in stages"
          :key="stage.id"
          :value="stage.id"
          :style="{
            backgroundColor: stage.color,
            color: readableTextColor(stage.color),
          }"
        >
          {{ stage.name }}
        </option>
      </select>
      <CrmStageProgressBar
        v-else
        :stages="stages"
        :current-stage-id="deal.crm_stage_id"
      />
    </div>

    <div
      v-if="deal.contact"
      class="flex flex-col gap-1 p-4 border-b border-n-weak"
    >
      <p class="text-xs text-n-slate-9 mb-1">{{ t('CRM.CONTACT') }}</p>
      <p class="text-sm font-semibold text-n-slate-12">
        {{ deal.contact.name }}
      </p>
      <p
        v-if="deal.contact.phone_number"
        class="text-sm text-n-slate-11 flex items-center gap-1.5"
      >
        <i class="i-lucide-phone w-3.5 h-3.5 shrink-0" />
        {{ deal.contact.phone_number }}
      </p>
      <p
        v-if="deal.contact.email"
        class="text-sm text-n-slate-11 flex items-center gap-1.5"
      >
        <i class="i-lucide-mail w-3.5 h-3.5 shrink-0" />
        {{ deal.contact.email }}
      </p>
    </div>

    <div class="flex flex-col gap-4 p-4">
      <div v-if="deal.assignee_id" class="pb-3">
        <p class="text-xs text-n-slate-9 mb-1">{{ t('CRM.ASSIGNEE') }}</p>
        <p class="text-sm text-n-slate-12">
          {{ deal.assignee?.name ?? '-' }}
        </p>
      </div>

      <div class="flex flex-col -mx-4 border-t border-n-weak">
        <div class="flex items-center justify-between px-4 pt-3 pb-1">
          <p class="text-xs text-n-slate-9">
            {{ t('CRM.CUSTOM_FIELDS.TITLE') }}
          </p>
        </div>

        <div v-if="customFieldMode" class="px-4 py-3 border-b border-n-weak">
          <input
            v-model="customFieldForm.name"
            type="text"
            :placeholder="t('CRM.SETTINGS.CUSTOM_FIELD_NAME_PLACEHOLDER')"
            class="w-full text-sm px-3 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:ring-1 focus:ring-woot-500 mb-2"
          />
          <select
            v-model="customFieldForm.type"
            class="w-full text-sm px-3 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-woot-500 mb-2"
          >
            <option
              v-for="fieldType in customFieldTypes"
              :key="fieldType.id"
              :value="fieldType.id"
            >
              {{ t(fieldType.labelKey) }}
            </option>
          </select>
          <input
            v-if="isCustomFieldList"
            v-model="customFieldForm.options"
            type="text"
            :placeholder="t('CRM.SETTINGS.CUSTOM_FIELD_OPTIONS_PLACEHOLDER')"
            class="w-full text-sm px-3 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:ring-1 focus:ring-woot-500 mb-2"
          />
          <div class="flex gap-2">
            <button
              class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 transition-colors"
              @click="resetCustomFieldForm"
            >
              {{ t('CRM.CANCEL') }}
            </button>
            <button
              :disabled="isSavingCustomField"
              class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50 transition-colors"
              @click="saveCustomField"
            >
              {{ t('CRM.FORM.SAVE') }}
            </button>
          </div>
        </div>

        <div
          v-for="field in customFields"
          :key="field.id"
          class="border-b border-n-weak last:border-b-0"
        >
          <div class="flex items-center justify-between px-4 pt-3">
            <p class="m-0 text-sm font-medium text-n-slate-12 truncate">
              {{ field.attribute_display_name }}
            </p>
            <div class="flex items-center gap-1">
              <button
                class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
                @click="startEditCustomField(field)"
              >
                <i class="i-lucide-pencil w-3.5 h-3.5" />
              </button>
              <button
                class="p-1 rounded text-n-slate-9 hover:text-red-500 hover:bg-n-alpha-2 transition-colors"
                :disabled="isSavingCustomField"
                @click="deleteCustomField(field)"
              >
                <i class="i-lucide-trash-2 w-3.5 h-3.5" />
              </button>
            </div>
          </div>
          <CustomAttribute
            :attribute-key="field.attribute_key"
            :attribute-type="field.attribute_display_type"
            :values="field.attribute_values"
            :label="field.attribute_display_name"
            :description="field.attribute_description"
            :value="field.value"
            hide-label
            :attribute-regex="field.regex_pattern"
            :regex-cue="field.regex_cue"
            @update="handleAttributeUpdate"
            @delete="handleAttributeDelete"
          />
        </div>
      </div>
    </div>

    <div v-if="isEditing" class="mt-auto p-4 border-t border-n-weak flex gap-2">
      <button
        v-if="!confirmDelete"
        class="flex-1 text-sm px-3 py-2 rounded-lg bg-red-50 text-red-600 hover:bg-red-100 dark:bg-red-900/20 dark:text-red-400 dark:hover:bg-red-900/40 transition-colors font-medium"
        :disabled="isDeleting"
        @click="handleDelete"
      >
        {{ t('CRM.DELETE') }}
      </button>
      <template v-else>
        <button
          class="flex-1 text-sm px-3 py-2 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 transition-colors font-medium"
          @click="confirmDelete = false"
        >
          {{ t('CRM.CANCEL') }}
        </button>
        <button
          class="flex-1 text-sm px-3 py-2 rounded-lg bg-red-600 text-white hover:bg-red-700 transition-colors font-medium"
          :disabled="isDeleting"
          @click="handleDelete"
        >
          {{ isDeleting ? t('CRM.DELETING') : t('CRM.CONFIRM_DELETE') }}
        </button>
      </template>
    </div>
  </div>
</template>
