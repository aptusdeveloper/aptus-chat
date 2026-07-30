<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AgendaTabs from './AgendaTabs.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const store = useStore();
const { t } = useI18n();

const eventTypes = computed(() => store.getters['agenda/eventTypes']);
const professionals = computed(() => store.getters['agenda/professionals']);
const uiFlags = computed(() => store.getters['agenda/uiFlags']);

const formDialogRef = ref(null);
const editingId = ref(null);
const isSaving = ref(false);

const emptyForm = () => ({
  name: '',
  agendaProfessionalId: '',
  durationMinutes: 30,
  bufferBeforeMinutes: 0,
  bufferAfterMinutes: 0,
  minimumNoticeMinutes: 0,
  slotIntervalMinutes: 15,
  active: true,
});
const form = reactive(emptyForm());

function openCreateForm() {
  editingId.value = null;
  Object.assign(form, emptyForm());
  formDialogRef.value?.open();
}

function openEditForm(eventType) {
  editingId.value = eventType.id;
  Object.assign(form, {
    name: eventType.name,
    agendaProfessionalId: eventType.agenda_professional_id || '',
    durationMinutes: eventType.duration_minutes,
    bufferBeforeMinutes: eventType.buffer_before_minutes,
    bufferAfterMinutes: eventType.buffer_after_minutes,
    minimumNoticeMinutes: eventType.minimum_notice_minutes,
    slotIntervalMinutes: eventType.slot_interval_minutes,
    active: eventType.active,
  });
  formDialogRef.value?.open();
}

function professionalName(id) {
  return professionals.value.find(p => p.id === id)?.name;
}

