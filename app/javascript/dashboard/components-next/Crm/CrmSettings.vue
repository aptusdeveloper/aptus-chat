<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const pipelines = useMapGetter('crmDeals/pipelines');
const selectedPipelineId = ref(null);
const isSaving = ref(false);
const confirmDeleteId = ref(null);
const confirmDeleteType = ref(null);

const selectedPipeline = computed(
  () => pipelines.value.find(p => p.id === selectedPipelineId.value) ?? null
);

const pipelineForm = ref({ name: '', description: '', active: true });
const stageForm = ref({
  name: '',
  color: '#6B7280',
  position: 0,
  is_win: false,
  is_loss: false,
});
const editingPipelineId = ref(null);
const editingStageId = ref(null);
const showNewPipelineForm = ref(false);
const showNewStageForm = ref(false);

function startEditPipeline(pipeline) {
  editingPipelineId.value = pipeline.id;
  pipelineForm.value = {
    name: pipeline.name,
    description: pipeline.description ?? '',
    active: pipeline.active,
  };
}

function cancelEditPipeline() {
  editingPipelineId.value = null;
  showNewPipelineForm.value = false;
  pipelineForm.value = { name: '', description: '', active: true };
}

function startEditStage(stage) {
  editingStageId.value = stage.id;
  stageForm.value = {
    name: stage.name,
    color: stage.color ?? '#6B7280',
    position: stage.position,
    is_win: stage.is_win,
    is_loss: stage.is_loss,
  };
}

function cancelEditStage() {
  editingStageId.value = null;
  showNewStageForm.value = false;
  stageForm.value = {
    name: '',
    color: '#6B7280',
    position: 0,
    is_win: false,
    is_loss: false,
  };
}

async function savePipeline() {
  if (!pipelineForm.value.name.trim()) return;
  isSaving.value = true;
  try {
    if (editingPipelineId.value) {
      await store.dispatch('crmDeals/updatePipeline', {
        id: editingPipelineId.value,
        ...pipelineForm.value,
      });
    } else {
      await store.dispatch('crmDeals/createPipeline', pipelineForm.value);
    }
    cancelEditPipeline();
  } finally {
    isSaving.value = false;
  }
}

async function saveStage() {
  if (!stageForm.value.name.trim() || !selectedPipelineId.value) return;
  isSaving.value = true;
  try {
    if (editingStageId.value) {
      await store.dispatch('crmDeals/updateStage', {
        pipelineId: selectedPipelineId.value,
        stageId: editingStageId.value,
        stageData: stageForm.value,
      });
    } else {
      const stages = selectedPipeline.value?.stages ?? [];
      const maxPos = stages.length
        ? Math.max(...stages.map(s => s.position)) + 1
        : 0;
      await store.dispatch('crmDeals/createStage', {
        pipelineId: selectedPipelineId.value,
        stageData: { ...stageForm.value, position: maxPos },
      });
    }
    cancelEditStage();
  } finally {
    isSaving.value = false;
  }
}

async function confirmDelete(type, id) {
  if (confirmDeleteId.value === id && confirmDeleteType.value === type) {
    isSaving.value = true;
    try {
      if (type === 'pipeline') {
        await store.dispatch('crmDeals/deletePipeline', id);
        if (selectedPipelineId.value === id) selectedPipelineId.value = null;
      } else if (type === 'stage') {
        await store.dispatch('crmDeals/deleteStage', {
          pipelineId: selectedPipelineId.value,
          stageId: id,
        });
      }
    } finally {
      isSaving.value = false;
      confirmDeleteId.value = null;
      confirmDeleteType.value = null;
    }
  } else {
    confirmDeleteId.value = id;
    confirmDeleteType.value = type;
  }
}
</script>

