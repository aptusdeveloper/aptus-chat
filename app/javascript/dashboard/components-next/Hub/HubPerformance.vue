<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AptusHubAPI from 'dashboard/api/aptusHub';
import { currentMonthRange, formatNumber, hubErrorMessage } from './utils';

const { t } = useI18n();
const range = currentMonthRange();
const filters = ref({ ...range });
const data = ref(null);
const isLoading = ref(false);
const error = ref('');

const metrics = computed(() => data.value?.metrics || {});
const history = computed(() => data.value?.usage_history || []);
const maxMessages = computed(() =>
  Math.max(...history.value.map(point => Number(point.total_messages || 0)), 1)
);

const stats = computed(() => [
  [
    t('HUB.METRICS.SESSIONS'),
    metrics.value.sessions,
    'i-lucide-panel-top-open',
  ],
  [
    t('HUB.METRICS.USER_MESSAGES'),
    metrics.value.user_messages,
    'i-lucide-user-round',
  ],
  [t('HUB.METRICS.BOT_MESSAGES'), metrics.value.bot_messages, 'i-lucide-bot'],
  [t('HUB.METRICS.USERS'), metrics.value.total_users, 'i-lucide-users'],
  [
    t('HUB.METRICS.EVENTS'),
    metrics.value.events,
    'i-lucide-mouse-pointer-click',
  ],
]);

function barHeight(point) {
  const percent = (Number(point.total_messages || 0) / maxMessages.value) * 100;
  return `${Math.max(percent, point.total_messages ? 8 : 2)}%`;
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
      <section class="grid gap-3 sm:grid-cols-2 xl:grid-cols-5 mb-4">
        <div
          v-for="[label, value, icon] in stats"
          :key="label"
          class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4 min-h-24"
        >
          <div
            class="flex items-center gap-2 text-xs font-medium text-n-slate-9"
          >
            <i class="w-4 h-4" :class="icon" />
            {{ label }}
          </div>
          <div class="mt-3 text-2xl font-semibold text-n-slate-12">
            {{ formatNumber(value) }}
          </div>
        </div>
      </section>

      <section
        class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4"
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
    </template>
  </div>
</template>
