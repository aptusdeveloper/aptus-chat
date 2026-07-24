<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { useAdmin } from 'dashboard/composables/useAdmin';
import AptusHubAPI from 'dashboard/api/aptusHub';
import {
  formatCurrency,
  formatDate,
  formatHour,
  formatNumber,
  formatShortDate,
  formatWeekday,
  hubErrorMessage,
  presetDayRange,
} from './utils';

const CHART_METRICS = [
  { key: 'total_messages', labelKey: 'HUB.PERFORMANCE.CHART.MESSAGES' },
  { key: 'sessions', labelKey: 'HUB.PERFORMANCE.CHART.SESSIONS' },
  { key: 'total_users', labelKey: 'HUB.PERFORMANCE.CHART.USERS' },
  {
    key: 'llm_cost',
    labelKey: 'HUB.PERFORMANCE.CHART.COST',
    currency: 'USD',
  },
];

const CHART_TOP_PADDING = 20;
const CHART_BOTTOM_PADDING = 10;
const CHART_SIDE_PADDING = 2;
const CHART_SHORT_RANGE_THRESHOLD = 7;

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const { isAdmin } = useAdmin();

const PRESETS = [
  { key: 'today', days: 1, labelKey: 'HUB.PERFORMANCE.FILTER.TODAY' },
  { key: 'last_7d', days: 7, labelKey: 'HUB.PERFORMANCE.FILTER.LAST_7_DAYS' },
  {
    key: 'last_30d',
    days: 30,
    labelKey: 'HUB.PERFORMANCE.FILTER.LAST_30_DAYS',
  },
];

const presets = computed(() =>
  PRESETS.map(preset => ({ ...preset, label: t(preset.labelKey) }))
);

const activePreset = ref('last_30d');
const filters = ref(presetDayRange(30));
const data = ref(null);
const isLoading = ref(false);
const error = ref('');

const showCustomPopover = ref(false);
const draftFrom = ref(filters.value.from);
const draftTo = ref(filters.value.to);

const metrics = computed(() => data.value?.metrics || {});
const channels = computed(() => data.value?.channels || []);
const history = computed(() => data.value?.usage_history || []);

const activeMetricKey = ref('total_messages');

const chartMetrics = computed(() =>
  CHART_METRICS.filter(
    metric => isAdmin.value || metric.key !== 'llm_cost'
  ).map(metric => ({ ...metric, label: t(metric.labelKey) }))
);

const activeMetric = computed(() =>
  chartMetrics.value.find(metric => metric.key === activeMetricKey.value)
);

function metricValue(point) {
  return Number(point[activeMetricKey.value] || 0);
}

function formatMetricValue(value) {
  return activeMetric.value.currency
    ? formatCurrency(value, activeMetric.value.currency)
    : formatNumber(value);
}

const chartMax = computed(() => Math.max(...history.value.map(metricValue), 1));

const chartPoints = computed(() => {
  const points = history.value;
  const count = points.length;
  if (count < 2) return [];

  const usableWidth = 100 - CHART_SIDE_PADDING * 2;
  const usableHeight = 100 - CHART_TOP_PADDING - CHART_BOTTOM_PADDING;

  return points.map((point, index) => {
    const value = metricValue(point);
    const x = CHART_SIDE_PADDING + (index / (count - 1)) * usableWidth;
    const y =
      100 - CHART_BOTTOM_PADDING - (value / chartMax.value) * usableHeight;
    return { x, y, value, point };
  });
});

const linePath = computed(() =>
  chartPoints.value.map(point => `${point.x},${point.y}`).join(' ')
);

const areaPath = computed(() => {
  if (!chartPoints.value.length) return '';
  const first = chartPoints.value[0];
  const last = chartPoints.value[chartPoints.value.length - 1];
  return `${first.x},100 ${linePath.value} ${last.x},100`;
});

