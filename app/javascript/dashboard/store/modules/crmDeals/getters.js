export const getters = {
  pipelines($state) {
    return $state.pipelines;
  },

  activePipeline($state) {
    return $state.pipelines.find(p => p.id === $state.activePipelineId) || null;
  },

  dealsByStage($state) {
    return stageId =>
      Object.values($state.deals)
        .filter(d => d.crm_stage_id === stageId)
        .sort((a, b) => a.position - b.position);
  },

  allDeals($state) {
    return Object.values($state.deals);
  },

  uiFlags($state) {
    return $state.uiFlags;
  },
};
