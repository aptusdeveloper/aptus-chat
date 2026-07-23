import { uploadFile } from 'dashboard/helper/uploadHelper';
import CrmAutomationRulesAPI from 'dashboard/api/crm/automationRules';
import types from '../../mutation-types';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isCloning: false,
    isUploading: false,
  },
};

const getters = {
  all($state) {
    return [...$state.records].sort((a, b) => b.updated_at - a.updated_at);
  },

  byId: $state => id => {
    return $state.records.find(record => record.id === id) || null;
  },

  uiFlags($state) {
    return $state.uiFlags;
  },
};

const mutations = {
  [types.SET_CRM_AUTOMATION_UI_FLAG]($state, flags) {
    $state.uiFlags = { ...$state.uiFlags, ...flags };
  },

  [types.SET_CRM_AUTOMATIONS]($state, records) {
    $state.records = records;
  },

  [types.UPSERT_CRM_AUTOMATION]($state, record) {
    const exists = $state.records.some(item => item.id === record.id);
    $state.records = exists
      ? $state.records.map(item => (item.id === record.id ? record : item))
      : [record, ...$state.records];
  },

  [types.DELETE_CRM_AUTOMATION]($state, id) {
    $state.records = $state.records.filter(record => record.id !== id);
  },
};

const actions = {
  fetch: async ({ commit }) => {
    commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isFetching: true });
    try {
      const { data } = await CrmAutomationRulesAPI.get();
      commit(types.SET_CRM_AUTOMATIONS, data.payload);
      return data.payload;
    } finally {
      commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isFetching: false });
    }
  },

  fetchOne: async ({ commit }, id) => {
    commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isFetching: true });
    try {
      const { data } = await CrmAutomationRulesAPI.show(id);
      commit(types.UPSERT_CRM_AUTOMATION, data.payload);
      return data.payload;
    } finally {
      commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, automation) => {
    commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isCreating: true });
    try {
      const { data } = await CrmAutomationRulesAPI.create({
        crm_automation_rule: automation,
      });
      commit(types.UPSERT_CRM_AUTOMATION, data.payload);
      return data.payload;
    } finally {
      commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { id, ...automation }) => {
    commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await CrmAutomationRulesAPI.update(id, {
        crm_automation_rule: automation,
      });
      commit(types.UPSERT_CRM_AUTOMATION, data.payload);
      return data.payload;
    } finally {
      commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isDeleting: true });
    try {
      await CrmAutomationRulesAPI.delete(id);
      commit(types.DELETE_CRM_AUTOMATION, id);
    } finally {
      commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isDeleting: false });
    }
  },

  clone: async ({ commit }, id) => {
    commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isCloning: true });
    try {
      const { data } = await CrmAutomationRulesAPI.clone(id);
      commit(types.UPSERT_CRM_AUTOMATION, data.payload);
      return data.payload;
    } finally {
      commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isCloning: false });
    }
  },

  uploadAttachment: async ({ commit }, file) => {
    commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isUploading: true });
    try {
      return await uploadFile(file);
    } finally {
      commit(types.SET_CRM_AUTOMATION_UI_FLAG, { isUploading: false });
    }
  },
};

export { actions, getters, mutations, state };

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
