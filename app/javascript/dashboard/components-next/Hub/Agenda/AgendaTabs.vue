<script setup>
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const tabs = [
  {
    name: 'hub_agenda_professionals',
    labelKey: 'HUB.AGENDA.TABS.PROFESSIONALS',
  },
  { name: 'hub_agenda_event_types', labelKey: 'HUB.AGENDA.TABS.EVENT_TYPES' },
  { name: 'hub_agenda_appointments', labelKey: 'HUB.AGENDA.TABS.APPOINTMENTS' },
];

function goTo(name) {
  router.push({ name, params: { accountId: route.params.accountId } });
}
</script>

<template>
  <div
    class="mb-4 inline-flex items-center gap-1 rounded-lg border border-n-weak bg-n-solid-1 p-1"
  >
    <button
      v-for="tab in tabs"
      :key="tab.name"
      type="button"
      class="h-8 px-3 rounded-md text-sm font-medium transition-colors"
      :class="
        route.name === tab.name
          ? 'bg-n-solid-3 text-n-slate-12 shadow-sm'
          : 'text-n-slate-10 hover:text-n-slate-12'
      "
      @click="goTo(tab.name)"
    >
      {{ t(tab.labelKey) }}
    </button>
  </div>
</template>