const isHourlyBreakdown = computed(() => {
  const dates = history.value.map(point => point.date).filter(Boolean);
  return dates.length > 1 && new Set(dates).size === 1;
});

function chartLabel(point) {
  if (isHourlyBreakdown.value) {
    return point.bucket_start ? formatHour(point.bucket_start) : '';
  }

  if (!point.date) return '';
  return history.value.length <= CHART_SHORT_RANGE_THRESHOLD
    ? formatWeekday(point.date)
    : formatShortDate(point.date);
}

const singlePointValue = computed(() => {
  if (history.value.length !== 1) return 0;
  return metricValue(history.value[0]);
});

const statusLabel = computed(() => {
  const labels = {
    active: 'Ativo',
    paused: 'Pausado',
    cancelled: 'Cancelado',
  };
  return labels[data.value?.bot?.status] || 'Ativo';
});

const stats = computed(() => {
  const allStats = [
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
      value: formatCurrency(metrics.value.llm_cost, 'USD'),
      icon: 'i-lucide-circle-dollar-sign',
    },
  ];

  return isAdmin.value
    ? allStats
    : allStats.filter(stat => stat.key !== 'llm_cost');
});

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

function selectPreset(preset) {
  activePreset.value = preset.key;
  showCustomPopover.value = false;
  filters.value = presetDayRange(preset.days);
  loadPerformance();
}

function toggleCustomPopover() {
  if (showCustomPopover.value) {
    showCustomPopover.value = false;
    return;
  }

  draftFrom.value = filters.value.from;
  draftTo.value = filters.value.to;
  showCustomPopover.value = true;
}

function closeCustomPopover() {
  showCustomPopover.value = false;
}

function applyCustomRange() {
  activePreset.value = 'custom';
  filters.value = { from: draftFrom.value, to: draftTo.value };
  showCustomPopover.value = false;
  loadPerformance();
}

