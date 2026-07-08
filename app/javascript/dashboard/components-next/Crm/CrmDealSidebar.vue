<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import CrmDealForm from './components/CrmDealForm.vue';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'deleted']);
const isEditing = ref(false);

const activePipeline = useMapGetter('crmDeals/activePipeline');

const store = useStore();
const { t } = useI18n();
const isDeleting = ref(false);
const confirmDelete = ref(false);

const formattedAmount = computed(() => {
  if (props.deal.amount == null) return '—';
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: props.deal.currency || 'BRL',
  }).format(props.deal.amount);
});

const closeDateLabel = computed(() => {
  if (!props.deal.close_date) return '—';
  return new Date(props.deal.close_date).toLocaleDateString('pt-BR');
});

async function handleDelete() {
  if (!confirmDelete.value) {
    confirmDelete.value = true;
    return;
  }
  isDeleting.value = true;
  try {
    await store.dispatch('crmDeals/deleteDeal', props.deal.id);
    emit('deleted', props.deal.id);
    emit('close');
  } finally {
    isDeleting.value = false;
  }
}
</script>

<template>
  <div
    class="flex flex-col h-full bg-white dark:bg-n-solid-2 border-l border-n-weak w-80 shrink-0 overflow-y-auto"
  >
    <div
      class="flex items-center justify-between px-4 py-3 border-b border-n-weak"
    >
      <h2 class="text-sm font-semibold text-n-slate-12 truncate flex-1 mr-2">
        {{ deal.name }}
      </h2>
      <div class="flex items-center gap-1">
        <button
          class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
          @click="isEditing = !isEditing"
        >
          <i class="i-lucide-pencil w-4 h-4" />
        </button>
        <button
          class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
          @click="emit('close')"
        >
          <i class="i-lucide-x w-4 h-4" />
        </button>
      </div>
    </div>

    <div v-if="isEditing" class="p-3 border-b border-n-weak">
      <CrmDealForm
        :deal="deal"
        :pipeline-id="deal.crm_pipeline_id"
        :stages="activePipeline?.stages ?? []"
        @saved="isEditing = false"
        @cancel="isEditing = false"
      />
    </div>

    <div class="flex flex-col gap-4 p-4">
      <div class="grid grid-cols-2 gap-3">
        <div>
          <p class="text-xs text-n-slate-9 mb-0.5">
            {{ t('CRM.AMOUNT') }}
          </p>
          <p class="text-sm font-semibold text-n-slate-12">
            {{ formattedAmount }}
          </p>
        </div>
        <div>
          <p class="text-xs text-n-slate-9 mb-0.5">
            {{ t('CRM.CLOSE_DATE') }}
          </p>
          <p class="text-sm text-n-slate-12">{{ closeDateLabel }}</p>
        </div>
        <div v-if="deal.probability != null">
          <p class="text-xs text-n-slate-9 mb-0.5">
            {{ t('CRM.PROBABILITY') }}
          </p>
          <p class="text-sm text-n-slate-12">{{ deal.probability }}%</p>
        </div>
      </div>

      <div v-if="deal.assignee_id" class="border-t border-n-weak pt-3">
        <p class="text-xs text-n-slate-9 mb-1">{{ t('CRM.ASSIGNEE') }}</p>
        <p class="text-sm text-n-slate-12">
          {{ deal.assignee?.name ?? '—' }}
        </p>
      </div>

      <div v-if="deal.contact_id" class="border-t border-n-weak pt-3">
        <p class="text-xs text-n-slate-9 mb-1">{{ t('CRM.CONTACT') }}</p>
        <p class="text-sm text-n-slate-12">{{ deal.contact?.name ?? '—' }}</p>
      </div>
    </div>

    <div class="mt-auto p-4 border-t border-n-weak flex gap-2">
      <button
        v-if="!confirmDelete"
        class="flex-1 text-sm px-3 py-2 rounded-lg bg-red-50 text-red-600 hover:bg-red-100 dark:bg-red-900/20 dark:text-red-400 dark:hover:bg-red-900/40 transition-colors font-medium"
        :disabled="isDeleting"
        @click="handleDelete"
      >
        {{ t('CRM.DELETE') }}
      </button>
      <template v-else>
        <button
          class="flex-1 text-sm px-3 py-2 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 transition-colors font-medium"
          @click="confirmDelete = false"
        >
          {{ t('CRM.CANCEL') }}
        </button>
        <button
          class="flex-1 text-sm px-3 py-2 rounded-lg bg-red-600 text-white hover:bg-red-700 transition-colors font-medium"
          :disabled="isDeleting"
          @click="handleDelete"
        >
          {{ isDeleting ? t('CRM.DELETING') : t('CRM.CONFIRM_DELETE') }}
        </button>
      </template>
    </div>
  </div>
</template>
