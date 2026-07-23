<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import AptusHubAPI from 'dashboard/api/aptusHub';
import { currentMonthRange, formatNumber, hubErrorMessage } from './utils';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const range = currentMonthRange();

const filters = ref({ ...range });
const data = ref(null);
const isLoading = ref(false);
const error = ref('');

const metrics = computed(() => data.value?.metrics || {});
const channels = computed(() => data.value?.channels || []);
const hasUsage = computed(
  () =>
    Number(metrics.value.sessions || 0) > 0 ||
    Number(metrics.value.total_messages || 0) > 0 ||
    Number(metrics.value.total_users || 0) > 0
);

const statusLabel = computed(() => {
  const labels = {
    active: 'Ativo',
    paused: 'Pausado',
    cancelled: 'Cancelado',
  };
  return labels[data.value?.bot?.status] || 'Ativo';
});

const stats = computed(() => [
  {
    label: t('HUB.METRICS.SESSIONS'),
    value: formatNumber(metrics.value.sessions),
    icon: 'i-lucide-panel-top-open',
  },
  {
    label: t('HUB.METRICS.MESSAGES'),
    value: formatNumber(metrics.value.total_messages),
    icon: 'i-lucide-messages-square',
  },
  {
    label: t('HUB.METRICS.USERS'),
    value: formatNumber(metrics.value.total_users),
    icon: 'i-lucide-users',
  },
  {
    label: t('HUB.METRICS.NEW_USERS'),
    value: formatNumber(metrics.value.new_users),
    icon: 'i-lucide-user-plus',
  },
  {
    label: t('HUB.METRICS.RETURNING_USERS'),
    value: formatNumber(metrics.value.returning_users),
    icon: 'i-lucide-refresh-cw',
  },
]);

async function loadOverview() {
  isLoading.value = true;
  error.value = '';

  try {
    const response = await AptusHubAPI.overview(filters.value);
    data.value = response.data;
  } catch (apiError) {
    error.value = hubErrorMessage(apiError);
  } finally {
    isLoading.value = false;
  }
}

function openTester() {
  router.push({
    name: 'hub_tester',
    params: { accountId: route.params.accountId },
  });
}

onMounted(loadOverview);
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4">
    <div class="flex flex-wrap items-center gap-3 mb-4">
      <div class="mr-auto min-w-0">
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('HUB.OVERVIEW.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-10">
          {{ t('HUB.OVERVIEW.SUBTITLE') }}
        </p>
      </div>

      <input
        v-model="filters.from"
        type="date"
        class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
      />
      <input
        v-model="filters.to"
        type="date"
        class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
      />
      <button
        class="inline-flex items-center gap-2 h-9 px-3 rounded-lg text-sm font-medium bg-n-brand text-white hover:opacity-90 disabled:opacity-60"
        :disabled="isLoading"
        @click="loadOverview"
      >
        <i
          class="i-lucide-refresh-cw w-4 h-4"
          :class="{ 'animate-spin': isLoading }"
        />
        {{ t('HUB.ACTIONS.REFRESH') }}
      </button>
    </div>

    <div
      v-if="error"
      class="mb-4 rounded-lg border border-n-ruby-5 bg-n-ruby-2 px-4 py-3 text-sm text-n-ruby-11"
    >
      {{ error }}
    </div>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 text-sm text-n-slate-10"
    >
      <i class="i-lucide-loader-2 w-4 h-4 animate-spin" />
      {{ t('HUB.LOADING') }}
    </div>

    <template v-else-if="data">
      <section
        class="mb-4 rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4"
      >
        <div class="flex flex-wrap items-center gap-3">
          <div
            class="grid place-content-center size-10 rounded-lg bg-n-alpha-2 shrink-0"
          >
            <i class="i-lucide-bot w-5 h-5 text-n-slate-11" />
          </div>
          <div class="min-w-0 mr-auto">
            <h3 class="text-base font-semibold text-n-slate-12 truncate">
              {{ data.bot.name }}
            </h3>
            <p class="text-xs text-n-slate-9 truncate">{{ data.bot.id }}</p>
          </div>
          <span
            class="inline-flex items-center h-7 px-2 rounded-md text-xs font-medium bg-n-teal-3 text-n-teal-11"
          >
            {{ statusLabel }}
          </span>
          <button
            class="inline-flex items-center gap-2 h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 border border-n-weak hover:bg-n-alpha-2"
            @click="openTester"
          >
            <i class="i-lucide-message-circle-play w-4 h-4" />
            {{ t('HUB.NAV.TEST') }}
          </button>
        </div>
      </section>

      <section class="grid gap-3 sm:grid-cols-2 xl:grid-cols-5 mb-4">
        <div
          v-for="stat in stats"
          :key="stat.label"
          class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4 min-h-24"
        >
          <div
            class="flex items-center gap-2 text-xs font-medium text-n-slate-9"
          >
            <i class="w-4 h-4" :class="stat.icon" />
            {{ stat.label }}
          </div>
          <div class="mt-3 text-2xl font-semibold text-n-slate-12">
            {{ stat.value }}
          </div>
        </div>
      </section>

      <div
        v-if="!hasUsage"
        class="mb-4 rounded-lg border border-n-weak bg-n-alpha-1 px-4 py-3 text-sm text-n-slate-10"
      >
        {{ t('HUB.OVERVIEW.EMPTY_USAGE') }}
      </div>

      <section
        class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2"
      >
        <div class="px-4 py-3 border-b border-n-weak">
          <h3 class="text-sm font-semibold text-n-slate-12">
            {{ t('HUB.OVERVIEW.CHANNELS') }}
          </h3>
        </div>
        <div v-if="channels.length" class="divide-y divide-n-weak">
          <div
            v-for="channel in channels"
            :key="channel.id"
            class="flex items-center gap-3 px-4 py-3"
          >
            <i class="i-lucide-mailbox w-4 h-4 text-n-slate-9" />
            <div class="min-w-0 mr-auto">
              <p class="text-sm font-medium text-n-slate-12 truncate">
                {{ channel.name }}
              </p>
              <p class="text-xs text-n-slate-9">{{ channel.channel_type }}</p>
            </div>
            <span class="text-xs text-n-teal-11">
              {{ t('HUB.OVERVIEW.CONNECTED') }}
            </span>
          </div>
        </div>
        <div v-else class="px-4 py-6 text-sm text-n-slate-10">
          {{ t('HUB.OVERVIEW.NO_CHANNELS') }}
        </div>
      </section>
    </template>
  </div>
</template>