<template>
  <div
    class="flex flex-col h-full bg-white dark:bg-n-solid-2 border-l border-n-weak w-96 shrink-0 overflow-y-auto"
  >
    <div
      class="flex items-center justify-between px-4 py-3 border-b border-n-weak"
    >
      <h2 class="text-sm font-semibold text-n-slate-12">
        {{ t('CRM.SETTINGS.TITLE') }}
      </h2>
      <button
        class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
        @click="emit('close')"
      >
        <i class="i-lucide-x w-4 h-4" />
      </button>
    </div>

    <div class="flex flex-col gap-0 flex-1 overflow-y-auto">
      <!-- Pipelines list -->
      <div class="border-b border-n-weak">
        <div class="flex items-center justify-between px-4 py-2">
          <p
            class="text-xs font-semibold text-n-slate-9 uppercase tracking-wide"
          >
            {{ t('CRM.SETTINGS.PIPELINES') }}
          </p>
          <button
            class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            @click="
              showNewPipelineForm = true;
              editingPipelineId = null;
              pipelineForm = { name: '', description: '', active: true };
            "
          >
            <i class="i-lucide-plus w-4 h-4" />
          </button>
        </div>

        <!-- New pipeline form -->
        <div v-if="showNewPipelineForm && !editingPipelineId" class="px-4 pb-3">
          <input
            v-model="pipelineForm.name"
            type="text"
            :placeholder="t('CRM.SETTINGS.PIPELINE_NAME_PLACEHOLDER')"
            class="w-full text-sm px-3 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:ring-1 focus:ring-woot-500 mb-2"
          />
          <div class="flex gap-2">
            <button
              class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 transition-colors"
              @click="cancelEditPipeline"
            >
              {{ t('CRM.CANCEL') }}
            </button>
            <button
              :disabled="isSaving"
              class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50 transition-colors"
              @click="savePipeline"
            >
              {{ t('CRM.FORM.SAVE') }}
            </button>
          </div>
        </div>

        <div v-for="pipeline in pipelines" :key="pipeline.id" class="group">
          <!-- Edit inline form -->
          <div v-if="editingPipelineId === pipeline.id" class="px-4 pb-3">
            <input
              v-model="pipelineForm.name"
              type="text"
              class="w-full text-sm px-3 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-woot-500 mb-2"
            />
            <label class="flex items-center gap-2 text-xs text-n-slate-9 mb-2">
              <input
                v-model="pipelineForm.active"
                type="checkbox"
                class="rounded"
              />
              {{ t('CRM.SETTINGS.ACTIVE') }}
            </label>
            <div class="flex gap-2">
              <button
                class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 transition-colors"
                @click="cancelEditPipeline"
              >
                {{ t('CRM.CANCEL') }}
              </button>
              <button
                :disabled="isSaving"
                class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50 transition-colors"
                @click="savePipeline"
              >
                {{ t('CRM.FORM.SAVE') }}
              </button>
            </div>
          </div>

          <!-- Pipeline row -->
          <div
            v-else
            class="flex items-center gap-2 px-4 py-2 cursor-pointer hover:bg-n-alpha-1 transition-colors"
            :class="{ 'bg-n-alpha-2': selectedPipelineId === pipeline.id }"
            @click="selectedPipelineId = pipeline.id"
          >
            <span class="text-sm text-n-slate-12 flex-1 truncate">{{
              pipeline.name
            }}</span>
            <span
              v-if="!pipeline.active"
              class="text-xs text-n-slate-9 bg-n-alpha-2 px-1.5 rounded"
            >
              {{ t('CRM.SETTINGS.INACTIVE') }}
            </span>
            <div class="hidden group-hover:flex items-center gap-1">
              <button
                class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2"
                @click.stop="startEditPipeline(pipeline)"
              >
                <i class="i-lucide-pencil w-3.5 h-3.5" />
              </button>
              <button
                class="p-1 rounded hover:bg-n-alpha-2 transition-colors"
                :class="
                  confirmDeleteId === pipeline.id
                    ? 'text-red-500'
                    : 'text-n-slate-9 hover:text-red-500'
                "
                @click.stop="confirmDelete('pipeline', pipeline.id)"
              >
                <i class="i-lucide-trash-2 w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Stages list for selected pipeline -->
      <div v-if="selectedPipeline">
        <div class="flex items-center justify-between px-4 py-2">
          <p
            class="text-xs font-semibold text-n-slate-9 uppercase tracking-wide"
          >
            {{ t('CRM.SETTINGS.STAGES') }} - {{ selectedPipeline.name }}
          </p>
          <button
            class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            @click="
              showNewStageForm = true;
              editingStageId = null;
              stageForm = {
                name: '',
                color: '#6B7280',
                position: 0,
                is_win: false,
                is_loss: false,
              };
            "
          >
            <i class="i-lucide-plus w-4 h-4" />
          </button>
        </div>

        <!-- New stage form -->
        <div v-if="showNewStageForm && !editingStageId" class="px-4 pb-3">
          <input
            v-model="stageForm.name"
            type="text"
            :placeholder="t('CRM.SETTINGS.STAGE_NAME_PLACEHOLDER')"
            class="w-full text-sm px-3 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:ring-1 focus:ring-woot-500 mb-2"
          />
          <div class="flex items-center gap-3 mb-2">
            <div class="flex items-center gap-2">
              <label class="text-xs text-n-slate-9">{{
                t('CRM.SETTINGS.COLOR')
              }}</label>
              <input
                v-model="stageForm.color"
                type="color"
                class="w-8 h-7 rounded cursor-pointer border-0"
              />
            </div>
            <label class="flex items-center gap-1.5 text-xs text-n-slate-9">
              <input
                v-model="stageForm.is_win"
                type="checkbox"
                class="rounded"
                @change="if (stageForm.is_win) stageForm.is_loss = false;"
              />
              {{ t('CRM.SETTINGS.WIN_STAGE') }}
            </label>
            <label class="flex items-center gap-1.5 text-xs text-n-slate-9">
              <input
                v-model="stageForm.is_loss"
                type="checkbox"
                class="rounded"
                @change="if (stageForm.is_loss) stageForm.is_win = false;"
              />
              {{ t('CRM.SETTINGS.LOSS_STAGE') }}
            </label>
          </div>
          <div class="flex gap-2">
            <button
              class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 transition-colors"
              @click="cancelEditStage"
            >
              {{ t('CRM.CANCEL') }}
            </button>
            <button
              :disabled="isSaving"
              class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50 transition-colors"
              @click="saveStage"
            >
              {{ t('CRM.FORM.SAVE') }}
            </button>
          </div>
        </div>

        <div
          v-for="stage in selectedPipeline.stages ?? []"
          :key="stage.id"
          class="group"
        >
          <!-- Edit inline form -->
          <div v-if="editingStageId === stage.id" class="px-4 pb-3">
            <input
              v-model="stageForm.name"
              type="text"
              class="w-full text-sm px-3 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-woot-500 mb-2"
            />
            <div class="flex items-center gap-3 mb-2">
              <div class="flex items-center gap-2">
                <label class="text-xs text-n-slate-9">{{
                  t('CRM.SETTINGS.COLOR')
                }}</label>
                <input
                  v-model="stageForm.color"
                  type="color"
                  class="w-8 h-7 rounded cursor-pointer border-0"
                />
              </div>
              <label class="flex items-center gap-1.5 text-xs text-n-slate-9">
                <input
                  v-model="stageForm.is_win"
                  type="checkbox"
                  class="rounded"
                  @change="if (stageForm.is_win) stageForm.is_loss = false;"
                />
                {{ t('CRM.SETTINGS.WIN_STAGE') }}
              </label>
              <label class="flex items-center gap-1.5 text-xs text-n-slate-9">
                <input
                  v-model="stageForm.is_loss"
                  type="checkbox"
                  class="rounded"
                  @change="if (stageForm.is_loss) stageForm.is_win = false;"
                />
                {{ t('CRM.SETTINGS.LOSS_STAGE') }}
              </label>
            </div>
            <div class="flex gap-2">
              <button
                class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 transition-colors"
                @click="cancelEditStage"
              >
                {{ t('CRM.CANCEL') }}
              </button>
              <button
                :disabled="isSaving"
                class="flex-1 text-xs px-2 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50 transition-colors"
                @click="saveStage"
              >
                {{ t('CRM.FORM.SAVE') }}
              </button>
            </div>
          </div>

          <!-- Stage row -->
          <div
            v-else
            class="flex items-center gap-2 px-4 py-2 hover:bg-n-alpha-1 transition-colors"
          >
            <span
              class="w-2.5 h-2.5 rounded-full shrink-0"
              :style="{ backgroundColor: stage.color || '#6B7280' }"
            />
            <span class="text-sm text-n-slate-12 flex-1 truncate">{{
              stage.name
            }}</span>
            <span
              v-if="stage.is_win"
              class="text-xs text-emerald-600 bg-emerald-50 dark:bg-emerald-900/20 px-1.5 rounded"
            >
              {{ t('CRM.WON') }}
            </span>
            <span
              v-else-if="stage.is_loss"
              class="text-xs text-red-500 bg-red-50 dark:bg-red-900/20 px-1.5 rounded"
            >
              {{ t('CRM.LOST') }}
            </span>
            <div class="hidden group-hover:flex items-center gap-1">
              <button
                class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2"
                @click="startEditStage(stage)"
              >
                <i class="i-lucide-pencil w-3.5 h-3.5" />
              </button>
              <button
                class="p-1 rounded hover:bg-n-alpha-2 transition-colors"
                :class="
                  confirmDeleteId === stage.id
                    ? 'text-red-500'
                    : 'text-n-slate-9 hover:text-red-500'
                "
                @click="confirmDelete('stage', stage.id)"
              >
                <i class="i-lucide-trash-2 w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <div
        v-else-if="pipelines.length"
        class="flex flex-col items-center justify-center flex-1 gap-2 text-n-slate-9 py-8"
      >
        <i class="i-lucide-mouse-pointer-click w-8 h-8" />
        <p class="text-sm">{{ t('CRM.SETTINGS.SELECT_PIPELINE') }}</p>
      </div>
    </div>
  </div>
</template>
