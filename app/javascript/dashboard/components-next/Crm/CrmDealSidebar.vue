<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import {
  useStore,
  useStoreGetters,
  useMapGetter,
} from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import EmojiIcon from 'dashboard/components-next/emoji-icon-picker/EmojiIcon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import CrmStageProgressBar from './components/CrmStageProgressBar.vue';

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
const route = useRoute();
const router = useRouter();
const deleteDialogRef = ref(null);
const draftStageId = ref(null);
const draftCustomAttributes = ref({});
const isSavingEdit = ref(false);
const isDeletingLead = ref(false);
const isDeletingLeadAndContact = ref(false);
const showActionsDropdown = ref(false);
const showStageDropdown = ref(false);

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

const selectedStageId = computed(() =>
  isEditing.value ? draftStageId.value : props.deal.crm_stage_id
);

const currentStage = computed(
  () => stages.value.find(stage => stage.id === selectedStageId.value) ?? null
);

const headerStyle = computed(() => {
  const tint = hexToRgba(currentStage.value?.color, 0.14);
  return tint ? { backgroundColor: tint } : {};
});

const displayName = computed(() => props.deal.contact?.name || props.deal.name);

const contactResponsible = computed(() => props.deal.contact_responsible ?? null);

const contactResponsibleLabel = computed(() =>
  contactResponsible.value?.type === 'team'
    ? t('CRM.CONTACT_TEAM')
    : t('CRM.CONTACT_ASSIGNEE')
);

const contactResponsibleName = computed(
  () => contactResponsible.value?.name ?? ''
);

const latestConversation = computed(
  () => props.deal.latest_contact_conversation ?? null
);

const latestConversationInbox = computed(
  () => latestConversation.value?.inbox ?? null
);

const canOpenConversation = computed(() => Boolean(latestConversation.value?.id));

const canOpenContact = computed(() => Boolean(props.deal.contact?.id));

const actionMenuItems = computed(() => [
  ...(canOpenConversation.value
    ? [
        {
          label: t('CRM.GO_TO_CONVERSATION'),
          action: 'conversation',
          value: 'conversation',
          icon: 'i-lucide-message-circle',
        },
      ]
    : []),
  ...(canOpenContact.value
    ? [
        {
          label: t('CRM.VIEW_CONTACT'),
          action: 'contact',
          value: 'contact',
          icon: 'i-lucide-contact',
        },
      ]
    : []),
  {
    label: t('CRM.FORM.EDIT_DEAL'),
    action: 'edit',
    value: 'edit',
    icon: 'i-lucide-pencil',
  },
]);

const displayedCustomAttributes = computed(() =>
  isEditing.value ? draftCustomAttributes.value : props.deal.custom_attributes || {}
);

const hasDraftChanges = computed(() => {
  const originalStageId = props.deal.crm_stage_id;
  const originalAttributes = props.deal.custom_attributes || {};

  return (
    draftStageId.value !== originalStageId ||
    JSON.stringify(draftCustomAttributes.value) !==
      JSON.stringify(originalAttributes)
  );
});

watch(isEditing, value => {
  if (!value) {
    showStageDropdown.value = false;
    resetDraftState();
  }
});

watch(
  () => props.deal.id,
  () => {
    isEditing.value = false;
    showActionsDropdown.value = false;
    showStageDropdown.value = false;
    resetDraftState();
  }
);

const customAttributeDefinitions = computed(() =>
  getters['attributes/getDealAttributesByPipeline'].value(
    props.deal.crm_pipeline_id
  )
);

const customFields = computed(() =>
  customAttributeDefinitions.value.map(definition => ({
    ...definition,
    value: displayedCustomAttributes.value[definition.attribute_key] ?? '',
  }))
);

function formatDateValue(value) {
  if (!value) return '---';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString('pt-BR');
}

function formatAttributeValue(field) {
  const { attribute_display_type: type, value } = field;

  if (type === 'checkbox') {
    return value === true || value === 'true'
      ? t('CONTACT_PANEL.ATTRIBUTES.YES')
      : t('CONTACT_PANEL.ATTRIBUTES.NO');
  }

  if (value === null || value === undefined || value === '') {
    return '---';
  }

  if (type === 'date') {
    return formatDateValue(value);
  }

  return String(value);
}

