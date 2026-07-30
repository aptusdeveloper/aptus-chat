<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import AgendaTabs from './AgendaTabs.vue';

const store = useStore();
const { t } = useI18n();

const professionals = computed(() => store.getters['agenda/professionals']);
const uiFlags = computed(() => store.getters['agenda/uiFlags']);

const isFormOpen = ref(false);
const editingId = ref(null);
const isSaving = ref(false);
const expandedProfessionalId = ref(null);

const emptyForm = () => ({
  name: '',
  specialty: '',
  timezone: 'America/Sao_Paulo',
  active: true,
});
const form = reactive(emptyForm());

function openCreateForm() {
  editingId.value = null;
  Object.assign(form, emptyForm());
  isFormOpen.value = true;
}

function openEditForm(professional) {
  editingId.value = professional.id;
  Object.assign(form, {
    name: professional.name,
    specialty: professional.specialty || '',
    timezone: professional.timezone,
    active: professional.active,
  });
  isFormOpen.value = true;
}

function closeForm() {
  isFormOpen.value = false;
  editingId.value = null;
}

async function saveProfessional() {
  isSaving.value = true;
  try {
    if (editingId.value) {
      await store.dispatch('agenda/updateProfessional', {
        id: editingId.value,
        ...form,
      });
    } else {
      await store.dispatch('agenda/createProfessional', { ...form });
    }
    closeForm();
  } finally {
    isSaving.value = false;
  }
}

async function deleteProfessional(professional) {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('HUB.AGENDA.PROFESSIONALS.DELETE_CONFIRM'))) return;
  await store.dispatch('agenda/deleteProfessional', professional.id);
}

function toggleAvailability(professional) {
  const isOpening = expandedProfessionalId.value !== professional.id;
  expandedProfessionalId.value = isOpening ? professional.id : null;
  if (isOpening) {
    store.dispatch('agenda/fetchAvailabilities', professional.id);
  }
}

const DAY_KEYS = ['0', '1', '2', '3', '4', '5', '6'];

const emptyWeeklyBlock = () => ({
  dayOfWeek: '1',
  startHour: 8,
  startMinutes: 0,
  endHour: 12,
  endMinutes: 0,
});
const weeklyBlockForm = reactive(emptyWeeklyBlock());

const emptyOverride = () => ({
  date: '',
  unavailable: true,
  startHour: 8,
  startMinutes: 0,
  endHour: 12,
  endMinutes: 0,
});
const overrideForm = reactive(emptyOverride());

function availabilitiesFor(professionalId) {
  return store.getters['agenda/availabilitiesForProfessional'](professionalId);
}

function weeklyBlocksFor(professionalId) {
  return availabilitiesFor(professionalId)
    .filter(a => !a.date)
    .sort(
      (a, b) => a.day_of_week - b.day_of_week || a.start_hour - b.start_hour
    );
}

function overridesFor(professionalId) {
  return availabilitiesFor(professionalId).filter(a => a.date);
}

async function addWeeklyBlock(professionalId) {
  await store.dispatch('agenda/createAvailability', {
    professionalId,
    availabilityData: {
      day_of_week: Number(weeklyBlockForm.dayOfWeek),
      start_hour: Number(weeklyBlockForm.startHour),
      start_minutes: Number(weeklyBlockForm.startMinutes),
      end_hour: Number(weeklyBlockForm.endHour),
      end_minutes: Number(weeklyBlockForm.endMinutes),
      unavailable: false,
    },
  });
  Object.assign(weeklyBlockForm, emptyWeeklyBlock());
}

async function addOverride(professionalId) {
  await store.dispatch('agenda/createAvailability', {
    professionalId,
    availabilityData: {
      date: overrideForm.date,
      unavailable: overrideForm.unavailable,
      start_hour: overrideForm.unavailable
        ? null
        : Number(overrideForm.startHour),
      start_minutes: overrideForm.unavailable
        ? null
        : Number(overrideForm.startMinutes),
      end_hour: overrideForm.unavailable ? null : Number(overrideForm.endHour),
      end_minutes: overrideForm.unavailable
        ? null
        : Number(overrideForm.endMinutes),
    },
  });
  Object.assign(overrideForm, emptyOverride());
}