onMounted(loadPerformance);
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4">
    <div class="mb-4">
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ t('HUB.PERFORMANCE.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-10">
        {{ t('HUB.PERFORMANCE.SUBTITLE') }}
      </p>
    </div>

    <section
      v-if="data"
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

    <div class="mb-4 flex flex-wrap items-center gap-3">
      <div
        class="inline-flex items-center gap-1 rounded-lg border border-n-weak bg-n-solid-1 p-1"
      >
        <button
          v-for="preset in presets"
          :key="preset.key"
          type="button"
          class="h-8 px-3 rounded-md text-sm font-medium transition-colors"
          :class="
            activePreset === preset.key
              ? 'bg-n-solid-3 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'
          "
          @click="selectPreset(preset)"
        >
          {{ preset.label }}
        </button>
        <div class="relative">
          <button
            type="button"
            class="h-8 px-3 rounded-md text-sm font-medium transition-colors"
            :class="
              activePreset === 'custom'
                ? 'bg-n-solid-3 text-n-slate-12 shadow-sm'
                : 'text-n-slate-10 hover:text-n-slate-12'
            "
            @click="toggleCustomPopover"
          >
            {{ t('HUB.PERFORMANCE.FILTER.CUSTOM') }}
          </button>

          <div
            v-if="showCustomPopover"
            v-on-click-outside="closeCustomPopover"
            class="absolute z-20 top-full mt-2 ltr:left-0 rtl:right-0 w-64 rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-3 shadow-lg"
          >
            <div class="flex flex-col gap-3">
              <div>
                <label class="block mb-1 text-xs font-medium text-n-slate-11">
                  {{ t('HUB.PERFORMANCE.FILTER.FROM') }}
                </label>
                <input
                  v-model="draftFrom"
                  type="date"
                  class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
                />
              </div>
              <div>
                <label class="block mb-1 text-xs font-medium text-n-slate-11">
                  {{ t('HUB.PERFORMANCE.FILTER.TO') }}
                </label>
                <input
                  v-model="draftTo"
                  type="date"
                  class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
                />
              </div>
              <div class="flex justify-end gap-2">
                <button
                  type="button"
                  class="h-8 px-3 rounded-lg text-sm font-medium text-n-slate-11 hover:bg-n-alpha-2"
                  @click="closeCustomPopover"
                >
                  {{ t('HUB.PERFORMANCE.FILTER.CANCEL') }}
                </button>
                <button
                  type="button"
                  class="h-8 px-3 rounded-lg text-sm font-medium bg-n-brand text-white hover:opacity-90"
                  @click="applyCustomRange"
                >
                  {{ t('HUB.PERFORMANCE.FILTER.APPLY') }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <span class="text-xs text-n-slate-9">
        {{ formatDate(filters.from) }} – {{ formatDate(filters.to) }}
      </span>

      <button
        class="inline-flex items-center gap-2 h-9 px-3 rounded-lg text-sm font-medium text-n-slate-11 border border-n-weak hover:bg-n-alpha-2 ml-auto disabled:opacity-60"
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
      class="mb-4 flex items-center gap-2 text-sm text-n-slate-10"
    >
      <i class="i-lucide-loader-2 w-4 h-4 animate-spin" />
      {{ t('HUB.PERFORMANCE.LOADING') }}
    </div>

    <template v-else-if="data">
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
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <h3 class="text-sm font-semibold text-n-slate-12">
            {{ t('HUB.PERFORMANCE.HISTORY') }}
          </h3>
          <div
            class="inline-flex items-center gap-1 rounded-lg border border-n-weak bg-n-solid-1 p-1"
          >
            <button
              v-for="metric in chartMetrics"
              :key="metric.key"
              type="button"
              class="h-7 px-2.5 rounded-md text-xs font-medium transition-colors"
              :class="
                activeMetricKey === metric.key
                  ? 'bg-n-solid-3 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-10 hover:text-n-slate-12'
              "
              @click="activeMetricKey = metric.key"
            >
              {{ metric.label }}
            </button>
          </div>
        </div>

        <div v-if="chartPoints.length">
          <div class="relative h-60">
            <svg
              viewBox="0 0 100 100"
              preserveAspectRatio="none"
              class="absolute inset-0 w-full h-full"
            >
              <polygon :points="areaPath" class="fill-n-brand/10" />
              <polyline
                :points="linePath"
                class="fill-none stroke-n-brand"
                stroke-width="2"
                stroke-linejoin="round"
                stroke-linecap="round"
                vector-effect="non-scaling-stroke"
              />
            </svg>
            <div
              v-for="(point, index) in chartPoints"
              :key="index"
              class="absolute text-[10px] font-medium text-n-slate-11 -translate-x-1/2 -translate-y-full whitespace-nowrap"
              :style="{ left: `${point.x}%`, top: `calc(${point.y}% - 6px)` }"
            >
              {{ formatMetricValue(point.value) }}
            </div>
            <div
              v-for="(point, index) in chartPoints"
              :key="index"
              class="absolute size-1.5 rounded-full bg-n-brand -translate-x-1/2 -translate-y-1/2"
              :style="{ left: `${point.x}%`, top: `${point.y}%` }"
            />
          </div>
          <div class="flex mt-2">
            <span
              v-for="(point, index) in chartPoints"
              :key="index"
              class="flex-1 text-[11px] text-center text-n-slate-9 truncate"
            >
              {{ chartLabel(point.point) }}
            </span>
          </div>
        </div>
        <div
          v-else-if="history.length === 1"
          class="py-8 flex flex-col items-center justify-center gap-1"
        >
          <span class="text-3xl font-semibold text-n-slate-12">
            {{ formatMetricValue(singlePointValue) }}
          </span>
          <span class="text-xs text-n-slate-9">
            {{ activeMetric.label }} · {{ formatDate(filters.from) }} –
            {{ formatDate(filters.to) }}
          </span>
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
