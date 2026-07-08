import PipelinesAPI from 'dashboard/api/crm/pipelines';
import DealsAPI from 'dashboard/api/crm/deals';
import StagesAPI from 'dashboard/api/crm/stages';
import types from '../../mutation-types';

export const actions = {
  fetchPipelines: async ({ commit }) => {
    commit(types.SET_CRM_UI_FLAG, { isFetchingPipelines: true });
    try {
      const { data } = await PipelinesAPI.get();
      commit(types.SET_CRM_PIPELINES, data.payload);
    } finally {
      commit(types.SET_CRM_UI_FLAG, { isFetchingPipelines: false });
    }
  },

  setActivePipeline: ({ commit }, pipelineId) => {
    commit(types.SET_CRM_ACTIVE_PIPELINE, pipelineId);
  },

  fetchDeals: async ({ commit }, pipelineId) => {
    commit(types.SET_CRM_UI_FLAG, { isFetchingDeals: true });
    try {
      const { data } = await DealsAPI.get({ pipeline_id: pipelineId });
      commit(types.SET_CRM_DEALS, data.payload);
    } finally {
      commit(types.SET_CRM_UI_FLAG, { isFetchingDeals: false });
    }
  },

  moveDeal: async ({ commit, state }, { id, stageId, position }) => {
    const original = state.deals[id];
    commit(types.UPSERT_CRM_DEAL, {
      ...original,
      crm_stage_id: stageId,
      position,
    });
    commit(types.SET_CRM_UI_FLAG, { isMoving: true });
    try {
      const { data } = await DealsAPI.move(id, { stageId, position });
      commit(types.UPSERT_CRM_DEAL, data.payload);
    } catch {
      commit(types.UPSERT_CRM_DEAL, original);
    } finally {
      commit(types.SET_CRM_UI_FLAG, { isMoving: false });
    }
  },

  createDeal: async ({ commit }, dealData) => {
    const { data } = await DealsAPI.create({ crm_deal: dealData });
    commit(types.UPSERT_CRM_DEAL, data.payload);
    return data.payload;
  },

  updateDeal: async ({ commit }, { id, ...dealData }) => {
    const { data } = await DealsAPI.update(id, { crm_deal: dealData });
    commit(types.UPSERT_CRM_DEAL, data.payload);
    return data.payload;
  },

  deleteDeal: async ({ commit }, id) => {
    await DealsAPI.delete(id);
    commit(types.DELETE_CRM_DEAL, id);
  },

  createPipeline: async ({ commit }, pipelineData) => {
    const { data } = await PipelinesAPI.create({ crm_pipeline: pipelineData });
    commit(types.UPSERT_CRM_PIPELINE, data.payload);
    return data.payload;
  },

  updatePipeline: async ({ commit }, { id, ...pipelineData }) => {
    const { data } = await PipelinesAPI.update(id, {
      crm_pipeline: pipelineData,
    });
    commit(types.UPSERT_CRM_PIPELINE, data.payload);
    return data.payload;
  },

  deletePipeline: async ({ commit }, id) => {
    await PipelinesAPI.delete(id);
    commit(types.DELETE_CRM_PIPELINE, id);
  },

  createStage: async ({ commit }, { pipelineId, stageData }) => {
    const { data } = await StagesAPI.createStage(pipelineId, {
      stage: stageData,
    });
    commit(types.UPSERT_CRM_STAGE, { pipelineId, stage: data.payload });
    return data.payload;
  },

  updateStage: async ({ commit }, { pipelineId, stageId, stageData }) => {
    const { data } = await StagesAPI.updateStage(pipelineId, stageId, {
      stage: stageData,
    });
    commit(types.UPSERT_CRM_STAGE, { pipelineId, stage: data.payload });
    return data.payload;
  },

  deleteStage: async ({ commit }, { pipelineId, stageId }) => {
    await StagesAPI.deleteStage(pipelineId, stageId);
    commit(types.DELETE_CRM_STAGE, { pipelineId, stageId });
  },
};
