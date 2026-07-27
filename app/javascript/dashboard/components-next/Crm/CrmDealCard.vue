<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['click']);
const { t } = useI18n();

const formattedAmount = computed(() => {
  if (props.deal.amount == null) return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: props.deal.currency || 'BRL',
  }).format(props.deal.amount);
});

const isOverdue = computed(() => {
  if (!props.deal.close_date) return false;
  return new Date(props.deal.close_date) < new Date();
});

const closeDateLabel = computed(() => {
  if (!props.deal.close_date) return null;
  return new Date(props.deal.close_date).toLocaleDateString('pt-BR');
});

const displayName = computed(() => props.deal.contact?.name || props.deal.name);

const contactThumbnail = computed(() => props.deal.contact?.thumbnail || '');
</script>

<template>
  <div
    class="bg-white dark:bg-n-solid-2 rounded-lg border border-n-weak p-3 cursor-grab active:cursor-grabbing shadow-sm hover:shadow-md transition-shadow duration-150 select-none"
    @click="emit('click', deal)"
  >
    <div class="flex items-center gap-2 mb-2 min-w-0">
      <Avatar
        :name="displayName"
        :src="contactThumbnail"
        :size="24"
        rounded-full
      />
      <p class="text-sm font-medium text-n-slate-12 truncate mb-0">
        {{ displayName }}
      </p>
    </div>

    <div class="flex items-center justify-between gap-2 flex-wrap">
      <span
        v-if="formattedAmount"
        class="text-xs font-semibold text-n-slate-11"
      >
        {{ formattedAmount }}
      </span>

      <span
        v-if="closeDateLabel"
        class="text-xs px-1.5 py-0.5 rounded font-medium"
        :class="[
          isOverdue
            ? 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'
            : 'bg-n-alpha-2 text-n-slate-11',
        ]"
      >
        {{ closeDateLabel }}
      </span>
    </div>

    <div v-if="deal.is_win || deal.is_loss" class="mt-2">
      <span
        v-if="deal.is_win"
        class="text-xs bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400 px-1.5 py-0.5 rounded font-medium"
      >
        {{ t('CRM.WON') }}
      </span>
      <span
        v-if="deal.is_loss"
        class="text-xs bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400 px-1.5 py-0.5 rounded font-medium"
      >
        {{ t('CRM.LOST') }}
      </span>
    </div>
  </div>
</template>
