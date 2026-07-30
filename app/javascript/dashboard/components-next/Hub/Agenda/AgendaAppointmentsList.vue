<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import AgendaTabs from './AgendaTabs.vue';

const store = useStore();
const { t } = useI18n();

const professionals = computed(() => store.getters['agenda/professionals']);
const appointments = computed(() => store.getters['agenda/allAppointments']);
const uiFlags = computed(() => store.getters['agenda/uiFlags']);

function defaultRange() {
  const from = new Date();
  const to = new Date();
  to.setDate(to.getDate() + 14);
  return {
    from: from.toISOString().slice(0, 10),
    to: to.toISOString().slice(0, 10),
  };
}

const filters = reactive({ professionalId: '', ...defaultRange() });

const sortedAppointments = computed(() =>
  [...appointments.value].sort(
    (a, b) => new Date(a.starts_at) - new Date(b.starts_at)
  )
);

function professionalName(id) {
  return professionals.value.find(p => p.id === id)?.name || id;
}

function formatDateTime(value) {
  return new Date(value).toLocaleString();
}

async function loadAppointments() {
  await store.dispatch('agenda/fetchAppointments', {
    agenda_professional_id: filters.professionalId || undefined,
    date_from: filters.from ? `${filters.from}T00:00:00` : undefined,
    date_to: filters.to ? `${filters.to}T23:59:59` : undefined,
  });
}

const cancellingId = ref(null);
const cancelReason = ref('');

function startCancel(appointment) {
  cancellingId.value = appointment.id;
  cancelReason.value = '';
}

async function confirmCancel(appointment) {
  await store.dispatch('agenda/cancelAppointment', {
    id: appointment.id,
    reason: cancelReason.value,
  });
  cancellingId.value = null;
}

const reschedulingId = ref(null);
const rescheduleTime = ref('');

function startReschedule(appointment) {
  reschedulingId.value = appointment.id;
  rescheduleTime.value = '';
}

async function confirmReschedule(appointment) {
  if (!rescheduleTime.value) return;
  await store.dispatch('agenda/rescheduleAppointment', {
    id: appointment.id,
    startsAt: new Date(rescheduleTime.value).toISOString(),
  });
  reschedulingId.value = null;
  loadAppointments();
}

watch(
  () => [filters.professionalId, filters.from, filters.to],
  loadAppointments
);

onMounted(() => {
  store.dispatch('agenda/fetchProfessionals');
  loadAppointments();
});
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4">
    <div class="mb-4">
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ t('HUB.AGENDA.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-10">{{ t('HUB.AGENDA.SUBTITLE') }}</p>
    </div>

    <AgendaTabs />

    <div class="mb-4 flex flex-wrap items-end gap-3">
      <div>
        <label class="block mb-1 text-xs font-medium text-n-slate-11">
          {{ t('HUB.AGENDA.APPOINTMENTS.FILTERS.PROFESSIONAL') }}
        </label>
        <select
          v-model="filters.professionalId"
          class="h-9 rounded-lg border border-n-weak bg-n-background px-2 text-sm text-n-slate-12"
        >
          <option value="">
            {{ t('HUB.AGENDA.APPOINTMENTS.FILTERS.ALL_PROFESSIONALS') }}
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
          {{ t('HUB.AGENDA.APPOINTMENTS.FILTERS.FROM') }}
        </label>
        <input
          v-model="filters.from"
          type="date"
          class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
        />
      </div>
      <div>
        <label class="block mb-1 text-xs font-medium text-n-slate-11">
          {{ t('HUB.AGENDA.APPOINTMENTS.FILTERS.TO') }}
        </label>
        <input
          v-model="filters.to"
          type="date"
          class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
        />
      </div>
    </div>

    <div v-if="uiFlags.isFetchingAppointments" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.APPOINTMENTS.LOADING') }}
    </div>
    <div v-else-if="!sortedAppointments.length" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.APPOINTMENTS.EMPTY') }}
    </div>

    <div
      v-else
      class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 divide-y divide-n-weak"
    >
      <div
        v-for="appointment in sortedAppointments"
        :key="appointment.id"
        class="p-4"
      >
        <div class="flex flex-wrap items-center gap-3">
          <div class="min-w-0 mr-auto">
            <p class="text-sm font-medium text-n-slate-12">
              {{ formatDateTime(appointment.starts_at) }}
            </p>
            <p class="text-xs text-n-slate-9 truncate">
              {{ professionalName(appointment.agenda_professional_id) }}
              <template v-if="appointment.patient_name">
                · {{ appointment.patient_name }}
              </template>
            </p>
          </div>
          <span
            class="inline-flex items-center h-6 px-2 rounded-md text-xs font-medium"
            :class="
              appointment.status === 'confirmed'
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-slate-3 text-n-slate-11'
            "
          >
            {{ t(`HUB.AGENDA.APPOINTMENTS.STATUS.${appointment.status}`) }}
          </span>
          <span
            class="inline-flex items-center h-6 px-2 rounded-md text-xs font-medium bg-n-alpha-2 text-n-slate-11"
          >
            {{ t(`HUB.AGENDA.APPOINTMENTS.SOURCE.${appointment.source}`) }}
          </span>
          <template v-if="appointment.status === 'confirmed'">
            <button
              type="button"
              class="h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 border border-n-weak hover:bg-n-alpha-2"
              @click="startReschedule(appointment)"
            >
              {{ t('HUB.AGENDA.APPOINTMENTS.RESCHEDULE') }}
            </button>
            <button
              type="button"
              class="h-8 px-3 rounded-lg text-sm font-medium text-n-ruby-11 border border-n-weak hover:bg-n-alpha-2"
              @click="startCancel(appointment)"
            >
              {{ t('HUB.AGENDA.APPOINTMENTS.CANCEL') }}
            </button>
          </template>
        </div>

        <div
          v-if="cancellingId === appointment.id"
          class="mt-3 flex items-center gap-2"
        >
          <input
            v-model="cancelReason"
            type="text"
            :placeholder="
              t('HUB.AGENDA.APPOINTMENTS.CANCEL_REASON_PLACEHOLDER')
            "
            class="flex-1 h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          />
          <button
            type="button"
            class="h-8 px-3 rounded-lg text-sm font-medium bg-n-ruby-9 text-white hover:opacity-90"
            @click="confirmCancel(appointment)"
          >
            {{ t('HUB.AGENDA.APPOINTMENTS.CONFIRM') }}
          </button>
          <button
            type="button"
            class="h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 hover:bg-n-alpha-2"
            @click="cancellingId = null"
          >
            {{ t('HUB.AGENDA.APPOINTMENTS.CLOSE') }}
          </button>
        </div>

        <div
          v-if="reschedulingId === appointment.id"
          class="mt-3 flex items-center gap-2"
        >
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.APPOINTMENTS.RESCHEDULE_NEW_TIME') }}
          </label>
          <input
            v-model="rescheduleTime"
            type="datetime-local"
            class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
          />
          <button
            type="button"
            class="h-8 px-3 rounded-lg text-sm font-medium bg-n-brand text-white hover:opacity-90"
            @click="confirmReschedule(appointment)"
          >
            {{ t('HUB.AGENDA.APPOINTMENTS.CONFIRM') }}
          </button>
          <button
            type="button"
            class="h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 hover:bg-n-alpha-2"
            @click="reschedulingId = null"
          >
            {{ t('HUB.AGENDA.APPOINTMENTS.CLOSE') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