function getDraftAttributeValue(field) {
  const value = draftCustomAttributes.value[field.attribute_key];

  if (field.attribute_display_type === 'checkbox') {
    return value === true || value === 'true';
  }

  if (value === null || value === undefined) {
    return '';
  }

  if (field.attribute_display_type === 'date') {
    if (!value) return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';
    return date.toISOString().split('T')[0];
  }

  return value;
}

function normalizeAttributeValue(type, value) {
  if (type === 'checkbox') {
    return Boolean(value);
  }

  if (value === '' || value === null || value === undefined) {
    return '';
  }

  if (['number', 'currency', 'percent'].includes(type)) {
    const numericValue = Number(value);
    return Number.isNaN(numericValue) ? value : numericValue;
  }

  return value;
}

function updateDraftAttribute(field, value) {
  draftCustomAttributes.value = {
    ...draftCustomAttributes.value,
    [field.attribute_key]: normalizeAttributeValue(
      field.attribute_display_type,
      value
    ),
  };
}

async function persistCustomAttributes(updatedAttributes) {
  await store.dispatch('crmDeals/updateDeal', {
    id: props.deal.id,
    custom_attributes: updatedAttributes,
  });
}

async function handleAttributeUpdate(key, value) {
  if (isEditing.value) {
    draftCustomAttributes.value = {
      ...draftCustomAttributes.value,
      [key]: value,
    };
    return;
  }

  try {
    await persistCustomAttributes({
      ...displayedCustomAttributes.value,
      [key]: value,
    });
    useAlert(t('CRM.CUSTOM_FIELDS.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.CUSTOM_FIELDS.UPDATE_ERROR'));
  }
}

async function handleAttributeDelete(key) {
  if (isEditing.value) {
    const { [key]: _removed, ...rest } = draftCustomAttributes.value;
    draftCustomAttributes.value = rest;
    return;
  }

  try {
    const { [key]: _removed, ...rest } = displayedCustomAttributes.value;
    await persistCustomAttributes(rest);
    useAlert(t('CRM.CUSTOM_FIELDS.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.CUSTOM_FIELDS.UPDATE_ERROR'));
  }
}

function initializeDraftState() {
  draftStageId.value = props.deal.crm_stage_id;
  draftCustomAttributes.value = { ...(props.deal.custom_attributes || {}) };
}

function resetDraftState() {
  draftStageId.value = null;
  draftCustomAttributes.value = {};
}

function enterEditMode() {
  initializeDraftState();
  isEditing.value = true;
}

function cancelEditMode() {
  isEditing.value = false;
}

function updateStage(stageId) {
  draftStageId.value = stageId;
  showStageDropdown.value = false;
}

async function confirmEditMode() {
  if (!hasDraftChanges.value) {
    isEditing.value = false;
    return;
  }

  isSavingEdit.value = true;
  try {
    await store.dispatch('crmDeals/updateDeal', {
      id: props.deal.id,
      crm_stage_id: draftStageId.value,
      custom_attributes: draftCustomAttributes.value,
    });
    isEditing.value = false;
    useAlert(t('CRM.EDIT_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.EDIT_ERROR'));
  } finally {
    isSavingEdit.value = false;
  }
}

async function deleteLead() {
  isDeletingLead.value = true;
  try {
    await store.dispatch('crmDeals/deleteDeal', props.deal.id);
    deleteDialogRef.value?.close();
    emit('deleted', props.deal.id);
    emit('close');
  } finally {
    isDeletingLead.value = false;
  }
}

async function deleteLeadAndContact() {
  isDeletingLeadAndContact.value = true;
  try {
    await store.dispatch('crmDeals/deleteDeal', props.deal.id);

    if (props.deal.contact?.id) {
      await store.dispatch('contacts/delete', props.deal.contact.id);
    }

    deleteDialogRef.value?.close();
    emit('deleted', props.deal.id);
    emit('close');
  } finally {
    isDeletingLeadAndContact.value = false;
  }
}

function openConversation() {
  if (!canOpenConversation.value) return;

  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: latestConversation.value.id,
    },
  });
}

function openContact() {
  if (!canOpenContact.value) return;

  router.push({
    name: 'contacts_edit',
    params: {
      accountId: route.params.accountId,
      contactId: props.deal.contact.id,
    },
  });
}

function handleActionClick({ action }) {
  showActionsDropdown.value = false;

  if (action === 'conversation') {
    openConversation();
    return;
  }

  if (action === 'contact') {
    openContact();
    return;
  }

  if (action === 'edit') {
    enterEditMode();
  }
}

