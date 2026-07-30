import ProfessionalsAPI from 'dashboard/api/agenda/professionals';
import EventTypesAPI from 'dashboard/api/agenda/eventTypes';
import AppointmentsAPI from 'dashboard/api/agenda/appointments';
import AvailabilitiesAPI from 'dashboard/api/agenda/availabilities';
import types from '../../mutation-types';

export const actions = {
  fetchProfessionals: async ({ commit }) => {
    commit(types.SET_AGENDA_UI_FLAG, { isFetchingProfessionals: true });
    try {
      const { data } = await ProfessionalsAPI.get();
      commit(types.SET_AGENDA_PROFESSIONALS, data.payload);
    } finally {
      commit(types.SET_AGENDA_UI_FLAG, { isFetchingProfessionals: false });
    }
  },

  createProfessional: async ({ commit }, professionalData) => {
    const { data } = await ProfessionalsAPI.create({
      agenda_professional: professionalData,
    });
    commit(types.UPSERT_AGENDA_PROFESSIONAL, data.payload);
    return data.payload;
  },

  updateProfessional: async ({ commit }, { id, ...professionalData }) => {
    const { data } = await ProfessionalsAPI.update(id, {
      agenda_professional: professionalData,
    });
    commit(types.UPSERT_AGENDA_PROFESSIONAL, data.payload);
    return data.payload;
  },

  deleteProfessional: async ({ commit }, id) => {
    await ProfessionalsAPI.delete(id);
    commit(types.DELETE_AGENDA_PROFESSIONAL, id);
  },

  fetchAvailableSlots: async (
    _store,
    { professionalId, eventTypeId, dateFrom, dateTo }
  ) => {
    const { data } = await ProfessionalsAPI.availableSlots(professionalId, {
      event_type_id: eventTypeId,
      date_from: dateFrom,
      date_to: dateTo,
    });
    return data.slots;
  },

  fetchEventTypes: async ({ commit }) => {
    commit(types.SET_AGENDA_UI_FLAG, { isFetchingEventTypes: true });
    try {
      const { data } = await EventTypesAPI.get();
      commit(types.SET_AGENDA_EVENT_TYPES, data.payload);
    } finally {
      commit(types.SET_AGENDA_UI_FLAG, { isFetchingEventTypes: false });
    }
  },

  createEventType: async ({ commit }, eventTypeData) => {
    const { data } = await EventTypesAPI.create({
      agenda_event_type: eventTypeData,
    });
    commit(types.UPSERT_AGENDA_EVENT_TYPE, data.payload);
    return data.payload;
  },

  updateEventType: async ({ commit }, { id, ...eventTypeData }) => {
    const { data } = await EventTypesAPI.update(id, {
      agenda_event_type: eventTypeData,
    });
    commit(types.UPSERT_AGENDA_EVENT_TYPE, data.payload);
    return data.payload;
  },

  deleteEventType: async ({ commit }, id) => {
    await EventTypesAPI.delete(id);
    commit(types.DELETE_AGENDA_EVENT_TYPE, id);
  },

  fetchAppointments: async ({ commit }, params = {}) => {
    commit(types.SET_AGENDA_UI_FLAG, { isFetchingAppointments: true });
    try {
      const { data } = await AppointmentsAPI.get(params);
      commit(types.SET_AGENDA_APPOINTMENTS, data.payload);
    } finally {
      commit(types.SET_AGENDA_UI_FLAG, { isFetchingAppointments: false });
    }
  },

  createAppointment: async ({ commit }, appointmentData) => {
    const { data } = await AppointmentsAPI.create(appointmentData);
    commit(types.UPSERT_AGENDA_APPOINTMENT, data.payload);
    return data.payload;
  },

  updateAppointment: async ({ commit }, { id, ...appointmentData }) => {
    const { data } = await AppointmentsAPI.update(id, appointmentData);
    commit(types.UPSERT_AGENDA_APPOINTMENT, data.payload);
    return data.payload;
  },

  cancelAppointment: async ({ commit }, { id, reason }) => {
    const { data } = await AppointmentsAPI.cancel(id, reason);
    commit(types.UPSERT_AGENDA_APPOINTMENT, data.payload);
    return data.payload;
  },

  rescheduleAppointment: async ({ commit }, { id, startsAt }) => {
    const { data } = await AppointmentsAPI.reschedule(id, startsAt);
    commit(types.UPSERT_AGENDA_APPOINTMENT, data.payload);
    return data.payload;
  },

  fetchAvailabilities: async ({ commit }, professionalId) => {
    const { data } = await AvailabilitiesAPI.get(professionalId);
    commit(types.SET_AGENDA_AVAILABILITIES, {
      professionalId,
      availabilities: data.payload,
    });
  },

  createAvailability: async (
    { commit },
    { professionalId, availabilityData }
  ) => {
    const { data } = await AvailabilitiesAPI.create(professionalId, {
      agenda_availability: availabilityData,
    });
    commit(types.UPSERT_AGENDA_AVAILABILITY, {
      professionalId,
      availability: data.payload,
    });
    return data.payload;
  },

  updateAvailability: async (
    { commit },
    { professionalId, id, availabilityData }
  ) => {
    const { data } = await AvailabilitiesAPI.update(professionalId, id, {
      agenda_availability: availabilityData,
    });
    commit(types.UPSERT_AGENDA_AVAILABILITY, {
      professionalId,
      availability: data.payload,
    });
    return data.payload;
  },

  deleteAvailability: async ({ commit }, { professionalId, id }) => {
    await AvailabilitiesAPI.delete(professionalId, id);
    commit(types.DELETE_AGENDA_AVAILABILITY, {
      professionalId,
      availabilityId: id,
    });
  },

  replaceWeeklyAvailability: async (
    { commit },
    { professionalId, weeklyBlocks }
  ) => {
    const { data } = await AvailabilitiesAPI.bulkReplaceWeekly(
      professionalId,
      weeklyBlocks
    );
    commit(types.SET_AGENDA_AVAILABILITIES, {
      professionalId,
      availabilities: data.payload,
    });
    return data.payload;
  },
};
