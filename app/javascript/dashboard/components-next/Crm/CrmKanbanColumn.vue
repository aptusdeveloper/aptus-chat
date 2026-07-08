<script setup>
import { ref, computed, watch } from 'vue';
import Draggable from 'vuedraggable';
import { useStore } from 'dashboard/composables/store';
import CrmDealCard from './CrmDealCard.vue';
import CrmDealForm from './components/CrmDealForm.vue';

const props = defineProps({
  stage: {
    type: Object,
    required: true,
  },
  deals: {
    type: Array,
    default: () => [],
  },
  pipelineId: {
    type: String,
    required: true,
  },
  stages: {
    type: Array,
    required: true,
  },
  activeFormStageId: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(['select-deal', 'open-form', 'close-form']);

const showForm = computed(() => props.activeFormStageId === props.stage.id);

const store = useStore();
const localDeals = ref([...props.deals]);

watch(
  () => props.deals,
  newDeals => {
    localDeals.value = [...newDeals];
  }
);

function onDragEnd(event) {
  const { item, newIndex, to } = event;
  const dealId = item.dataset.id;
  const targetStageId = to.dataset.stageId;

  const sibling = localDeals.value[newIndex - 1];
  const nextSibling = localDeals.value[newIndex + 1];

  let newPosition;
  if (sibling && nextSibling) {
    newPosition = (sibling.position + nextSibling.position) / 2;
  } else if (sibling) {
    newPosition = sibling.position + 1;
  } else if (nextSibling) {
    newPosition = nextSibling.position - 1;
  } else {
    newPosition = 0;
  }

  store.dispatch('crmDeals/moveDeal', {
    id: dealId,
    stageId: targetStageId,
    position: newPosition,
  });
}

const totalAmount = () => {
  return props.deals.reduce((sum, d) => sum + (Number(d.amount) || 0), 0);
};

const formattedTotal = () => {
  const total = totalAmount();
  if (!total) return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(total);
};
</script>

<template>
  <div
    class="flex flex-col min-w-64 w-64 shrink-0 bg-n-alpha-1 dark:bg-n-solid-1 rounded-xl border border-n-weak"
  >
    <div class="px-3 pt-3 pb-2 border-b border-n-weak">
      <div class="flex items-center gap-2 mb-1">
        <span
          class="w-2.5 h-2.5 rounded-full shrink-0"
          :style="{ backgroundColor: stage.color || '#6B7280' }"
        />
        <h3 class="text-sm font-semibold text-n-slate-12 truncate flex-1">
          {{ stage.name }}
        </h3>
        <span
          class="text-xs text-n-slate-9 shrink-0 bg-n-alpha-2 px-1.5 py-0.5 rounded"
        >
          {{ deals.length }}
        </span>
        <button
          class="p-0.5 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
          @click="emit('open-form', stage.id)"
        >
          <i class="i-lucide-plus w-3.5 h-3.5" />
        </button>
      </div>
      <p v-if="formattedTotal()" class="text-xs text-n-slate-9 pl-4">
        {{ formattedTotal() }}
      </p>
    </div>

    <Teleport to="body">
      <div
        v-if="showForm"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="emit('close-form')"
      >
        <CrmDealForm
          :pipeline-id="pipelineId"
          :stages="stages"
          :initial-stage-id="stage.id"
          @saved="emit('close-form')"
          @cancel="emit('close-form')"
        />
      </div>
    </Teleport>

    <Draggable
      v-model="localDeals"
      group="crm-deals"
      item-key="id"
      :data-stage-id="stage.id"
      class="flex flex-col gap-2 p-2 flex-1 min-h-16 overflow-y-auto max-h-[calc(100vh-14rem)]"
      @end="onDragEnd"
    >
      <template #item="{ element }">
        <div :data-id="element.id">
          <CrmDealCard :deal="element" @click="emit('select-deal', element)" />
        </div>
      </template>
    </Draggable>
  </div>
</template>
