import types from '../../mutation-types';

export const mutations = {
  [types.SET_CRM_PIPELINES]($state, pipelines) {
    $state.pipelines = pipelines;
  },

  [types.SET_CRM_DEALS]($state, deals) {
    $state.deals = deals.reduce((acc, deal) => {
      acc[deal.id] = deal;
      return acc;
    }, {});
  },

  [types.SET_CRM_ACTIVE_PIPELINE]($state, pipelineId) {
    $state.activePipelineId = pipelineId;
  },

  [types.SET_CRM_UI_FLAG]($state, flags) {
    $state.uiFlags = { ...$state.uiFlags, ...flags };
  },

  [types.UPSERT_CRM_DEAL]($state, deal) {
    $state.deals = { ...$state.deals, [deal.id]: deal };
  },

  [types.DELETE_CRM_DEAL]($state, dealId) {
    const { [dealId]: _, ...rest } = $state.deals;
    $state.deals = rest;
  },

  [types.UPSERT_CRM_PIPELINE]($state, pipeline) {
    const idx = $state.pipelines.findIndex(p => p.id === pipeline.id);
    if (idx !== -1) {
      $state.pipelines = $state.pipelines.map(p =>
        p.id === pipeline.id ? pipeline : p
      );
    } else {
      $state.pipelines = [...$state.pipelines, pipeline];
    }
  },

  [types.DELETE_CRM_PIPELINE]($state, pipelineId) {
    $state.pipelines = $state.pipelines.filter(p => p.id !== pipelineId);
    if ($state.activePipelineId === pipelineId) {
      $state.activePipelineId = $state.pipelines[0]?.id ?? null;
    }
  },

  [types.UPSERT_CRM_STAGE]($state, { pipelineId, stage }) {
    $state.pipelines = $state.pipelines.map(p => {
      if (p.id !== pipelineId) return p;
      const stages = p.stages ?? [];
      const idx = stages.findIndex(s => s.id === stage.id);
      const newStages =
        idx !== -1
          ? stages.map(s => (s.id === stage.id ? stage : s))
          : [...stages, stage];
      return {
        ...p,
        stages: newStages.sort((a, b) => a.position - b.position),
      };
    });
  },

  [types.DELETE_CRM_STAGE]($state, { pipelineId, stageId }) {
    $state.pipelines = $state.pipelines.map(p => {
      if (p.id !== pipelineId) return p;
      return { ...p, stages: (p.stages ?? []).filter(s => s.id !== stageId) };
    });
  },
};
