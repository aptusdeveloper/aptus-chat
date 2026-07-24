<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';

const route = useRoute();
const { t } = useI18n();
const accountId = computed(() => route.params.accountId);

const tabs = computed(() => [
  {
    name: 'hub_performance',
    label: t('HUB.NAV.PERFORMANCE'),
    icon: 'i-lucide-chart-no-axes-column',
    to: { name: 'hub_performance', params: { accountId: accountId.value } },
  },
  {
    name: 'hub_tester',
    label: t('HUB.NAV.TEST'),
    icon: 'i-lucide-square-play',
    to: { name: 'hub_tester', params: { accountId: accountId.value } },
  },
  {
    name: 'hub_payments',
    label: t('HUB.NAV.PAYMENTS'),
    icon: 'i-lucide-credit-card',
    to: { name: 'hub_payments', params: { accountId: accountId.value } },
  },
]);
</script>

<template>
  <div class="flex flex-col h-full w-full overflow-hidden">
    <div
      class="flex flex-wrap items-center gap-3 px-4 py-3 border-b border-n-weak bg-white dark:bg-n-solid-2 shrink-0"
    >
      <div class="flex items-center gap-2 min-w-0">
        <i class="i-lucide-bot w-5 h-5 text-n-slate-9 shrink-0" />
        <h1 class="text-base font-semibold text-n-slate-12 truncate">
          {{ t('HUB.TITLE') }}
        </h1>
      </div>

      <nav class="flex items-center gap-1 min-w-0">
        <router-link
          v-for="tab in tabs"
          :key="tab.name"
          :to="tab.to"
          class="inline-flex items-center gap-2 h-8 px-3 rounded-lg text-sm font-medium transition-colors whitespace-nowrap"
          :class="
            route.name === tab.name
              ? 'bg-n-brand/10 text-n-blue-11'
              : 'text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2'
          "
        >
          <i class="w-4 h-4 shrink-0" :class="tab.icon" />
          <span>{{ tab.label }}</span>
        </router-link>
      </nav>
    </div>

    <router-view />
  </div>
</template>