async function saveEventType() {
  isSaving.value = true;
  const payload = {
    name: form.name,
    agenda_professional_id: form.agendaProfessionalId || null,
    duration_minutes: Number(form.durationMinutes),
    buffer_before_minutes: Number(form.bufferBeforeMinutes),
    buffer_after_minutes: Number(form.bufferAfterMinutes),
    minimum_notice_minutes: Number(form.minimumNoticeMinutes),
    slot_interval_minutes: Number(form.slotIntervalMinutes),
    active: form.active,
  };
  try {
    if (editingId.value) {
      await store.dispatch('agenda/updateEventType', {
        id: editingId.value,
        ...payload,
      });
    } else {
      await store.dispatch('agenda/createEventType', payload);
    }
    formDialogRef.value?.close();
  } catch (error) {
    useAlert(t('HUB.AGENDA.EVENT_TYPES.FORM.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
}

const deleteDialogRef = ref(null);
const deletingEventType = ref(null);
const isDeleting = ref(false);

function openDeleteDialog(eventType) {
  deletingEventType.value = eventType;
  deleteDialogRef.value?.open();
}

async function confirmDelete() {
  if (!deletingEventType.value) return;
  isDeleting.value = true;
  try {
    await store.dispatch('agenda/deleteEventType', deletingEventType.value.id);
    deleteDialogRef.value?.close();
  } catch (error) {
    useAlert(t('HUB.AGENDA.EVENT_TYPES.DELETE_ERROR'));
  } finally {
    isDeleting.value = false;
  }
}

onMounted(() => {
  store.dispatch('agenda/fetchEventTypes');
  store.dispatch('agenda/fetchProfessionals');
});
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4">
    <div class="mb-4 flex items-center justify-between">
      <div>
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('HUB.AGENDA.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-10">{{ t('HUB.AGENDA.SUBTITLE') }}</p>
      </div>
      <Button
        icon="i-lucide-plus"
        :label="t('HUB.AGENDA.EVENT_TYPES.NEW')"
        @click="openCreateForm"
      />
    </div>

    <AgendaTabs />

    <div v-if="uiFlags.isFetchingEventTypes" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.EVENT_TYPES.LOADING') }}
    </div>
    <div v-else-if="!eventTypes.length" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.EVENT_TYPES.EMPTY') }}
    </div>

    <div
      v-else
      class="rounded-lg border border-n-weak bg-n-solid-1 dark:bg-n-solid-2 divide-y divide-n-weak"
    >
      <div
        v-for="eventType in eventTypes"
        :key="eventType.id"
        class="flex items-center gap-3 px-4 py-3"
      >
        <div class="min-w-0 mr-auto">
          <p class="text-sm font-medium text-n-slate-12 truncate">
            {{ eventType.name }}
          </p>
          <p class="text-xs text-n-slate-9 truncate">
            {{
              t('HUB.AGENDA.EVENT_TYPES.DURATION_SUMMARY', {
                duration: eventType.duration_minutes,
                professional:
                  professionalName(eventType.agenda_professional_id) ||
                  t('HUB.AGENDA.EVENT_TYPES.ANY_PROFESSIONAL'),
              })
            }}
          </p>
        </div>
        <Button
          slate
          outline
          sm
          icon="i-lucide-pencil"
          :title="t('HUB.AGENDA.EVENT_TYPES.FORM.SAVE')"
          @click="openEditForm(eventType)"
        />
        <Button
          ruby
          outline
          sm
          icon="i-lucide-trash-2"
          :title="t('HUB.AGENDA.EVENT_TYPES.FORM.DELETE')"
          @click="openDeleteDialog(eventType)"
        />
      </div>
    </div>

    <Dialog
      ref="formDialogRef"
      width="xl"
      :title="
        editingId
          ? t('HUB.AGENDA.EVENT_TYPES.EDIT')
          : t('HUB.AGENDA.EVENT_TYPES.NEW')
      "
      :is-loading="isSaving"
      :disable-confirm-button="!form.name || !form.durationMinutes"
      :confirm-button-label="t('HUB.AGENDA.EVENT_TYPES.FORM.SAVE')"
      @confirm="saveEventType"
    >
      <div class="grid gap-4 sm:grid-cols-2">
        <div class="sm:col-span-2">
          <Input
            v-model="form.name"
            :label="t('HUB.AGENDA.EVENT_TYPES.FORM.NAME')"
            :placeholder="t('HUB.AGENDA.EVENT_TYPES.FORM.NAME_PLACEHOLDER')"
          />
        </div>
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.EVENT_TYPES.FORM.PROFESSIONAL') }}
          </label>
          <select
            v-model="form.agendaProfessionalId"
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
          >
            <option value="">
              {{ t('HUB.AGENDA.EVENT_TYPES.ANY_PROFESSIONAL') }}
            </option>
            <option
              v-for="professional in professionals"
              :key="professional.id"
              :value="professional.id"
            >
              {{ professional.name }}
            </option>
          </select>
        </div>
        <Input
          v-model.number="form.durationMinutes"
          type="number"
          min="1"
          :label="t('HUB.AGENDA.EVENT_TYPES.FORM.DURATION')"
        />
        <Input
          v-model.number="form.bufferBeforeMinutes"
          type="number"
          min="0"
          :label="t('HUB.AGENDA.EVENT_TYPES.FORM.BUFFER_BEFORE')"
        />
        <Input
          v-model.number="form.bufferAfterMinutes"
          type="number"
          min="0"
          :label="t('HUB.AGENDA.EVENT_TYPES.FORM.BUFFER_AFTER')"
        />
        <Input
          v-model.number="form.minimumNoticeMinutes"
          type="number"
          min="0"
          :label="t('HUB.AGENDA.EVENT_TYPES.FORM.MINIMUM_NOTICE')"
        />
        <Input
          v-model.number="form.slotIntervalMinutes"
          type="number"
          min="1"
          :label="t('HUB.AGENDA.EVENT_TYPES.FORM.SLOT_INTERVAL')"
        />
        <label
          class="inline-flex items-center gap-2 text-sm text-n-slate-12 pt-5"
        >
          <Switch v-model="form.active" />
          {{ t('HUB.AGENDA.EVENT_TYPES.FORM.ACTIVE') }}
        </label>
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('HUB.AGENDA.EVENT_TYPES.DELETE_CONFIRM_TITLE')"
      :description="t('HUB.AGENDA.EVENT_TYPES.DELETE_CONFIRM')"
      :is-loading="isDeleting"
      :confirm-button-label="t('HUB.AGENDA.EVENT_TYPES.FORM.DELETE')"
      @confirm="confirmDelete"
    />
  </div>
</template>
