<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import AptusHubAPI from 'dashboard/api/aptusHub';
import {
  currentMonthRange,
  formatCurrency,
  formatNumber,
  hubErrorMessage,
} from './utils';

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
const history = computed(() => data.value?.usage_history || []);
const maxMessages = computed(() =>
  Math.max(...history.value.map(point => Number(point.total_messages || 0)), 1)
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
    key: 'sessions',
    label: t('HUB.METRICS.SESSIONS'),
    value: formatNumber(metrics.value.sessions),
    icon: 'i-lucide-panel-top-open',
  },
  {
    key: 'user_messages',
    label: t('HUB.METRICS.USER_MESSAGES'),
    value: formatNumber(metrics.value.user_messages),
    icon: 'i-lucide-user-round',
  },
  {
    key: 'bot_messages',
    label: t('HUB.METRICS.BOT_MESSAGES'),
    value: formatNumber(metrics.value.bot_messages),
    icon: 'i-lucide-bot',
  },
  {
    key: 'users',
    label: t('HUB.METRICS.USERS'),
    value: formatNumber(metrics.value.total_users),
    icon: 'i-lucide-users',
    sub: t('HUB.PERFORMANCE.USERS_BREAKDOWN', {
      new: formatNumber(metrics.value.new_users),
      returning: formatNumber(metrics.value.returning_users),
    }),
  },
  {
    key: 'events',
    label: t('HUB.METRICS.EVENTS'),
    value: formatNumber(metrics.value.events),
    icon: 'i-lucide-mouse-pointer-click',
  },
  {
    key: 'tokens',
    label: t('HUB.METRICS.TOKENS'),
    value: formatNumber(metrics.value.llm_tokens),
    icon: 'i-lucide-cpu',
  },
  {
    key: 'llm_cost',
    label: t('HUB.METRICS.LLM_COST'),
    value: formatCurrency(metrics.value.llm_cost),
    icon: 'i-lucide-circle-dollar-sign',
  },
]);

function barHeight(point) {
  const percent = (Number(point.total_messages || 0) / maxMessages.value) * 100;
  return `${Math.max(percent, point.total_messages ? 8 : 2)}%`;
}

function openTester() {
  router.push({
    name: 'hub_tester',
    params: { accountId: route.params.accountId },
  });
}

async function loadPerformance() {
  isLoading.value = true;
  error.value = '';

  try {
    const response = await AptusHubAPI.performance(filters.value);
    data.value = response.data;
  } catch (apiError) {
    error.value = hubErrorMessage(apiError);
  } finally {
    isLoading.value = false;
  }
}

onMounted(loadPerformance);
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4">
    <div class="flex flex-wrap items-center gap-3 mb-4">
      <div class="mr-auto min-w-0">
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('HUB.PERFORMANCE.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-10">
          {{ t('HUB.PERFORMANCE.SUBTITLE') }}
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
        @click="loadPerformance"
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
      {{ t('HUB.PERFORMANCE.LOADING') }}
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
            v-if="data.bot.ai_model"
            class="inline-flex items-center h-7 px-2 rounded-md text-xs font-medium bg-n-slate-3 text-n-slate-11"
          >
            {{ data.bot.ai_model }}
          </span>
          <span
            class="inline-flex items-center h-7 px-2 rounded-md text-xs font-medium bg-n-teal-3 text-n-teal-11"
          >
            {{ statusLabel }}
          </span>
          <button
            class="inline-flex items-center gap-2 h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 border border-n-weak hover:bg-n-alpha-2"
            @click="openTester"
          >
            <i class="i-lucide-square-play w-4 h-4" />
            {{ t('HUB.NAV.TEST') }}
          </button>
        </div>
      </section>

      <section
        class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7 mb-4"
      >
        <div
          v-for="stat in stats"
          :key="stat.key"
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
          <div v-if="stat.sub" class="mt-1 text-xs text-n-slate-9">
            {{ stat.sub }}
          </div>
        </div>
      </section>

      <section
        class="mb-4 rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4"
      >
        <div class="flex items-center justify-between gap-3 mb-4">
          <h3 class="text-sm font-semibold text-n-slate-12">
            {{ t('HUB.PERFORMANCE.HISTORY') }}
          </h3>
          <span class="text-xs text-n-slate-9">
            {{ t('HUB.PERFORMANCE.TOTAL_MESSAGES') }}
          </span>
        </div>

        <div
          v-if="history.length"
          class="h-52 flex items-end gap-2 border-b border-n-weak pb-2"
        >
          <div
            v-for="point in history"
            :key="point.label"
            class="flex-1 min-w-8 h-full flex flex-col justify-end gap-2"
          >
            <div
              class="rounded-t bg-n-brand/70 min-h-1 transition-all"
              :style="{ height: barHeight(point) }"
              :title="formatNumber(point.total_messages)"
            />
            <span class="text-[11px] text-center text-n-slate-9 truncate">
              {{ point.label }}
            </span>
          </div>
        </div>
        <div v-else class="py-8 text-sm text-n-slate-10">
          {{ t('HUB.PERFORMANCE.EMPTY_HISTORY') }}
        </div>
      </section>

      <section
        class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2"
      >
        <div class="px-4 py-3 border-b border-n-weak">
          <h3 class="text-sm font-semibold text-n-slate-12">
            {{ t('HUB.PERFORMANCE.CHANNELS') }}
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
              {{ t('HUB.PERFORMANCE.CONNECTED') }}
            </span>
          </div>
        </div>
        <div v-else class="px-4 py-6 text-sm text-n-slate-10">
          {{ t('HUB.PERFORMANCE.NO_CHANNELS') }}
        </div>
      </section>
    </template>
  </div>
</template>
