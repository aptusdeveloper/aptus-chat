<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { ptBR } from 'date-fns/locale';
import {
  addDays,
  addMonths,
  addWeeks,
  differenceInMinutes,
  eachDayOfInterval,
  endOfDay,
  endOfMonth,
  endOfWeek,
  format,
  isSameDay,
  isSameMonth,
  isToday,
  parseISO,
  startOfDay,
  startOfMonth,
  startOfWeek,
  subDays,
  subMonths,
  subWeeks,
} from 'date-fns';
import { useAlert } from 'dashboard/composables';
import AgendaTabs from './AgendaTabs.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const store = useStore();
const { t } = useI18n();

const GRID_START_HOUR = 7;
const GRID_END_HOUR = 21;
const ROW_HEIGHT_PX = 56;
const PX_PER_MINUTE = ROW_HEIGHT_PX / 60;
const GRID_HEIGHT_PX = (GRID_END_HOUR - GRID_START_HOUR) * ROW_HEIGHT_PX;

const professionals = computed(() => store.getters['agenda/professionals']);
const eventTypes = computed(() => store.getters['agenda/eventTypes']);
const appointments = computed(() => store.getters['agenda/allAppointments']);
const uiFlags = computed(() => store.getters['agenda/uiFlags']);
const contacts = computed(() => store.getters['contacts/getContacts']);
const deals = computed(() => store.getters['crmDeals/allDeals']);
const activeProfessionals = computed(() =>
  professionals.value.filter(professional => professional.active !== false)
);

const viewMode = ref('week'); // 'day' | 'week' | 'month'
const anchorDate = ref(new Date());
const selectedProfessionalId = ref('');

function professionalName(id) {
  return professionals.value.find(p => p.id === id)?.name || '';
}
function professionalColor(id) {
  return professionals.value.find(p => p.id === id)?.color || '#64748B';
}

function hexToRgb(hex) {
  const clean = hex.replace('#', '');
  const full =
    clean.length === 3
      ? clean
          .split('')
          .map(c => c + c)
          .join('')
      : clean;
  return {
    r: parseInt(full.slice(0, 2), 16),
    g: parseInt(full.slice(2, 4), 16),
    b: parseInt(full.slice(4, 6), 16),
  };
}

function appointmentAccentColor(appointment) {
  return professionalColor(appointment.agenda_professional_id);
}