function openDeleteDialog() {
  deleteDialogRef.value?.open();
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
        <div class="flex items-center gap-2 min-w-0 flex-1 mr-2">
          <Avatar
            :name="displayName"
            :src="deal.contact?.thumbnail || ''"
            :size="64"
          />
          <h2 class="text-sm font-semibold text-n-slate-12 truncate">
            {{ displayName }}
          </h2>
        </div>
        <div class="flex items-center gap-1">
          <button
            class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            @click="emit('close')"
          >
            <i class="i-lucide-x w-4 h-4" />
          </button>
          <div
            v-on-clickaway="() => (showActionsDropdown = false)"
            class="relative flex items-center"
          >
            <button
              v-tooltip="t('CONVERSATION.HEADER.MORE_ACTIONS')"
              class="p-1 rounded-md text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
              :class="showActionsDropdown ? 'bg-n-alpha-2 text-n-slate-12' : ''"
              @click="showActionsDropdown = !showActionsDropdown"
            >
              <i class="i-lucide-more-vertical w-4 h-4" />
            </button>
            <DropdownMenu
              v-if="showActionsDropdown"
              :menu-items="actionMenuItems"
              class="mt-1 ltr:right-0 rtl:left-0 top-full"
              @action="handleActionClick"
            />
          </div>
        </div>
      </div>
      <div v-if="isEditing" v-on-clickaway="() => (showStageDropdown = false)" class="relative w-full">
        <button
          type="button"
          class="w-full flex items-center justify-between gap-3 px-2.5 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 text-sm font-medium hover:bg-n-alpha-1 transition-colors"
          @click="showStageDropdown = !showStageDropdown"
        >
          <span class="flex items-center gap-2 min-w-0">
            <span
              class="size-2 rounded-full flex-shrink-0"
              :style="{ backgroundColor: currentStage?.color || '#94A3B8' }"
            />
            <span class="truncate">{{ currentStage?.name }}</span>
          </span>
          <i
            class="i-lucide-chevron-down w-4 h-4 flex-shrink-0 text-n-slate-10"
          />
        </button>

        <div
          v-if="showStageDropdown"
          class="absolute top-full left-0 right-0 z-50 mt-1 p-2 rounded-xl bg-n-alpha-3 backdrop-blur-[100px] outline outline-1 outline-n-container shadow-lg"
        >
          <button
            v-for="stage in stages"
            :key="stage.id"
            type="button"
            class="w-full h-9 px-2 rounded-lg flex items-center gap-2 text-sm text-n-slate-12 hover:bg-n-alpha-1 transition-colors"
            :class="
              stage.id === selectedStageId
                ? 'bg-n-alpha-1 dark:bg-n-solid-active'
                : ''
            "
            @click="updateStage(stage.id)"
          >
            <span
              class="size-2 rounded-full flex-shrink-0"
              :style="{ backgroundColor: stage.color || '#94A3B8' }"
            />
            <span class="truncate">{{ stage.name }}</span>
          </button>
        </div>
      </div>
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
      <div v-if="contactResponsible" class="pb-3">
        <p class="text-xs text-n-slate-9 mb-1">{{ contactResponsibleLabel }}</p>
        <div class="flex items-center gap-2 text-sm text-n-slate-12">
          <Avatar
            v-if="contactResponsible.type === 'agent'"
            :name="contactResponsibleName"
            :src="contactResponsible.thumbnail || ''"
            :size="16"
            rounded-full
          />
          <span
            v-else
            class="flex items-center justify-center size-4 rounded-md outline outline-1 outline-n-weak -outline-offset-1"
          >
            <EmojiIcon
              v-if="contactResponsible.icon"
              :value="contactResponsible.icon"
              :color="contactResponsible.icon_color"
              class="size-3"
            />
            <Icon
              v-else
              icon="i-lucide-users-round"
              class="size-3 text-n-slate-11"
            />
          </span>
          <span>{{ contactResponsibleName }}</span>
        </div>
      </div>

      <div v-if="latestConversationInbox" class="pb-3">
        <p class="text-xs text-n-slate-9 mb-1">{{ t('CRM.INBOX') }}</p>
        <div class="flex items-center gap-2 text-sm text-n-slate-12 min-w-0">
          <ChannelIcon
            :inbox="latestConversationInbox"
            class="size-4 flex-shrink-0 text-n-slate-11"
          />
          <span class="truncate">{{ latestConversationInbox.name }}</span>
        </div>
      </div>

        <div class="flex flex-col -mx-4 border-t border-n-weak">
          <div class="flex items-center justify-between px-4 pt-3 pb-1">
            <p class="text-xs text-n-slate-9">
              {{ t('CRM.CUSTOM_FIELDS.TITLE') }}
            </p>
          </div>

          <div
            v-for="field in customFields"
            :key="field.id"
            class="border-b border-n-weak last:border-b-0 px-4 py-3"
          >
            <div class="flex items-start justify-between gap-3">
              <p class="m-0 text-sm font-medium text-n-slate-12 shrink-0 max-w-[48%]">
                {{ field.attribute_display_name }}
              </p>
              <div class="flex-1 min-w-0">
                <template v-if="isEditing">
                  <label
                    v-if="field.attribute_display_type === 'checkbox'"
                    class="flex justify-end"
                  >
                    <input
                      :checked="getDraftAttributeValue(field)"
                      type="checkbox"
                      class="h-4 w-4 rounded border-n-weak bg-transparent"
                      @change="
                        updateDraftAttribute(field, $event.target.checked)
                      "
                    />
                  </label>

                  <select
                    v-else-if="field.attribute_display_type === 'list'"
                    :value="getDraftAttributeValue(field)"
                    class="w-full h-9 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-2 text-sm text-right text-n-slate-12"
                    @change="updateDraftAttribute(field, $event.target.value)"
                  >
                    <option value="">---</option>
                    <option
                      v-for="option in field.attribute_values || []"
                      :key="option"
                      :value="option"
                    >
                      {{ option }}
                    </option>
                  </select>

                  <input
                    v-else
                    :value="getDraftAttributeValue(field)"
                    :type="
                      field.attribute_display_type === 'link'
                        ? 'url'
                        : field.attribute_display_type
                    "
                    class="w-full h-9 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-2 text-sm text-right text-n-slate-12"
                    @input="updateDraftAttribute(field, $event.target.value)"
                  />
                </template>

                <template v-else>
                  <a
                    v-if="
                      field.attribute_display_type === 'link' &&
                      field.value
                    "
                    :href="field.value"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="block text-sm text-right text-n-slate-12 break-all hover:underline"
                  >
                    {{ formatAttributeValue(field) }}
                  </a>
                  <p
                    v-else
                    class="m-0 text-sm text-right text-n-slate-11 break-words"
                  >
                    {{ formatAttributeValue(field) }}
                  </p>
                </template>
              </div>
            </div>
          </div>
        </div>
    </div>

    <div v-if="isEditing" class="mt-auto p-4 border-t border-n-weak flex flex-col gap-2">
      <div class="flex gap-2">
        <Button
          class="flex-1"
          variant="faded"
          color="slate"
          :label="t('CRM.CANCEL')"
          :disabled="isSavingEdit"
          @click="cancelEditMode"
        />
        <Button
          class="flex-1"
          color="blue"
          :label="t('CRM.CONFIRM')"
          :is-loading="isSavingEdit"
          :disabled="!hasDraftChanges || isSavingEdit"
          @click="confirmEditMode"
        />
      </div>
      <Button
        class="w-full"
        variant="faded"
        color="ruby"
        :label="t('CRM.DELETE')"
        :disabled="isSavingEdit || isDeletingLead || isDeletingLeadAndContact"
        @click="openDeleteDialog"
      />
    </div>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      width="md"
      :title="t('CRM.DELETE_DIALOG_TITLE')"
      :description="t('CRM.DELETE_DIALOG_DESCRIPTION')"
      :show-cancel-button="false"
      :show-confirm-button="false"
    >
      <template #footer>
        <div class="flex flex-col gap-3 w-full">
          <Button
            class="w-full"
            variant="faded"
            color="ruby"
            :label="t('CRM.DELETE_LEAD')"
            :is-loading="isDeletingLead"
            :disabled="isDeletingLead || isDeletingLeadAndContact"
            @click="deleteLead"
          />
          <Button
            class="w-full"
            color="ruby"
            :label="t('CRM.DELETE_LEAD_AND_CONTACT')"
            :is-loading="isDeletingLeadAndContact"
            :disabled="isDeletingLead || isDeletingLeadAndContact"
            @click="deleteLeadAndContact"
          />
          <Button
            class="w-full"
            variant="faded"
            color="slate"
            :label="t('CRM.CANCEL')"
            :disabled="isDeletingLead || isDeletingLeadAndContact"
            @click="deleteDialogRef?.close()"
          />
        </div>
      </template>
    </Dialog>
  </div>
</template>
