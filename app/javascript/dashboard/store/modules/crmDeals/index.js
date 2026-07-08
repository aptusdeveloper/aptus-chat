import { getters } from './getters';
import { actions } from './actions';
import { mutations } from './mutations';

const state = {
  pipelines: [],
  deals: {},
  activePipelineId: null,
  uiFlags: {
    isFetchingPipelines: false,
    isFetchingDeals: false,
    isMoving: false,
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
