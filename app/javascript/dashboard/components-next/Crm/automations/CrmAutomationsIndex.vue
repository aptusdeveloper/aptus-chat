<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { computed, onMounted, ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import { TRIGGERS } from './constants';

const store = useStore();
const router = useRouter();
const route = useRoute();
const { t } = useI18n();

const automations = useMapGetter('crmAutomations/all');
const uiFlags = useMapGetter('crmAutomations/uiFlags');
const confirmDeleteId = ref(null);

const accountId = computed(() => route.params.accountId);

const triggerLabels = computed(() =>
  TRIGGERS.reduce((acc, trigger) => {
    acc[trigger.id] = t(trigger.labelKey);
    return acc;
  }, {})
);

const automationTriggers = automation => automation.triggers || [];

const triggerName = trigger =>
  triggerLabels.value[trigger.trigger_type] || trigger.trigger_type;

const triggerDetails = trigger => {
  const details = [
    trigger.crm_pipeline_name || t('CRM.AUTOMATIONS.FORM.ALL_PIPELINES_OPTION'),
  ];

  if (trigger.stage_names?.length) {
    details.push(trigger.stage_names.join(', '));
  }

  if (trigger.days) {
    details.push(`${trigger.days} ${t('CRM.AUTOMATIONS.LIST.DAYS_SUFFIX')}`);
  }

  return details.join(' · ');
};

const actionCount = automation =>
  automation.actions_count ?? automation.actions?.length ?? 0;

const updatedAt = automation => {
  if (!automation.updated_at) return '-';
  return new Date(automation.updated_at * 1000).toLocaleDateString('pt-BR');
};

const openNewAutomation = () => {
  router.push({
    name: 'crm_automation_new',
    params: { accountId: accountId.value },
  });
};

const openAutomation = automation => {
  router.push({
    name: 'crm_automation_edit',
    params: { accountId: accountId.value, automationId: automation.id },
  });
};

const toggleAutomation = async automation => {
  await store.dispatch('crmAutomations/update', {
    id: automation.id,
    active: !automation.active,
  });
};

const cloneAutomation = async automation => {
  const cloned = await store.dispatch('crmAutomations/clone', automation.id);
  useAlert(t('CRM.AUTOMATIONS.LIST.CLONE_SUCCESS'));
  openAutomation(cloned);
};

const deleteAutomation = async automation => {
  if (confirmDeleteId.value !== automation.id) {
    confirmDeleteId.value = automation.id;
    return;
  }

  await store.dispatch('crmAutomations/delete', automation.id);
  confirmDeleteId.value = null;
  useAlert(t('CRM.AUTOMATIONS.LIST.DELETE_SUCCESS'));
};

onMounted(async () => {
  await store.dispatch('crmAutomations/fetch');
});
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 overflow-hidden">
    <div
      class="flex items-center justify-between gap-3 px-4 py-3 border-b border-n-weak bg-white dark:bg-n-solid-2 shrink-0"
    >
      <div class="min-w-0">
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ t('CRM.AUTOMATIONS.TITLE') }}
        </h2>
        <p class="mt-0.5 text-xs text-n-slate-10">
          {{ t('CRM.AUTOMATIONS.SUBTITLE') }}
        </p>
      </div>
      <Button
        icon="i-lucide-plus"
        :label="t('CRM.AUTOMATIONS.LIST.NEW')"
        @click="openNewAutomation"
      />
    </div>

    <div class="flex-1 min-h-0 overflow-auto p-4">
      <div
        v-if="uiFlags.isFetching"
        class="flex items-center justify-center h-full text-n-slate-9"
      >
        <i class="i-lucide-loader-2 w-5 h-5 animate-spin" />
      </div>

      <div
        v-else-if="!automations.length"
        class="flex flex-col items-center justify-center h-full gap-3 text-center text-n-slate-10"
      >
        <i class="i-lucide-workflow w-10 h-10" />
        <div>
          <p class="text-sm font-medium text-n-slate-12">
            {{ t('CRM.AUTOMATIONS.LIST.EMPTY_TITLE') }}
          </p>
          <p class="mt-1 text-sm">
            {{ t('CRM.AUTOMATIONS.LIST.EMPTY_SUBTITLE') }}
          </p>
        </div>
        <Button
          icon="i-lucide-plus"
          :label="t('CRM.AUTOMATIONS.LIST.NEW')"
          @click="openNewAutomation"
        />
      </div>

      <div
        v-else
        class="overflow-hidden rounded-lg border border-n-weak bg-white dark:bg-n-solid-2"
      >
        <table class="w-full text-sm">
          <thead class="bg-n-alpha-1 text-xs uppercase text-n-slate-9">
            <tr>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('CRM.AUTOMATIONS.LIST.COLUMNS.NAME') }}
              </th>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('CRM.AUTOMATIONS.LIST.COLUMNS.STATUS') }}
              </th>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('CRM.AUTOMATIONS.LIST.COLUMNS.TRIGGER') }}
              </th>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('CRM.AUTOMATIONS.LIST.COLUMNS.ACTIONS') }}
              </th>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('CRM.AUTOMATIONS.LIST.COLUMNS.UPDATED') }}
              </th>
              <th class="px-4 py-3 text-right font-semibold">
                {{ t('CRM.AUTOMATIONS.LIST.COLUMNS.MANAGE') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="automation in automations"
              :key="automation.id"
              class="border-t border-n-weak hover:bg-n-alpha-1"
            >
              <td class="px-4 py-3">
                <button
                  class="max-w-xs truncate text-left font-medium text-n-slate-12 hover:text-n-blue-11"
                  @click="openAutomation(automation)"
                >
                  {{ automation.name }}
                </button>
              </td>
              <td class="px-4 py-3">
                <span
                  class="inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-xs font-medium"
                  :class="
                    automation.active
                      ? 'bg-n-teal-9/10 text-n-teal-11'
                      : 'bg-n-slate-9/10 text-n-slate-11'
                  "
                >
                  <i
                    :class="
                      automation.active
                        ? 'i-lucide-circle-check'
                        : 'i-lucide-circle'
                    "
                    class="w-3.5 h-3.5"
                  />
                  {{
                    automation.active
                      ? t('CRM.AUTOMATIONS.STATUS.ACTIVE')
                      : t('CRM.AUTOMATIONS.STATUS.INACTIVE')
                  }}
                </span>
              </td>
              <td class="px-4 py-3 text-n-slate-11">
                <div class="flex max-w-md flex-wrap gap-2">
                  <span
                    v-for="(trigger, triggerIndex) in automationTriggers(
                      automation
                    )"
                    :key="`${automation.id}-${triggerIndex}`"
                    class="inline-flex max-w-64 flex-col rounded-md bg-n-alpha-1 px-2 py-1 text-xs"
                  >
                    <span class="font-medium text-n-slate-12">
                      {{ triggerName(trigger) }}
                    </span>
                    <span class="break-words text-n-slate-10">
                      {{ triggerDetails(trigger) }}
                    </span>
                  </span>
                </div>
              </td>
              <td class="px-4 py-3 text-n-slate-11">
                {{ actionCount(automation) }}
              </td>
              <td class="px-4 py-3 text-n-slate-11">
                {{ updatedAt(automation) }}
              </td>
              <td class="px-4 py-3">
                <div class="flex items-center justify-end gap-1">
                  <Button
                    ghost
                    slate
                    sm
                    icon="i-lucide-pencil"
                    @click="openAutomation(automation)"
                  />
                  <Button
                    ghost
                    slate
                    sm
                    icon="i-lucide-copy"
                    :is-loading="uiFlags.isCloning"
                    @click="cloneAutomation(automation)"
                  />
                  <Button
                    ghost
                    slate
                    sm
                    :icon="
                      automation.active ? 'i-lucide-pause' : 'i-lucide-play'
                    "
                    :is-loading="uiFlags.isUpdating"
                    @click="toggleAutomation(automation)"
                  />
                  <Button
                    ghost
                    ruby
                    sm
                    :icon="
                      confirmDeleteId === automation.id
                        ? 'i-lucide-check'
                        : 'i-lucide-trash-2'
                    "
                    :is-loading="uiFlags.isDeleting"
                    @click="deleteAutomation(automation)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
