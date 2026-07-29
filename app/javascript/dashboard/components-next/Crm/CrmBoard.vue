<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CrmKanbanColumn from './CrmKanbanColumn.vue';
import CrmDealSidebar from './CrmDealSidebar.vue';
import CrmPipelineSelector from './components/CrmPipelineSelector.vue';
import CrmSettings from './CrmSettings.vue';

const SIDEBAR_MIN_WIDTH = 320;
const SIDEBAR_MAX_WIDTH = 720;
const SIDEBAR_DEFAULT_WIDTH = 320;

const store = useStore();
const { t } = useI18n();

const pipelines = useMapGetter('crmDeals/pipelines');
const activePipeline = useMapGetter('crmDeals/activePipeline');
const uiFlags = useMapGetter('crmDeals/uiFlags');
const dealsByStage = useMapGetter('crmDeals/dealsByStage');
const allDeals = useMapGetter('crmDeals/allDeals');

const selectedDealId = ref(null);
const activePipelineId = ref(null);
const showSettings = ref(false);
const activeFormStageId = ref(null);
const sidebarWidth = ref(SIDEBAR_DEFAULT_WIDTH);

const stages = computed(() => activePipeline.value?.stages ?? []);
const selectedDeal = computed(
  () => allDeals.value.find(deal => deal.id === selectedDealId.value) ?? null
);

function handleSelectDeal(deal) {
  selectedDealId.value = deal.id;
}

function handleSidebarClose() {
  selectedDealId.value = null;
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

// Click-and-drag panning for the board's horizontal scroll, matching
// Kommo's CRM board. Skips interactive elements and deal cards (identified
// by `data-id`, set by CrmKanbanColumn) so it doesn't fight with the
// vuedraggable card-drag or with buttons/inputs.
const boardScrollRef = ref(null);
const isPanning = ref(false);
let panStartX = 0;
let panStartScrollLeft = 0;
const isResizingSidebar = ref(false);
let resizeStartX = 0;
let resizeStartWidth = SIDEBAR_DEFAULT_WIDTH;

function isInteractiveTarget(target) {
  return !!target.closest('button, a, input, select, textarea, [data-id]');
}

function startPan(event) {
  if (event.button !== 0 || isInteractiveTarget(event.target)) return;
  if (isResizingSidebar.value) return;
  const el = boardScrollRef.value;
  if (!el) return;
  isPanning.value = true;
  panStartX = event.clientX;
  panStartScrollLeft = el.scrollLeft;
}

function movePan(event) {
  if (!isPanning.value || !boardScrollRef.value) return;
  event.preventDefault();
  boardScrollRef.value.scrollLeft =
    panStartScrollLeft - (event.clientX - panStartX);
}

function stopPan() {
  isPanning.value = false;
}

function startSidebarResize(event) {
  if (event.button !== 0) return;
  event.preventDefault();
  isResizingSidebar.value = true;
  resizeStartX = event.clientX;
  resizeStartWidth = sidebarWidth.value;
}

function resizeSidebar(event) {
  if (!isResizingSidebar.value) return;
  const nextWidth = resizeStartWidth + (event.clientX - resizeStartX);
  sidebarWidth.value = Math.min(
    SIDEBAR_MAX_WIDTH,
    Math.max(SIDEBAR_MIN_WIDTH, nextWidth)
  );
}

function stopSidebarResize() {
  isResizingSidebar.value = false;
}

onMounted(() => {
  window.addEventListener('mousemove', movePan);
  window.addEventListener('mouseup', stopPan);
  window.addEventListener('mousemove', resizeSidebar);
  window.addEventListener('mouseup', stopSidebarResize);
});

onBeforeUnmount(() => {
  window.removeEventListener('mousemove', movePan);
  window.removeEventListener('mouseup', stopPan);
  window.removeEventListener('mousemove', resizeSidebar);
  window.removeEventListener('mouseup', stopSidebarResize);
});
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden">
    <div
      class="flex items-center gap-3 px-4 py-2 border-b border-n-weak bg-white dark:bg-n-solid-2 shrink-0 min-h-12"
    >
      <CrmPipelineSelector
        v-if="pipelines.length"
        v-model="activePipelineId"
        :pipelines="pipelines"
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
            selectedDealId = null;
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
      <Transition name="crm-lead-sidebar">
        <div
          v-if="selectedDeal && !showSettings"
          class="crm-lead-sidebar h-full shrink-0 overflow-hidden"
          :style="{ width: `${sidebarWidth}px` }"
        >
          <div
            class="crm-lead-sidebar__resizer"
            @mousedown="startSidebarResize"
          />
          <CrmDealSidebar
            :key="selectedDeal.id"
            :deal="selectedDeal"
            @close="handleSidebarClose"
            @deleted="handleSidebarClose"
          />
        </div>
      </Transition>

      <div
        ref="boardScrollRef"
        class="flex gap-3 p-4 overflow-x-auto flex-1"
        :class="isPanning ? 'cursor-grabbing select-none' : 'cursor-grab'"
        @mousedown="startPan"
      >
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

      <CrmSettings v-if="showSettings" @close="showSettings = false" />
    </div>
  </div>
</template>

<style scoped>
.crm-lead-sidebar-enter-active,
.crm-lead-sidebar-leave-active {
  transition:
    width 180ms ease,
    opacity 180ms ease,
    transform 180ms ease;
}

.crm-lead-sidebar-enter-from,
.crm-lead-sidebar-leave-to {
  width: 0;
  opacity: 0;
  transform: translateX(-12px);
}

.crm-lead-sidebar-enter-to,
.crm-lead-sidebar-leave-from {
  width: 20rem;
  opacity: 1;
  transform: translateX(0);
}

.crm-lead-sidebar {
  position: relative;
}

.crm-lead-sidebar__resizer {
  position: absolute;
  top: 0;
  right: 0;
  width: 8px;
  height: 100%;
  cursor: ew-resize;
  z-index: 20;
}

.crm-lead-sidebar__resizer::before {
  content: '';
  position: absolute;
  top: 0;
  right: 3px;
  width: 2px;
  height: 100%;
  background: transparent;
  transition: background-color 160ms ease;
}

.crm-lead-sidebar__resizer:hover::before {
  background: rgba(59, 130, 246, 0.45);
}
</style>