async function deleteAvailability(professionalId, availability) {
  // eslint-disable-next-line no-alert
  if (
    !window.confirm(t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.DELETE_CONFIRM'))
  )
    return;
  await store.dispatch('agenda/deleteAvailability', {
    professionalId,
    id: availability.id,
  });
}

function pad(value) {
  return String(value).padStart(2, '0');
}

onMounted(() => {
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
        {{ t('HUB.AGENDA.PROFESSIONALS.NEW') }}
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
            ? t('HUB.AGENDA.PROFESSIONALS.EDIT')
            : t('HUB.AGENDA.PROFESSIONALS.NEW')
        }}
      </h3>
      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.PROFESSIONALS.FORM.NAME') }}
          </label>
          <input
            v-model="form.name"
            type="text"
            :placeholder="t('HUB.AGENDA.PROFESSIONALS.FORM.NAME_PLACEHOLDER')"
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          />
        </div>
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.PROFESSIONALS.FORM.SPECIALTY') }}
          </label>
          <input
            v-model="form.specialty"
            type="text"
            :placeholder="
              t('HUB.AGENDA.PROFESSIONALS.FORM.SPECIALTY_PLACEHOLDER')
            "
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          />
        </div>
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.PROFESSIONALS.FORM.TIMEZONE') }}
          </label>
          <input
            v-model="form.timezone"
            type="text"
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
            {{ t('HUB.AGENDA.PROFESSIONALS.FORM.ACTIVE') }}
          </label>
        </div>
      </div>
      <div class="mt-4 flex justify-end gap-2">
        <button
          type="button"
          class="h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 hover:bg-n-alpha-2"
          @click="closeForm"
        >
          {{ t('HUB.AGENDA.PROFESSIONALS.FORM.CANCEL') }}
        </button>
        <button
          type="button"
          class="h-8 px-3 rounded-lg text-sm font-medium bg-n-brand text-white hover:opacity-90 disabled:opacity-60"
          :disabled="isSaving || !form.name"
          @click="saveProfessional"
        >
          {{
            isSaving
              ? t('HUB.AGENDA.PROFESSIONALS.FORM.SAVING')
              : t('HUB.AGENDA.PROFESSIONALS.FORM.SAVE')
          }}
        </button>
      </div>
    </div>

    <div v-if="uiFlags.isFetchingProfessionals" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.PROFESSIONALS.LOADING') }}
    </div>
    <div v-else-if="!professionals.length" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.PROFESSIONALS.EMPTY') }}
    </div>

    <div v-else class="flex flex-col gap-3">
      <div
        v-for="professional in professionals"
        :key="professional.id"
        class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2"
      >
        <div class="flex items-center gap-3 p-4">
          <div class="min-w-0 mr-auto">
            <p class="text-sm font-semibold text-n-slate-12 truncate">
              {{ professional.name }}
            </p>
            <p class="text-xs text-n-slate-9 truncate">
              {{ professional.specialty }} · {{ professional.timezone }}
            </p>
          </div>
          <span
            class="inline-flex items-center h-6 px-2 rounded-md text-xs font-medium"
            :class="
              professional.active
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-slate-3 text-n-slate-11'
            "
          >
            {{
              professional.active
                ? t('HUB.AGENDA.PROFESSIONALS.FORM.ACTIVE')
                : '—'
            }}
          </span>
          <button
            type="button"
            class="h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 border border-n-weak hover:bg-n-alpha-2"
            @click="toggleAvailability(professional)"
          >
            {{ t('HUB.AGENDA.PROFESSIONALS.MANAGE_AVAILABILITY') }}
          </button>
          <button
            type="button"
            class="h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 border border-n-weak hover:bg-n-alpha-2"
            @click="openEditForm(professional)"
          >
            {{ t('HUB.AGENDA.PROFESSIONALS.FORM.SAVE') }}
          </button>
          <button
            type="button"
            class="h-8 px-3 rounded-lg text-sm font-medium text-n-ruby-11 border border-n-weak hover:bg-n-alpha-2"
            @click="deleteProfessional(professional)"
          >
            {{ t('HUB.AGENDA.APPOINTMENTS.CANCEL') }}
          </button>
        </div>

        <div
          v-if="expandedProfessionalId === professional.id"
          class="border-t border-n-weak p-4"
        >
          <h4 class="text-sm font-semibold text-n-slate-12 mb-1">
            {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.TITLE') }}
          </h4>
          <p class="text-xs text-n-slate-9 mb-3">
            {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.SUBTITLE') }}
          </p>

          <div
            v-if="!weeklyBlocksFor(professional.id).length"
            class="text-xs text-n-slate-9 mb-2"
          >
            {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.EMPTY') }}
          </div>
          <ul class="mb-3 flex flex-col gap-1">
            <li
              v-for="availability in weeklyBlocksFor(professional.id)"
              :key="availability.id"
              class="flex items-center justify-between text-sm text-n-slate-12 bg-n-alpha-1 rounded-md px-3 py-1.5"
            >
              <span>
                {{
                  t(
                    `HUB.AGENDA.PROFESSIONALS.AVAILABILITY.DAYS.${availability.day_of_week}`
                  )
                }}
                · {{ pad(availability.start_hour) }}:{{
                  pad(availability.start_minutes)
                }}
                – {{ pad(availability.end_hour) }}:{{
                  pad(availability.end_minutes)
                }}
              </span>
              <button
                type="button"
                class="text-xs text-n-ruby-11 hover:underline"
                @click="deleteAvailability(professional.id, availability)"
              >
                {{ t('HUB.AGENDA.APPOINTMENTS.CANCEL') }}
              </button>
            </li>
          </ul>

          <div class="grid gap-2 sm:grid-cols-5 items-end mb-4">
            <div>
              <label class="block mb-1 text-xs font-medium text-n-slate-11">
                {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.DAY_OF_WEEK') }}
              </label>
              <select
                v-model="weeklyBlockForm.dayOfWeek"
                class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
              >
                <option v-for="day in DAY_KEYS" :key="day" :value="day">
                  {{ t(`HUB.AGENDA.PROFESSIONALS.AVAILABILITY.DAYS.${day}`) }}
                </option>
              </select>
            </div>
            <div>
              <label class="block mb-1 text-xs font-medium text-n-slate-11">
                {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.START') }}
              </label>
              <div class="flex gap-1">
                <input
                  v-model.number="weeklyBlockForm.startHour"
                  type="number"
                  min="0"
                  max="23"
                  class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                />
                <input
                  v-model.number="weeklyBlockForm.startMinutes"
                  type="number"
                  min="0"
                  max="59"
                  class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                />
              </div>
            </div>
            <div>
              <label class="block mb-1 text-xs font-medium text-n-slate-11">
                {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.END') }}
              </label>
              <div class="flex gap-1">
                <input
                  v-model.number="weeklyBlockForm.endHour"
                  type="number"
                  min="0"
                  max="23"
                  class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                />
                <input
                  v-model.number="weeklyBlockForm.endMinutes"
                  type="number"
                  min="0"
                  max="59"
                  class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                />
              </div>
            </div>
            <div class="sm:col-span-2">
              <button
                type="button"
                class="h-9 px-3 rounded-lg text-sm font-medium bg-n-brand text-white hover:opacity-90"
                @click="addWeeklyBlock(professional.id)"
              >
                {{
                  t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.ADD_WEEKLY_BLOCK')
                }}
              </button>
            </div>
          </div>

          <div v-if="overridesFor(professional.id).length" class="mb-3">
            <ul class="flex flex-col gap-1">
              <li
                v-for="availability in overridesFor(professional.id)"
                :key="availability.id"
                class="flex items-center justify-between text-sm text-n-slate-12 bg-n-alpha-1 rounded-md px-3 py-1.5"
              >
                <span>
                  {{ availability.date }}
                  <template v-if="availability.unavailable">
                    —
                    {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.UNAVAILABLE') }}
                  </template>
                  <template v-else>
                    · {{ pad(availability.start_hour) }}:{{
                      pad(availability.start_minutes)
                    }}
                    – {{ pad(availability.end_hour) }}:{{
                      pad(availability.end_minutes)
                    }}
                  </template>
                </span>
                <button
                  type="button"
                  class="text-xs text-n-ruby-11 hover:underline"
                  @click="deleteAvailability(professional.id, availability)"
                >
                  {{ t('HUB.AGENDA.APPOINTMENTS.CANCEL') }}
                </button>
              </li>
            </ul>
          </div>

          <div class="grid gap-2 sm:grid-cols-6 items-end">
            <div>
              <label class="block mb-1 text-xs font-medium text-n-slate-11">
                {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.DATE_OVERRIDE') }}
              </label>
              <input
                v-model="overrideForm.date"
                type="date"
                class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
              />
            </div>
            <div class="flex items-end">
              <label
                class="inline-flex items-center gap-2 text-xs text-n-slate-12"
              >
                <input
                  v-model="overrideForm.unavailable"
                  type="checkbox"
                  class="rounded border-n-weak"
                />
                {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.UNAVAILABLE') }}
              </label>
            </div>
            <template v-if="!overrideForm.unavailable">
              <div>
                <label class="block mb-1 text-xs font-medium text-n-slate-11">
                  {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.START') }}
                </label>
                <div class="flex gap-1">
                  <input
                    v-model.number="overrideForm.startHour"
                    type="number"
                    min="0"
                    max="23"
                    class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                  />
                  <input
                    v-model.number="overrideForm.startMinutes"
                    type="number"
                    min="0"
                    max="59"
                    class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                  />
                </div>
              </div>
              <div>
                <label class="block mb-1 text-xs font-medium text-n-slate-11">
                  {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.END') }}
                </label>
                <div class="flex gap-1">
                  <input
                    v-model.number="overrideForm.endHour"
                    type="number"
                    min="0"
                    max="23"
                    class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                  />
                  <input
                    v-model.number="overrideForm.endMinutes"
                    type="number"
                    min="0"
                    max="59"
                    class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
                  />
                </div>
              </div>
            </template>
            <div>
              <button
                type="button"
                class="h-9 px-3 rounded-lg text-sm font-medium bg-n-brand text-white hover:opacity-90"
                :disabled="!overrideForm.date"
                @click="addOverride(professional.id)"
              >
                {{
                  t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.ADD_DATE_OVERRIDE')
                }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
