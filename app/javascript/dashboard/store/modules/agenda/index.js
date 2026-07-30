import { getters } from './getters';
import { actions } from './actions';
import { mutations } from './mutations';

const state = {
  professionals: [],
  eventTypes: [],
  appointments: {},
  availabilitiesByProfessional: {},
  uiFlags: {
    isFetchingProfessionals: false,
    isFetchingEventTypes: false,
    isFetchingAppointments: false,
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
