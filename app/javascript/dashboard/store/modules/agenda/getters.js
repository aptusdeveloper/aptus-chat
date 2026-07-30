export const getters = {
  professionals($state) {
    return $state.professionals;
  },

  eventTypes($state) {
    return $state.eventTypes;
  },

  eventTypesForProfessional($state) {
    return professionalId =>
      $state.eventTypes.filter(
        e =>
          !e.agenda_professional_id ||
          e.agenda_professional_id === professionalId
      );
  },

  allAppointments($state) {
    return Object.values($state.appointments);
  },

  availabilitiesForProfessional($state) {
    return professionalId =>
      $state.availabilitiesByProfessional[professionalId] || [];
  },

  uiFlags($state) {
    return $state.uiFlags;
  },
};
