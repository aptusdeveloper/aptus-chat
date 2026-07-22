<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

const props = defineProps({
  deal: { type: Object, default: null },
  pipelineId: { type: String, required: true },
  stages: { type: Array, required: true },
  initialStageId: { type: String, default: null },
});

const emit = defineEmits(['saved', 'cancel']);

const store = useStore();
const { t } = useI18n();
const isSaving = ref(false);
const error = ref('');

const defaultStageId = computed(
  () =>
    props.deal?.crm_stage_id ??
    props.initialStageId ??
    props.stages[0]?.id ??
    ''
);

const form = ref({
  name: props.deal?.name ?? '',
  crm_stage_id: defaultStageId.value,
  crm_pipeline_id: props.pipelineId,
});

const isEdit = computed(() => !!props.deal);

async function handleSubmit() {
  error.value = '';
  if (!form.value.name.trim()) {
    error.value = t('CRM.FORM.NAME_REQUIRED');
    return;
  }
  isSaving.value = true;
  try {
    const payload = { ...form.value };
    if (isEdit.value) {
      await store.dispatch('crmDeals/updateDeal', {
        id: props.deal.id,
        ...payload,
      });
    } else {
      await store.dispatch('crmDeals/createDeal', payload);
    }
    emit('saved');
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <div
    class="flex flex-col bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak shadow-lg w-80"
  >
    <div
      class="flex items-center justify-between px-4 py-3 border-b border-n-weak"
    >
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ isEdit ? t('CRM.FORM.EDIT_DEAL') : t('CRM.FORM.CREATE_DEAL') }}
      </h3>
      <button
        class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
        @click="emit('cancel')"
      >
        <i class="i-lucide-x w-4 h-4" />
      </button>
    </div>

    <form class="flex flex-col gap-3 p-4" @submit.prevent="handleSubmit">
      <div>
        <label class="block text-xs text-n-slate-9 mb-1">
          {{ t('CRM.FORM.NAME') }} <span class="text-red-500">*</span>
        </label>
        <input
          v-model="form.name"
          type="text"
          :placeholder="t('CRM.FORM.NAME_PLACEHOLDER')"
          class="w-full text-sm px-3 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:ring-1 focus:ring-woot-500"
        />
        <p v-if="error" class="text-xs text-red-500 mt-1">{{ error }}</p>
      </div>

      <div>
        <label class="block text-xs text-n-slate-9 mb-1">{{
          t('CRM.FORM.STAGE')
        }}</label>
        <select
          v-model="form.crm_stage_id"
          class="w-full text-sm px-3 py-2 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-woot-500"
        >
          <option v-for="stage in stages" :key="stage.id" :value="stage.id">
            {{ stage.name }}
          </option>
        </select>
      </div>

      <div class="flex gap-2 pt-1">
        <button
          type="button"
          class="flex-1 text-sm px-3 py-2 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 transition-colors font-medium"
          @click="emit('cancel')"
        >
          {{ t('CRM.CANCEL') }}
        </button>
        <button
          type="submit"
          :disabled="isSaving"
          class="flex-1 text-sm px-3 py-2 rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50 transition-colors font-medium"
        >
          {{ isSaving ? t('CRM.FORM.SAVING') : t('CRM.FORM.SAVE') }}
        </button>
      </div>
    </form>
  </div>
</template>
