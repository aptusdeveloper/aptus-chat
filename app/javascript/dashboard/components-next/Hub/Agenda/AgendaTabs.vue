<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const tabDefs = [
  {
    name: 'hub_agenda_professionals',
    labelKey: 'HUB.AGENDA.TABS.PROFESSIONALS',
  },
  { name: 'hub_agenda_event_types', labelKey: 'HUB.AGENDA.TABS.EVENT_TYPES' },
  { name: 'hub_agenda_appointments', labelKey: 'HUB.AGENDA.TABS.APPOINTMENTS' },
];

const tabs = computed(() =>
  tabDefs.map(tab => ({ name: tab.name, label: t(tab.labelKey) }))
);

const activeIndex = computed(() => {
  const index = tabDefs.findIndex(tab => tab.name === route.name);
  return index === -1 ? 0 : index;
});

function handleTabChanged(tab) {
  router.push({
    name: tab.name,
    params: { accountId: route.params.accountId },
  });
}
</script>

<template>
  <TabBar
    class="mb-4"
    :tabs="tabs"
    :initial-active-tab="activeIndex"
    @tab-changed="handleTabChanged"
  />
</template>
