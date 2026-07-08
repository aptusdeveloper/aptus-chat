<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CrmKanbanColumn from './CrmKanbanColumn.vue';
import CrmDealSidebar from './CrmDealSidebar.vue';
import CrmPipelineSelector from './components/CrmPipelineSelector.vue';
import CrmSettings from './CrmSettings.vue';

const store = useStore();
const { t } = useI18n();

const pipelines = useMapGetter('crmDeals/pipelines');
const activePipeline = useMapGetter('crmDeals/activePipeline');
const uiFlags = useMapGetter('crmDeals/uiFlags');
const dealsByStage = useMapGetter('crmDeals/dealsByStage');

const selectedDeal = ref(null);
const activePipelineId = ref(null);
const showSettings = ref(false);
const activeFormStageId = ref(null);

const stages = computed(() => activePipeline.value?.stages ?? []);

function handleSelectDeal(deal) {
  selectedDeal.value = deal;
}

function handleSidebarClose() {
  selectedDeal.value = null;
}

async function loadDeals(pipelineId) {
  if (!pipelineId) return;
  await store.dispatch('crmDeals/setActivePipeline', pipelineId);
  await store.dispatch('crmDeals/fetchDeals', pipelineId);
}

watch(activePipelineId, newId => {
  if (newId) loadDeals(newId);
});

watch(pipelines, newPipelines => {
  if (newPipelines.length && !activePipelineId.value) {
    activePipelineId.value = newPipelines[0].id;
  }
});

onMounted(async () => {
  await store.dispatch('crmDeals/fetchPipelines');
});
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden">
    <div
      class="flex items-center gap-3 px-4 py-3 border-b border-n-weak bg-white dark:bg-n-solid-2 shrink-0"
    >
      <i class="i-lucide-kanban w-5 h-5 text-n-slate-9" />
      <h1 class="text-base font-semibold text-n-slate-12">
        {{ t('SIDEBAR.CRM') }}
      </h1>

      <CrmPipelineSelector
        v-if="pipelines.length"
        v-model="activePipelineId"
        :pipelines="pipelines"
        class="ml-2"
      />

      <div class="ml-auto flex items-center gap-2">
        <div
          v-if="uiFlags.isFetchingDeals"
          class="flex items-center gap-2 text-xs text-n-slate-9"
        >
          <i class="i-lucide-loader-2 w-4 h-4 animate-spin" />
          {{ t('CRM.LOADING') }}
        </div>
        <button
          class="p-1.5 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
          @click="
            showSettings = !showSettings;
            selectedDeal = null;
          "
        >
          <i class="i-lucide-settings w-4 h-4" />
        </button>
      </div>
    </div>

    <div
      v-if="!pipelines.length && !uiFlags.isFetchingPipelines"
      class="flex flex-col items-center justify-center flex-1 gap-2 text-n-slate-9"
    >
      <i class="i-lucide-inbox w-10 h-10" />
      <p class="text-sm">{{ t('CRM.NO_PIPELINES') }}</p>
    </div>

    <div class="flex flex-1 overflow-hidden">
      <div class="flex gap-3 p-4 overflow-x-auto flex-1">
        <CrmKanbanColumn
          v-for="stage in stages"
          :key="stage.id"
          :stage="stage"
          :deals="dealsByStage(stage.id)"
          :pipeline-id="activePipelineId"
          :stages="stages"
          :active-form-stage-id="activeFormStageId"
          @select-deal="handleSelectDeal"
          @open-form="activeFormStageId = $event"
          @close-form="activeFormStageId = null"
        />

        <div
          v-if="
            stages.length === 0 && activePipeline && !uiFlags.isFetchingDeals
          "
          class="flex flex-col items-center justify-center w-full gap-2 text-n-slate-9"
        >
          <i class="i-lucide-layout-list w-10 h-10" />
          <p class="text-sm">{{ t('CRM.NO_STAGES') }}</p>
        </div>
      </div>

      <CrmDealSidebar
        v-if="selectedDeal && !showSettings"
        :deal="selectedDeal"
        @close="handleSidebarClose"
        @deleted="handleSidebarClose"
      />

      <CrmSettings v-if="showSettings" @close="showSettings = false" />
    </div>
  </div>
</template>