function appointmentTint(appointment, alpha = 0.14) {
  const { r, g, b } = hexToRgb(appointmentAccentColor(appointment));
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function eventTypeName(id) {
  return eventTypes.value.find(e => e.id === id)?.name || '';
}
function contactName(id) {
  return (
    contacts.value.find(contact => String(contact.id) === String(id))?.name ||
    ''
  );
}
function dealName(id) {
  return deals.value.find(deal => deal.id === id)?.name || '';
}
function contactLabel(contact) {
  return (
    contact.name ||
    contact.email ||
    contact.phone_number ||
    t('HUB.AGENDA.APPOINTMENTS.NO_CONTACT_NAME', { id: contact.id })
  );
}
function dealLabel(deal) {
  const contact =
    deal.contact || contacts.value.find(c => c.id === deal.contact_id);
  const contactSuffix = contact ? ` - ${contactLabel(contact)}` : '';
  return `${deal.name}${contactSuffix}`;
}
function appointmentContactLabel(appointment) {
  if (appointment.contact) return contactLabel(appointment.contact);
  return contactName(appointment.contact_id);
}
function appointmentDealLabel(appointment) {
  if (appointment.crm_deal) return dealLabel(appointment.crm_deal);
  return dealName(appointment.crm_deal_id);
}

const visibleRange = computed(() => {
  if (viewMode.value === 'day') {
    return {
      from: startOfDay(anchorDate.value),
      to: endOfDay(anchorDate.value),
    };
  }
  if (viewMode.value === 'week') {
    return {
      from: startOfWeek(anchorDate.value, { weekStartsOn: 1 }),
      to: endOfWeek(anchorDate.value, { weekStartsOn: 1 }),
    };
  }
  return {
    from: startOfWeek(startOfMonth(anchorDate.value), { weekStartsOn: 1 }),
    to: endOfWeek(endOfMonth(anchorDate.value), { weekStartsOn: 1 }),
  };
});

const visibleDays = computed(() => {
  if (viewMode.value === 'day') return [anchorDate.value];
  return eachDayOfInterval({
    start: visibleRange.value.from,
    end: visibleRange.value.to,
  });
});

const monthWeeks = computed(() => {
  if (viewMode.value !== 'month') return [];
  const days = visibleDays.value;
  const weeks = [];
  for (let i = 0; i < days.length; i += 7) weeks.push(days.slice(i, i + 7));
  return weeks;
});

function capitalizeFirst(value) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

const rangeLabel = computed(() => {
  if (viewMode.value === 'day') {
    return capitalizeFirst(
      format(anchorDate.value, "EEEE, d 'de' MMMM", { locale: ptBR })
    );
  }
  if (viewMode.value === 'week') {
    const { from, to } = visibleRange.value;
    const sameMonth = isSameMonth(from, to);
    const fromLabel = format(from, sameMonth ? 'd' : "d 'de' MMM", {
      locale: ptBR,
    });
    const toLabel = format(to, "d 'de' MMM", { locale: ptBR });
    return capitalizeFirst(`${fromLabel} – ${toLabel}`);
  }
  return capitalizeFirst(
    format(anchorDate.value, "MMMM 'de' yyyy", { locale: ptBR })
  );
});

function goToday() {
  anchorDate.value = new Date();
}
function goPrev() {
  if (viewMode.value === 'day') anchorDate.value = subDays(anchorDate.value, 1);
  else if (viewMode.value === 'week')
    anchorDate.value = subWeeks(anchorDate.value, 1);
  else anchorDate.value = subMonths(anchorDate.value, 1);
}
function goNext() {
  if (viewMode.value === 'day') anchorDate.value = addDays(anchorDate.value, 1);
  else if (viewMode.value === 'week')
    anchorDate.value = addWeeks(anchorDate.value, 1);
  else anchorDate.value = addMonths(anchorDate.value, 1);
}
function openDay(day) {
  anchorDate.value = day;
  viewMode.value = 'day';
}

function toDateTimeInputValue(date) {
  return format(date, "yyyy-MM-dd'T'HH:mm");
}

function defaultAppointmentDate(day = anchorDate.value) {
  const date = new Date(day);
  const now = new Date();
  if (isSameDay(date, now)) {
    date.setHours(now.getHours() + 1, 0, 0, 0);
    return date;
  }

  date.setHours(9, 0, 0, 0);
  return date;
}

function compatibleEventTypes(professionalId) {
  return eventTypes.value.filter(eventType => {
    if (eventType.active === false) return false;
    return (
      !eventType.agenda_professional_id ||
      eventType.agenda_professional_id === professionalId
    );
  });
}

function compatibleDeals(contactId) {
  if (!contactId) return deals.value;

  return deals.value.filter(
    deal => !deal.contact_id || String(deal.contact_id) === String(contactId)
  );
}

function canProfessionalAcceptAppointment(professionalId) {
  return compatibleEventTypes(professionalId).length > 0;
}

function defaultProfessionalId() {
  const selectedProfessional = activeProfessionals.value.find(
    professional =>
      professional.id === selectedProfessionalId.value &&
      canProfessionalAcceptAppointment(professional.id)
  );
  const firstCompatibleProfessional = activeProfessionals.value.find(
    professional => canProfessionalAcceptAppointment(professional.id)
  );

  return (
    selectedProfessional?.id ||
    firstCompatibleProfessional?.id ||
    activeProfessionals.value[0]?.id ||
    professionals.value[0]?.id ||
    ''
  );
}

// ----- Availability warning (shared between create and reschedule) -----
const availabilityWarningDialogRef = ref(null);
const pendingAvailabilityAction = ref(null);

function openAvailabilityWarning({ professionalId, startsAt, run }) {
  pendingAvailabilityAction.value = { professionalId, startsAt, run };
  availabilityWarningDialogRef.value?.open();
}

function closeAvailabilityWarning() {
  pendingAvailabilityAction.value = null;
  availabilityWarningDialogRef.value?.close();
}

async function confirmDespiteAvailability() {
  if (!pendingAvailabilityAction.value) return;
  const { run } = pendingAvailabilityAction.value;
  pendingAvailabilityAction.value = null;
  availabilityWarningDialogRef.value?.close();
  await run();
}

// ----- Create appointment dialog -----
const createDialogRef = ref(null);
const isCreating = ref(false);

const emptyCreateForm = () => {
  const professionalId = defaultProfessionalId();
  const eventTypeId = compatibleEventTypes(professionalId)[0]?.id || '';

  return {
    professionalId,
    eventTypeId,
    startsAt: toDateTimeInputValue(defaultAppointmentDate()),
    contactId: '',
    crmDealId: '',
    patientName: '',
    patientPhone: '',
    notes: '',
  };
};

const createForm = reactive(emptyCreateForm());

const eventTypesForCreate = computed(() =>
  compatibleEventTypes(createForm.professionalId)
);
const dealsForCreate = computed(() => compatibleDeals(createForm.contactId));

function contactSelectOptions(contactId) {
  return [
    { value: '', label: t('HUB.AGENDA.APPOINTMENTS.FORM.NO_LINK') },
    ...(contactId && !contacts.value.some(c => String(c.id) === contactId)
      ? [{ value: contactId, label: contactName(contactId) }]
      : []),
    ...contacts.value.map(contact => ({
      value: String(contact.id),
      label: contactLabel(contact),
    })),
  ];
}

function dealSelectOptions(dealsList) {
  return [
    { value: '', label: t('HUB.AGENDA.APPOINTMENTS.FORM.NO_LINK') },
    ...dealsList.map(deal => ({ value: deal.id, label: dealLabel(deal) })),
  ];
}

const professionalSelectOptions = computed(() =>
  activeProfessionals.value.map(professional => ({
    value: professional.id,
    label: professional.name,
  }))
);
const eventTypeSelectOptions = computed(() =>
  eventTypesForCreate.value.map(eventType => ({
    value: eventType.id,
    label: eventType.name,
  }))
);
const contactCreateSelectOptions = computed(() =>
  contactSelectOptions(createForm.contactId)
);
const dealCreateSelectOptions = computed(() =>
  dealSelectOptions(dealsForCreate.value)
);

const canCreateAppointment = computed(() =>
  activeProfessionals.value.some(professional =>
    canProfessionalAcceptAppointment(professional.id)
  )
);

const canSubmitCreateAppointment = computed(
  () =>
    !!createForm.professionalId &&
    !!createForm.eventTypeId &&
    !!createForm.startsAt
);

function openCreateDialog(day = anchorDate.value, explicitDate = null) {
  const nextForm = emptyCreateForm();
  nextForm.startsAt = toDateTimeInputValue(
    explicitDate || defaultAppointmentDate(day)
  );
  Object.assign(createForm, nextForm);
  createDialogRef.value?.open();
}

function openCreateDialogAtSlot(day, minutesFromMidnight) {
  const date = new Date(day);
  date.setHours(0, minutesFromMidnight, 0, 0);
  openCreateDialog(day, date);
}

watch(
  () => createForm.professionalId,
  () => {
    const selectedEventTypeIsCompatible = eventTypesForCreate.value.some(
      eventType => eventType.id === createForm.eventTypeId
    );

    if (!selectedEventTypeIsCompatible) {
      createForm.eventTypeId = eventTypesForCreate.value[0]?.id || '';
    }
  }
);

watch(
  () => createForm.contactId,
  () => {
    const selectedDealIsCompatible = dealsForCreate.value.some(
      deal => deal.id === createForm.crmDealId
    );

    if (!selectedDealIsCompatible) {
      createForm.crmDealId = '';
    }
  }
);

watch(
  () => createForm.crmDealId,
  dealId => {
    const deal = deals.value.find(item => item.id === dealId);
    if (deal?.contact_id && !createForm.contactId) {
      createForm.contactId = String(deal.contact_id);
    }
  }
);

const appointmentsByDay = computed(() => {
  const map = new Map();
  appointments.value
    .filter(appointment => appointment.status !== 'cancelled')
    .forEach(appointment => {
      const key = format(parseISO(appointment.starts_at), 'yyyy-MM-dd');
      const list = map.get(key) || [];
      list.push(appointment);
      map.set(key, list);
    });
  map.forEach(list =>
    list.sort((a, b) => new Date(a.starts_at) - new Date(b.starts_at))
  );
  return map;
});

function appointmentsFor(day) {
  return appointmentsByDay.value.get(format(day, 'yyyy-MM-dd')) || [];
}

function formatHourLabel(hour) {
  return `${String(hour).padStart(2, '0')}:00`;
}

const hourLabels = computed(() =>
  Array.from(
    { length: GRID_END_HOUR - GRID_START_HOUR },
    (_, i) => GRID_START_HOUR + i
  )
);

const SLOT_MINUTES = 30;

const gridSlots = computed(() => {
  const slots = [];
  for (
    let minutes = GRID_START_HOUR * 60;
    minutes < GRID_END_HOUR * 60;
    minutes += SLOT_MINUTES
  ) {
    slots.push(minutes);
  }
  return slots;
});

function slotTimeLabel(minutesFromMidnight) {
  const hours = Math.floor(minutesFromMidnight / 60);
  const minutes = minutesFromMidnight % 60;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

// ----- Business-hours shading (only meaningful with a single professional selected) -----
// Also reused to warn when creating an appointment outside a professional's availability.
function businessWindowsForProfessionalDay(professionalId, day) {
  if (!professionalId) return [];

  const dayKey = format(day, 'yyyy-MM-dd');
  const all =
    store.getters['agenda/availabilitiesForProfessional'](professionalId);
  const overrides = all.filter(a => a.date === dayKey);
  const source = overrides.length
    ? overrides
    : all.filter(a => !a.date && a.day_of_week === day.getDay());

  return source
    .filter(a => !a.unavailable)
    .map(a => ({
      start: a.start_hour * 60 + a.start_minutes,
      end: a.end_hour * 60 + a.end_minutes,
    }))
    .sort((a, b) => a.start - b.start);
}

function businessWindowsForDay(day) {
  return businessWindowsForProfessionalDay(selectedProfessionalId.value, day);
}

function closedRangesForDay(day) {
  if (!selectedProfessionalId.value) return [];

  const gridStart = GRID_START_HOUR * 60;
  const gridEnd = GRID_END_HOUR * 60;
  const windows = businessWindowsForDay(day)
    .map(w => ({
      start: Math.max(w.start, gridStart),
      end: Math.min(w.end, gridEnd),
    }))
    .filter(w => w.end > w.start);

  const closed = [];
  let cursor = gridStart;
  windows.forEach(w => {
    if (w.start > cursor) closed.push({ start: cursor, end: w.start });
    cursor = Math.max(cursor, w.end);
  });
  if (cursor < gridEnd) closed.push({ start: cursor, end: gridEnd });

  return closed.map(range => ({
    top: `${(range.start - gridStart) * PX_PER_MINUTE}px`,
    height: `${(range.end - range.start) * PX_PER_MINUTE}px`,
  }));
}

function isDayFullyClosed(day) {
  return (
    !!selectedProfessionalId.value && businessWindowsForDay(day).length === 0
  );
}

function appointmentFallsWithinAvailability(
  professionalId,
  startDate,
  durationMinutes
) {
  const windows = businessWindowsForProfessionalDay(professionalId, startDate);
  if (!windows.length) return false;

  const startMinutes = startDate.getHours() * 60 + startDate.getMinutes();
  const endMinutes = startMinutes + durationMinutes;
  return windows.some(w => startMinutes >= w.start && endMinutes <= w.end);
}

watch(
  selectedProfessionalId,
  professionalId => {
    if (professionalId) {
      store.dispatch('agenda/fetchAvailabilities', professionalId);
    }
  },
  { immediate: true }
);

function blockStyle(appointment) {
  const start = parseISO(appointment.starts_at);
  const end = parseISO(appointment.ends_at);
  const minutesFromGridStart =
    (start.getHours() - GRID_START_HOUR) * 60 + start.getMinutes();
  const durationMinutes = Math.max(differenceInMinutes(end, start), 15);
  return {
    top: `${Math.max(minutesFromGridStart, 0) * PX_PER_MINUTE}px`,
    height: `${durationMinutes * PX_PER_MINUTE}px`,
  };
}

function nowLinePosition(day) {
  if (!isToday(day)) return null;
  const now = new Date();
  const minutesFromGridStart =
    (now.getHours() - GRID_START_HOUR) * 60 + now.getMinutes();
  if (
    minutesFromGridStart < 0 ||
    minutesFromGridStart > GRID_HEIGHT_PX / PX_PER_MINUTE
  )
    return null;
  return minutesFromGridStart * PX_PER_MINUTE;
}

async function loadAppointments() {
  const { from, to } = visibleRange.value;
  await store.dispatch('agenda/fetchAppointments', {
    agenda_professional_id: selectedProfessionalId.value || undefined,
    date_from: format(startOfDay(from), "yyyy-MM-dd'T'HH:mm:ss"),
    date_to: format(endOfDay(to), "yyyy-MM-dd'T'HH:mm:ss"),
  });
}

function buildCreatePayload() {
  return {
    agenda_professional_id: createForm.professionalId,
    agenda_event_type_id: createForm.eventTypeId,
    starts_at: new Date(createForm.startsAt).toISOString(),
    source: 'staff',
    contact_id: createForm.contactId || undefined,
    crm_deal_id: createForm.crmDealId || undefined,
    patient_name: createForm.patientName || undefined,
    patient_phone: createForm.patientPhone || undefined,
    notes: createForm.notes || undefined,
  };
}

async function submitCreateAppointment(payload) {
  isCreating.value = true;
  try {
    await store.dispatch('agenda/createAppointment', payload);
    createDialogRef.value?.close();
    useAlert(t('HUB.AGENDA.APPOINTMENTS.CREATE_SUCCESS'));
    loadAppointments();
  } catch (error) {
    if (error?.response?.status === 422) {
      useAlert(t('HUB.AGENDA.APPOINTMENTS.CREATE_ERROR_CONFLICT'));
    } else {
      useAlert(t('HUB.AGENDA.APPOINTMENTS.CREATE_ERROR'));
    }
  } finally {
    isCreating.value = false;
  }
}

async function checkAvailabilityBeforeSubmit(
  professionalId,
  eventTypeId,
  startsAt
) {
  await store.dispatch('agenda/fetchAvailabilities', professionalId);
  const eventType = eventTypes.value.find(item => item.id === eventTypeId);
  if (!eventType) return true;

  return appointmentFallsWithinAvailability(
    professionalId,
    new Date(startsAt),
    eventType.duration_minutes
  );
}

async function createAppointment() {
  if (!canSubmitCreateAppointment.value) return;

  isCreating.value = true;
  const withinAvailability = await checkAvailabilityBeforeSubmit(
    createForm.professionalId,
    createForm.eventTypeId,
    createForm.startsAt
  );
  isCreating.value = false;

  const payload = buildCreatePayload();

  if (!withinAvailability) {
    openAvailabilityWarning({
      professionalId: createForm.professionalId,
      startsAt: createForm.startsAt,
      run: () => submitCreateAppointment(payload),
    });
    return;
  }

  await submitCreateAppointment(payload);
}

const availabilityWarningDescription = computed(() => {
  if (!pendingAvailabilityAction.value) return '';

  const { professionalId, startsAt } = pendingAvailabilityAction.value;
  const windows = businessWindowsForProfessionalDay(
    professionalId,
    new Date(startsAt)
  );
  if (!windows.length) {
    return t(
      'HUB.AGENDA.APPOINTMENTS.FORM.AVAILABILITY_WARNING.NO_AVAILABILITY_THIS_DAY'
    );
  }

  const hours = windows
    .map(w => `${slotTimeLabel(w.start)}–${slotTimeLabel(w.end)}`)
    .join(', ');
  return t(
    'HUB.AGENDA.APPOINTMENTS.FORM.AVAILABILITY_WARNING.AVAILABLE_HOURS',
    { hours }
  );
});

function viewModeLabel(mode) {
  const labels = {
    day: t('HUB.AGENDA.APPOINTMENTS.VIEW.DAY'),
    week: t('HUB.AGENDA.APPOINTMENTS.VIEW.WEEK'),
    month: t('HUB.AGENDA.APPOINTMENTS.VIEW.MONTH'),
  };

  return labels[mode] || mode;
}

function appointmentStatusLabel(status) {
  const labels = {
    confirmed: t('HUB.AGENDA.APPOINTMENTS.STATUS.confirmed'),
    cancelled: t('HUB.AGENDA.APPOINTMENTS.STATUS.cancelled'),
    completed: t('HUB.AGENDA.APPOINTMENTS.STATUS.completed'),
    no_show: t('HUB.AGENDA.APPOINTMENTS.STATUS.no_show'),
  };

  return labels[status] || status;
}

function appointmentSourceLabel(source) {
  const labels = {
    bot: t('HUB.AGENDA.APPOINTMENTS.SOURCE.bot'),
    staff: t('HUB.AGENDA.APPOINTMENTS.SOURCE.staff'),
  };

  return labels[source] || source;
}

function appointmentDetailMeta(appointment) {
  const start = parseISO(appointment.starts_at);
  const end = parseISO(appointment.ends_at);
  const day = format(start, "d 'de' MMMM", { locale: ptBR });

  return `${format(start, 'HH:mm')} - ${format(end, 'HH:mm')} - ${day}`;
}

watch([visibleRange, selectedProfessionalId], loadAppointments);

onMounted(() => {
  store.dispatch('agenda/fetchProfessionals');
  store.dispatch('agenda/fetchEventTypes');
  store.dispatch('contacts/get');
  store.dispatch('crmDeals/fetchDeals');
  loadAppointments();
});

// ----- Appointment detail popover: cancel / reschedule -----
const actionState = reactive({});

function stateFor(id) {
  if (!actionState[id]) {
    actionState[id] = {
      mode: null,
      reason: '',
      time: '',
      contactId: '',
      crmDealId: '',
    };
  }
  return actionState[id];
}

function resetAction(id) {
  if (actionState[id]) actionState[id].mode = null;
}

function startCancel(id) {
  const state = stateFor(id);
  state.mode = 'cancel';
  state.reason = '';
}

function startReschedule(id) {
  const state = stateFor(id);
  state.mode = 'reschedule';
  state.time = '';
}

function startEditLinks(appointment) {
  const state = stateFor(appointment.id);
  state.mode = 'links';
  state.contactId = appointment.contact_id
    ? String(appointment.contact_id)
    : '';
  state.crmDealId = appointment.crm_deal_id || '';
}

function dealsForLinkState(state) {
  return compatibleDeals(state.contactId);
}

function syncLinkStateFromDeal(state) {
  const deal = deals.value.find(item => item.id === state.crmDealId);
  if (deal?.contact_id && !state.contactId) {
    state.contactId = String(deal.contact_id);
  }
}

function syncLinkStateFromContact(state) {
  const selectedDealIsCompatible = dealsForLinkState(state).some(
    deal => deal.id === state.crmDealId
  );

  if (!selectedDealIsCompatible) {
    state.crmDealId = '';
  }
}

async function confirmCancel(appointment, hide) {
  const state = stateFor(appointment.id);
  await store.dispatch('agenda/cancelAppointment', {
    id: appointment.id,
    reason: state.reason,
  });
  state.mode = null;
  useAlert(t('HUB.AGENDA.APPOINTMENTS.CANCEL_SUCCESS'));
  hide();
}

async function submitReschedule(appointment, state, hide) {
  try {
    await store.dispatch('agenda/rescheduleAppointment', {
      id: appointment.id,
      startsAt: new Date(state.time).toISOString(),
    });
    state.mode = null;
    useAlert(t('HUB.AGENDA.APPOINTMENTS.RESCHEDULE_SUCCESS'));
    loadAppointments();
    hide();
  } catch (error) {
    if (error?.response?.status === 422) {
      useAlert(t('HUB.AGENDA.APPOINTMENTS.RESCHEDULE_ERROR_CONFLICT'));
    } else {
      useAlert(t('HUB.AGENDA.APPOINTMENTS.RESCHEDULE_ERROR'));
    }
  }
}

async function confirmReschedule(appointment, hide) {
  const state = stateFor(appointment.id);
  if (!state.time) return;

  const withinAvailability = await checkAvailabilityBeforeSubmit(
    appointment.agenda_professional_id,
    appointment.agenda_event_type_id,
    state.time
  );

  if (!withinAvailability) {
    openAvailabilityWarning({
      professionalId: appointment.agenda_professional_id,
      startsAt: state.time,
      run: () => submitReschedule(appointment, state, hide),
    });
    return;
  }

  await submitReschedule(appointment, state, hide);
}

async function confirmLinksUpdate(appointment) {
  const state = stateFor(appointment.id);

  try {
    await store.dispatch('agenda/updateAppointment', {
      id: appointment.id,
      contact_id: state.contactId || null,
      crm_deal_id: state.crmDealId || null,
    });
    state.mode = null;
    useAlert(t('HUB.AGENDA.APPOINTMENTS.LINKS_UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('HUB.AGENDA.APPOINTMENTS.LINKS_UPDATE_ERROR'));
  }
}
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4">
    <div class="mb-4 flex items-center justify-between gap-3">
      <div>
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('HUB.AGENDA.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-10">{{ t('HUB.AGENDA.SUBTITLE') }}</p>
      </div>
      <Button
        icon="i-lucide-plus"
        :label="t('HUB.AGENDA.APPOINTMENTS.NEW')"
        :disabled="!canCreateAppointment"
        @click="openCreateDialog()"
      />
    </div>

    <AgendaTabs />

    <div class="mb-4 flex flex-wrap items-center gap-3">
      <div class="inline-flex items-center gap-1">
        <button
          type="button"
          class="h-8 w-8 inline-flex items-center justify-center rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
          @click="goPrev"
        >
          <span class="i-lucide-chevron-left size-4" />
        </button>
        <Button
          slate
          outline
          sm
          :label="t('HUB.AGENDA.APPOINTMENTS.TODAY')"
          @click="goToday"
        />
        <button
          type="button"
          class="h-8 w-8 inline-flex items-center justify-center rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
          @click="goNext"
        >
          <span class="i-lucide-chevron-right size-4" />
        </button>
      </div>

      <span class="text-sm font-medium text-n-slate-12">
        {{ rangeLabel }}
      </span>

      <div
        class="inline-flex items-center gap-1 rounded-lg border border-n-weak bg-n-solid-1 p-1"
      >
        <button
          v-for="mode in ['day', 'week', 'month']"
          :key="mode"
          type="button"
          class="h-8 px-3 rounded-md text-sm font-medium transition-colors"
          :class="
            viewMode === mode
              ? 'bg-n-solid-3 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'
          "
          @click="viewMode = mode"
        >
          {{ viewModeLabel(mode) }}
        </button>
      </div>

      <div
        class="ml-auto inline-flex flex-wrap items-center gap-1 rounded-lg border border-n-weak bg-n-solid-1 p-1"
        role="group"
        :aria-label="t('HUB.AGENDA.APPOINTMENTS.FILTERS.PROFESSIONAL')"
      >
        <button
          type="button"
          class="h-8 px-3 rounded-md text-sm font-medium transition-colors"
          :class="
            !selectedProfessionalId
              ? 'bg-n-solid-3 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'
          "
          @click="selectedProfessionalId = ''"
        >
          {{ t('HUB.AGENDA.APPOINTMENTS.FILTERS.ALL_PROFESSIONALS') }}
        </button>
        <button
          v-for="professional in professionals"
          :key="professional.id"
          type="button"
          class="h-8 pl-2 pr-3 inline-flex items-center gap-1.5 rounded-md text-sm font-medium transition-colors"
          :class="
            selectedProfessionalId === professional.id
              ? 'bg-n-solid-3 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'
          "
          @click="selectedProfessionalId = professional.id"
        >
          <span
            class="size-2.5 rounded-full shrink-0"
            :style="{ backgroundColor: professional.color || '#64748B' }"
          />
          {{ professional.name }}
        </button>
      </div>
    </div>

    <div class="relative">
      <div
        v-if="uiFlags.isFetchingAppointments"
        class="absolute inset-0 z-40 flex items-center justify-center gap-2 rounded-lg bg-n-solid-1/70 backdrop-blur-sm"
      >
        <Spinner :size="20" />
        <span class="text-sm text-n-slate-10">
          {{ t('HUB.AGENDA.APPOINTMENTS.LOADING') }}
        </span>
      </div>

      <!-- Month view -->
      <div
        v-if="viewMode === 'month'"
        class="rounded-lg border border-n-weak overflow-hidden"
      >
        <div class="grid grid-cols-7 bg-n-solid-1">
          <div
            v-for="day in visibleDays.slice(0, 7)"
            :key="day.toISOString()"
            class="px-2 py-1.5 text-xs font-medium text-n-slate-9 text-center capitalize"
          >
            {{ format(day, 'EEEEEE', { locale: ptBR }) }}
          </div>
        </div>
        <div
          v-for="(week, weekIndex) in monthWeeks"
          :key="weekIndex"
          class="grid grid-cols-7 border-t border-n-weak"
        >
          <button
            v-for="day in week"
            :key="day.toISOString()"
            type="button"
            class="min-h-24 p-1.5 text-left border-r border-n-weak last:border-r-0 hover:bg-n-alpha-1 align-top"
            :class="[
              !isSameMonth(day, anchorDate) && 'bg-n-alpha-1 opacity-50',
              isSameMonth(day, anchorDate) &&
                isDayFullyClosed(day) &&
                'bg-n-slate-3 dark:bg-n-solid-2',
            ]"
            @click="openDay(day)"
          >
            <span
              class="inline-flex items-center justify-center size-6 rounded-full text-xs font-medium"
              :class="
                isToday(day) ? 'bg-n-brand text-white' : 'text-n-slate-11'
              "
            >
              {{ format(day, 'd') }}
            </span>
            <span
              v-if="isSameMonth(day, anchorDate) && isDayFullyClosed(day)"
              class="block text-[10px] text-n-slate-9"
            >
              {{ t('HUB.AGENDA.APPOINTMENTS.DAY_UNAVAILABLE') }}
            </span>
            <div class="mt-1 flex flex-col gap-0.5">
              <span
                v-for="appointment in appointmentsFor(day).slice(0, 3)"
                :key="appointment.id"
                class="flex items-center gap-1 truncate rounded text-[11px] border-l-2 px-1 py-0.5 text-n-slate-12"
                :style="{
                  borderColor: appointmentAccentColor(appointment),
                  backgroundColor: appointmentTint(appointment),
                }"
              >
                {{ format(parseISO(appointment.starts_at), 'HH:mm') }}
                {{ appointment.patient_name }}
              </span>
              <span
                v-if="appointmentsFor(day).length > 3"
                class="text-[11px] text-n-slate-9 px-1"
              >
                {{
                  t('HUB.AGENDA.APPOINTMENTS.MORE_COUNT', {
                    count: appointmentsFor(day).length - 3,
                  })
                }}
              </span>
            </div>
          </button>
        </div>
      </div>

      <!-- Day / Week grid view -->
      <div v-else class="rounded-lg border border-n-weak overflow-x-auto">
        <div :style="{ minWidth: viewMode === 'week' ? '840px' : '320px' }">
          <div
            class="grid border-b border-n-weak"
            :style="{
              gridTemplateColumns: `56px repeat(${visibleDays.length}, 1fr)`,
            }"
          >
            <div />
            <div
              v-for="day in visibleDays"
              :key="day.toISOString()"
              class="px-2 py-2 text-center border-l border-n-weak"
              :class="isToday(day) && 'bg-n-solid-1'"
            >
              <p class="text-xs text-n-slate-9 capitalize">
                {{ format(day, 'EEE', { locale: ptBR }) }}
              </p>
              <p
                class="text-sm font-semibold"
                :class="isToday(day) ? 'text-n-brand' : 'text-n-slate-12'"
              >
                {{ format(day, 'd') }}
              </p>
            </div>
          </div>

          <div
            class="grid"
            :style="{
              gridTemplateColumns: `56px repeat(${visibleDays.length}, 1fr)`,
            }"
          >
            <div class="relative" :style="{ height: `${GRID_HEIGHT_PX}px` }">
              <span
                v-for="hour in hourLabels"
                :key="hour"
                class="absolute right-2 -translate-y-1/2 text-[11px] text-n-slate-9"
                :style="{
                  top: `${(hour - GRID_START_HOUR) * ROW_HEIGHT_PX}px`,
                }"
              >
                {{ formatHourLabel(hour) }}
              </span>
            </div>

            <div
              v-for="day in visibleDays"
              :key="day.toISOString()"
              class="relative border-l border-n-weak"
              :class="isToday(day) && 'bg-n-solid-1/40'"
              :style="{ height: `${GRID_HEIGHT_PX}px` }"
            >
              <div
                v-for="(range, rangeIndex) in closedRangesForDay(day)"
                :key="`closed-${rangeIndex}`"
                class="absolute inset-x-0 bg-n-slate-5 dark:bg-n-solid-3 pointer-events-none"
                :style="{ top: range.top, height: range.height }"
              />
              <p
                v-if="isDayFullyClosed(day)"
                class="absolute inset-x-0 top-2 flex items-center justify-center text-[11px] text-n-slate-9 pointer-events-none"
              >
                {{ t('HUB.AGENDA.APPOINTMENTS.DAY_UNAVAILABLE') }}
              </p>

              <div
                v-for="hour in hourLabels"
                :key="hour"
                class="absolute inset-x-0 border-t border-n-weak/40 pointer-events-none"
                :style="{
                  top: `${(hour - GRID_START_HOUR) * ROW_HEIGHT_PX}px`,
                }"
              />

              <button
                v-for="slotMinutes in gridSlots"
                :key="slotMinutes"
                type="button"
                class="absolute inset-x-0 z-10 cursor-pointer hover:bg-n-alpha-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand focus-visible:-outline-offset-2"
                :style="{
                  top: `${(slotMinutes - GRID_START_HOUR * 60) * PX_PER_MINUTE}px`,
                  height: `${SLOT_MINUTES * PX_PER_MINUTE}px`,
                }"
                :aria-label="
                  t('HUB.AGENDA.APPOINTMENTS.CREATE_AT_SLOT', {
                    time: slotTimeLabel(slotMinutes),
                  })
                "
                @click="openCreateDialogAtSlot(day, slotMinutes)"
              />

              <div
                v-if="nowLinePosition(day) !== null"
                class="absolute inset-x-0 z-20 border-t-2 border-n-ruby-9 pointer-events-none"
                :style="{ top: `${nowLinePosition(day)}px` }"
              >
                <span
                  class="absolute -left-1 -top-1 size-2 rounded-full bg-n-ruby-9"
                />
              </div>

              <Popover
                v-for="appointment in appointmentsFor(day)"
                :key="appointment.id"
                align="start"
                @hide="resetAction(appointment.id)"
              >
                <div
                  class="absolute inset-x-0.5 z-30 min-h-5 flex items-center rounded-md border-l-[3px] px-1.5 py-0.5 text-left text-[11px] leading-tight overflow-hidden cursor-pointer shadow-sm ring-1 ring-black/5 transition-shadow hover:shadow-md"
                  :style="{
                    ...blockStyle(appointment),
                    borderColor: appointmentAccentColor(appointment),
                    backgroundColor: appointmentTint(appointment),
                  }"
                >
                  <p class="w-full truncate text-n-slate-12">
                    <span class="font-medium">
                      {{ format(parseISO(appointment.starts_at), 'HH:mm') }}
                    </span>
                    {{
                      appointment.patient_name ||
                      t('HUB.AGENDA.APPOINTMENTS.NO_PATIENT_NAME')
                    }}
                  </p>
                </div>

                <template #content="{ hide }">
                  <div class="p-4 w-72 flex flex-col gap-3">
                    <div class="flex items-start justify-between gap-2">
                      <div>
                        <p class="text-sm font-semibold text-n-slate-12">
                          {{
                            appointment.patient_name ||
                            t('HUB.AGENDA.APPOINTMENTS.NO_PATIENT_NAME')
                          }}
                        </p>
                        <p class="text-xs text-n-slate-9">
                          {{ appointmentDetailMeta(appointment) }}
                        </p>
                      </div>
                      <span
                        class="inline-flex items-center h-5 px-2 rounded-md text-[11px] font-medium shrink-0"
                        :class="
                          appointment.status === 'confirmed'
                            ? 'bg-n-teal-3 text-n-teal-11'
                            : 'bg-n-slate-3 text-n-slate-11'
                        "
                      >
                        {{ appointmentStatusLabel(appointment.status) }}
                      </span>
                    </div>

                    <div class="text-xs text-n-slate-10 flex flex-col gap-0.5">
                      <span>
                        {{
                          professionalName(appointment.agenda_professional_id)
                        }}
                      </span>
                      <span
                        v-if="eventTypeName(appointment.agenda_event_type_id)"
                      >
                        {{ eventTypeName(appointment.agenda_event_type_id) }}
                      </span>
                      <span>
                        {{ appointmentSourceLabel(appointment.source) }}
                      </span>
                      <span v-if="appointmentContactLabel(appointment)">
                        {{
                          t('HUB.AGENDA.APPOINTMENTS.LINKED_CONTACT', {
                            contact: appointmentContactLabel(appointment),
                          })
                        }}
                      </span>
                      <span v-if="appointmentDealLabel(appointment)">
                        {{
                          t('HUB.AGENDA.APPOINTMENTS.LINKED_DEAL', {
                            deal: appointmentDealLabel(appointment),
                          })
                        }}
                      </span>
                    </div>

                    <div
                      v-if="stateFor(appointment.id).mode === null"
                      class="flex flex-col gap-2"
                    >
                      <Button
                        slate
                        outline
                        sm
                        :label="t('HUB.AGENDA.APPOINTMENTS.EDIT_LINKS')"
                        @click="startEditLinks(appointment)"
                      />
                      <div
                        v-if="appointment.status === 'confirmed'"
                        class="flex items-center gap-2"
                      >
                        <Button
                          slate
                          outline
                          sm
                          class="flex-1"
                          :label="t('HUB.AGENDA.APPOINTMENTS.RESCHEDULE')"
                          @click="startReschedule(appointment.id)"
                        />
                        <Button
                          ruby
                          outline
                          sm
                          class="flex-1"
                          :label="t('HUB.AGENDA.APPOINTMENTS.CANCEL')"
                          @click="startCancel(appointment.id)"
                        />
                      </div>
                    </div>

                    <div
                      v-else-if="stateFor(appointment.id).mode === 'links'"
                      class="flex flex-col gap-2"
                    >
                      <div>
                        <label
                          class="block mb-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('HUB.AGENDA.APPOINTMENTS.FORM.CONTACT') }}
                        </label>
                        <Select
                          v-model="stateFor(appointment.id).contactId"
                          :options="
                            contactSelectOptions(
                              stateFor(appointment.id).contactId
                            )
                          "
                          @update:model-value="
                            syncLinkStateFromContact(stateFor(appointment.id))
                          "
                        />
                      </div>
                      <div>
                        <label
                          class="block mb-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('HUB.AGENDA.APPOINTMENTS.FORM.DEAL') }}
                        </label>
                        <Select
                          v-model="stateFor(appointment.id).crmDealId"
                          :options="
                            dealSelectOptions(
                              dealsForLinkState(stateFor(appointment.id))
                            )
                          "
                          @update:model-value="
                            syncLinkStateFromDeal(stateFor(appointment.id))
                          "
                        />
                      </div>
                      <div class="flex items-center gap-2">
                        <Button
                          sm
                          class="flex-1"
                          :label="t('HUB.AGENDA.APPOINTMENTS.CONFIRM')"
                          @click="confirmLinksUpdate(appointment)"
                        />
                        <Button
                          slate
                          ghost
                          sm
                          :label="t('HUB.AGENDA.APPOINTMENTS.CLOSE')"
                          @click="stateFor(appointment.id).mode = null"
                        />
                      </div>
                    </div>

                    <div
                      v-else-if="stateFor(appointment.id).mode === 'cancel'"
                      class="flex flex-col gap-2"
                    >
                      <Input
                        v-model="stateFor(appointment.id).reason"
                        size="sm"
                        :placeholder="
                          t('HUB.AGENDA.APPOINTMENTS.CANCEL_REASON_PLACEHOLDER')
                        "
                      />
                      <div class="flex items-center gap-2">
                        <Button
                          ruby
                          sm
                          class="flex-1"
                          :label="t('HUB.AGENDA.APPOINTMENTS.CONFIRM')"
                          @click="confirmCancel(appointment, hide)"
                        />
                        <Button
                          slate
                          ghost
                          sm
                          :label="t('HUB.AGENDA.APPOINTMENTS.CLOSE')"
                          @click="stateFor(appointment.id).mode = null"
                        />
                      </div>
                    </div>

                    <div v-else class="flex flex-col gap-2">
                      <Input
                        v-model="stateFor(appointment.id).time"
                        type="datetime-local"
                        size="sm"
                      />
                      <div class="flex items-center gap-2">
                        <Button
                          sm
                          class="flex-1"
                          :label="t('HUB.AGENDA.APPOINTMENTS.CONFIRM')"
                          @click="confirmReschedule(appointment, hide)"
                        />
                        <Button
                          slate
                          ghost
                          sm
                          :label="t('HUB.AGENDA.APPOINTMENTS.CLOSE')"
                          @click="stateFor(appointment.id).mode = null"
                        />
                      </div>
                    </div>
                  </div>
                </template>
              </Popover>
            </div>
          </div>
        </div>
      </div>

      <div
        v-if="
          !uiFlags.isFetchingAppointments &&
          viewMode !== 'month' &&
          !appointments.length
        "
        class="pointer-events-none absolute inset-0 flex flex-col items-center justify-center gap-3 px-4 text-center"
      >
        <span class="i-lucide-calendar-plus size-8 text-n-slate-8" />
        <p class="text-sm text-n-slate-10 max-w-xs">
          {{ t('HUB.AGENDA.APPOINTMENTS.EMPTY') }}
        </p>
      </div>
    </div>

    <Dialog
      ref="createDialogRef"
      width="xl"
      :title="t('HUB.AGENDA.APPOINTMENTS.NEW')"
      :description="
        !canCreateAppointment
          ? t('HUB.AGENDA.APPOINTMENTS.FORM.MISSING_SETUP')
          : ''
      "
      :is-loading="isCreating"
      :disable-confirm-button="!canSubmitCreateAppointment"
      :confirm-button-label="t('HUB.AGENDA.APPOINTMENTS.FORM.SAVE')"
      @confirm="createAppointment"
    >
      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.APPOINTMENTS.FORM.PROFESSIONAL') }}
          </label>
          <Select
            v-model="createForm.professionalId"
            :options="professionalSelectOptions"
          />
        </div>
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.APPOINTMENTS.FORM.EVENT_TYPE') }}
          </label>
          <Select
            v-model="createForm.eventTypeId"
            :options="eventTypeSelectOptions"
          />
        </div>
        <Input
          v-model="createForm.startsAt"
          type="datetime-local"
          :label="t('HUB.AGENDA.APPOINTMENTS.FORM.STARTS_AT')"
        />
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.APPOINTMENTS.FORM.CONTACT') }}
          </label>
          <Select
            v-model="createForm.contactId"
            :options="contactCreateSelectOptions"
          />
        </div>
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.APPOINTMENTS.FORM.DEAL') }}
          </label>
          <Select
            v-model="createForm.crmDealId"
            :options="dealCreateSelectOptions"
          />
        </div>
        <Input
          v-model="createForm.patientPhone"
          :label="t('HUB.AGENDA.APPOINTMENTS.FORM.PATIENT_PHONE')"
          :placeholder="
            t('HUB.AGENDA.APPOINTMENTS.FORM.PATIENT_PHONE_PLACEHOLDER')
          "
        />
        <div class="sm:col-span-2">
          <Input
            v-model="createForm.patientName"
            :label="t('HUB.AGENDA.APPOINTMENTS.FORM.PATIENT_NAME')"
            :placeholder="
              t('HUB.AGENDA.APPOINTMENTS.FORM.PATIENT_NAME_PLACEHOLDER')
            "
          />
        </div>
        <div class="sm:col-span-2">
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.APPOINTMENTS.FORM.NOTES') }}
          </label>
          <textarea
            v-model="createForm.notes"
            rows="3"
            class="block w-full reset-base text-sm !mb-0 outline outline-1 border-none border-0 outline-offset-[-1px] rounded-lg bg-n-alpha-black2 placeholder:text-n-slate-10 disabled:cursor-not-allowed disabled:opacity-50 text-n-slate-12 transition-all duration-500 ease-in-out outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand px-3 py-2.5 resize-none"
            :placeholder="t('HUB.AGENDA.APPOINTMENTS.FORM.NOTES_PLACEHOLDER')"
          />
        </div>
      </div>
    </Dialog>

    <Dialog
      ref="availabilityWarningDialogRef"
      width="sm"
      type="alert"
      :title="
        t('HUB.AGENDA.APPOINTMENTS.FORM.AVAILABILITY_WARNING.TITLE', {
          professional: professionalName(
            pendingAvailabilityAction?.professionalId
          ),
        })
      "
      :description="availabilityWarningDescription"
      :cancel-button-label="
        t('HUB.AGENDA.APPOINTMENTS.FORM.AVAILABILITY_WARNING.CHANGE_TIME')
      "
      :confirm-button-label="
        t('HUB.AGENDA.APPOINTMENTS.FORM.AVAILABILITY_WARNING.CONFIRM_ANYWAY')
      "
      @confirm="confirmDespiteAvailability"
      @close="closeAvailabilityWarning"
    />
  </div>
</template>
