import types from '../../mutation-types';

export const mutations = {
  [types.SET_AGENDA_UI_FLAG]($state, flags) {
    $state.uiFlags = { ...$state.uiFlags, ...flags };
  },

  [types.SET_AGENDA_PROFESSIONALS]($state, professionals) {
    $state.professionals = professionals;
  },

  [types.UPSERT_AGENDA_PROFESSIONAL]($state, professional) {
    const idx = $state.professionals.findIndex(p => p.id === professional.id);
    $state.professionals =
      idx !== -1
        ? $state.professionals.map(p =>
            p.id === professional.id ? professional : p
          )
        : [...$state.professionals, professional];
  },

  [types.DELETE_AGENDA_PROFESSIONAL]($state, professionalId) {
    $state.professionals = $state.professionals.filter(
      p => p.id !== professionalId
    );
  },

  [types.SET_AGENDA_EVENT_TYPES]($state, eventTypes) {
    $state.eventTypes = eventTypes;
  },

  [types.UPSERT_AGENDA_EVENT_TYPE]($state, eventType) {
    const idx = $state.eventTypes.findIndex(e => e.id === eventType.id);
    $state.eventTypes =
      idx !== -1
        ? $state.eventTypes.map(e => (e.id === eventType.id ? eventType : e))
        : [...$state.eventTypes, eventType];
  },

  [types.DELETE_AGENDA_EVENT_TYPE]($state, eventTypeId) {
    $state.eventTypes = $state.eventTypes.filter(e => e.id !== eventTypeId);
  },

  [types.SET_AGENDA_APPOINTMENTS]($state, appointments) {
    $state.appointments = appointments.reduce((acc, appointment) => {
      acc[appointment.id] = appointment;
      return acc;
    }, {});
  },

  [types.UPSERT_AGENDA_APPOINTMENT]($state, appointment) {
    $state.appointments = {
      ...$state.appointments,
      [appointment.id]: appointment,
    };
  },

  [types.SET_AGENDA_AVAILABILITIES](
    $state,
    { professionalId, availabilities }
  ) {
    $state.availabilitiesByProfessional = {
      ...$state.availabilitiesByProfessional,
      [professionalId]: availabilities,
    };
  },

  [types.UPSERT_AGENDA_AVAILABILITY]($state, { professionalId, availability }) {
    const current = $state.availabilitiesByProfessional[professionalId] || [];
    const idx = current.findIndex(a => a.id === availability.id);
    const updated =
      idx !== -1
        ? current.map(a => (a.id === availability.id ? availability : a))
        : [...current, availability];

    $state.availabilitiesByProfessional = {
      ...$state.availabilitiesByProfessional,
      [professionalId]: updated,
    };
  },

  [types.DELETE_AGENDA_AVAILABILITY](
    $state,
    { professionalId, availabilityId }
  ) {
    const current = $state.availabilitiesByProfessional[professionalId] || [];
    $state.availabilitiesByProfessional = {
      ...$state.availabilitiesByProfessional,
      [professionalId]: current.filter(a => a.id !== availabilityId),
    };
  },
};
