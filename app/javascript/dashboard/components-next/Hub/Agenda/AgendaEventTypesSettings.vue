<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import AgendaTabs from './AgendaTabs.vue';

const store = useStore();
const { t } = useI18n();

const eventTypes = computed(() => store.getters['agenda/eventTypes']);
const professionals = computed(() => store.getters['agenda/professionals']);
const uiFlags = computed(() => store.getters['agenda/uiFlags']);

const isFormOpen = ref(false);
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
  isFormOpen.value = true;
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
  isFormOpen.value = true;
}

function closeForm() {
  isFormOpen.value = false;
  editingId.value = null;
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
    closeForm();
  } finally {
    isSaving.value = false;
  }
}

async function deleteEventType(eventType) {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('HUB.AGENDA.EVENT_TYPES.DELETE_CONFIRM'))) return;
  await store.dispatch('agenda/deleteEventType', eventType.id);
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
      <button
        class="inline-flex items-center gap-2 h-9 px-3 rounded-lg text-sm font-medium bg-n-brand text-white hover:opacity-90"
        @click="openCreateForm"
      >
        {{ t('HUB.AGENDA.EVENT_TYPES.NEW') }}
      </button>
    </div>

    <AgendaTabs />

    <div
      v-if="isFormOpen"
      class="mb-4 rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4"
    >
      <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
        {{
          editingId
            ? t('HUB.AGENDA.EVENT_TYPES.EDIT')
            : t('HUB.AGENDA.EVENT_TYPES.NEW')
        }}
      </h3>
      <div class="grid gap-3 sm:grid-cols-3">
        <div class="sm:col-span-2">
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.EVENT_TYPES.FORM.NAME') }}
          </label>
          <input
            v-model="form.name"
            type="text"
            :placeholder="t('HUB.AGENDA.EVENT_TYPES.FORM.NAME_PLACEHOLDER')"
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
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
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.EVENT_TYPES.FORM.DURATION') }}
          </label>
          <input
            v-model.number="form.durationMinutes"
            type="number"
            min="1"
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          />
        </div>
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.EVENT_TYPES.FORM.BUFFER_BEFORE') }}
          </label>
          <input
            v-model.number="form.bufferBeforeMinutes"
            type="number"
            min="0"
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          />
        </div>
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.EVENT_TYPES.FORM.BUFFER_AFTER') }}
          </label>
          <input
            v-model.number="form.bufferAfterMinutes"
            type="number"
            min="0"
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          />
        </div>
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.EVENT_TYPES.FORM.MINIMUM_NOTICE') }}
          </label>
          <input
            v-model.number="form.minimumNoticeMinutes"
            type="number"
            min="0"
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          />
        </div>
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.EVENT_TYPES.FORM.SLOT_INTERVAL') }}
          </label>
          <input
            v-model.number="form.slotIntervalMinutes"
            type="number"
            min="1"
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          />
        </div>
        <div class="flex items-end">
          <label class="inline-flex items-center gap-2 text-sm text-n-slate-12">
            <input
              v-model="form.active"
              type="checkbox"
              class="rounded border-n-weak"
            />
            {{ t('HUB.AGENDA.EVENT_TYPES.FORM.ACTIVE') }}
          </label>
        </div>
      </div>
      <div class="mt-4 flex justify-end gap-2">
        <button
          type="button"
          class="h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 hover:bg-n-alpha-2"
          @click="closeForm"
        >
          {{ t('HUB.AGENDA.EVENT_TYPES.FORM.CANCEL') }}
        </button>
        <button
          type="button"
          class="h-8 px-3 rounded-lg text-sm font-medium bg-n-brand text-white hover:opacity-90 disabled:opacity-60"
          :disabled="isSaving || !form.name || !form.durationMinutes"
          @click="saveEventType"
        >
          {{
            isSaving
              ? t('HUB.AGENDA.EVENT_TYPES.FORM.SAVING')
              : t('HUB.AGENDA.EVENT_TYPES.FORM.SAVE')
          }}
        </button>
      </div>
    </div>

    <div v-if="uiFlags.isFetchingEventTypes" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.EVENT_TYPES.LOADING') }}
    </div>
    <div v-else-if="!eventTypes.length" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.EVENT_TYPES.EMPTY') }}
    </div>

    <div
      v-else
      class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 divide-y divide-n-weak"
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
        <button
          type="button"
          class="h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 border border-n-weak hover:bg-n-alpha-2"
          @click="openEditForm(eventType)"
        >
          {{ t('HUB.AGENDA.EVENT_TYPES.FORM.SAVE') }}
        </button>
        <button
          type="button"
          class="h-8 px-3 rounded-lg text-sm font-medium text-n-ruby-11 border border-n-weak hover:bg-n-alpha-2"
          @click="deleteEventType(eventType)"
        >
          {{ t('HUB.AGENDA.APPOINTMENTS.CANCEL') }}
        </button>
      </div>
    </div>
  </div>
</template>
