<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import AptusHubAPI from 'dashboard/api/aptusHub';
import {
  formatCurrency,
  formatDate,
  formatMonthLabel,
  formatNumber,
  hubErrorMessage,
  paymentStatusClass,
  paymentStatusLabel,
} from './utils';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const data = ref(null);
const isLoading = ref(false);
const error = ref('');

const month = computed(() => route.params.month);
const costs = computed(() => data.value?.costs || {});
const isProrated = computed(
  () => costs.value.monthly_fee_billed_days < costs.value.monthly_fee_month_days
);
const metrics = computed(() => data.value?.metrics || {});

const metricStats = computed(() => [
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
]);

async function loadDetails() {
  isLoading.value = true;
  error.value = '';

  try {
    const response = await AptusHubAPI.paymentDetails(month.value);
    data.value = response.data;
  } catch (apiError) {
    error.value = hubErrorMessage(apiError);
  } finally {
    isLoading.value = false;
  }
}

function goBack() {
  router.push({
    name: 'hub_payments',
    params: { accountId: route.params.accountId },
  });
}

onMounted(loadDetails);
</script>

<template>
  <div class="h-full w-full overflow-y-auto p-6">
    <div class="max-w-3xl mx-auto">
      <button
        class="inline-flex items-center gap-2 h-8 px-3 mb-4 rounded-lg text-sm font-medium text-n-slate-11 border border-n-weak hover:bg-n-alpha-2"
        @click="goBack"
      >
        <i class="i-lucide-arrow-left w-4 h-4" />
        {{ t('HUB.PAYMENTS.DETAILS.BACK') }}
      </button>

      <div class="flex flex-wrap items-center gap-3 mb-6">
        <div class="mr-auto min-w-0">
          <h2 class="text-lg font-semibold text-n-slate-12 capitalize">
            {{ formatMonthLabel(month) }}
          </h2>
          <p class="text-sm text-n-slate-10">
            {{ t('HUB.PAYMENTS.DETAILS.SUBTITLE') }}
          </p>
        </div>
        <span
          v-if="data"
          class="inline-flex items-center h-7 px-2 rounded-md text-xs font-medium"
          :class="paymentStatusClass(data.status)"
        >
          {{ paymentStatusLabel(data.status) }}
        </span>
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
        {{ t('HUB.PAYMENTS.DETAILS.LOADING') }}
      </div>

      <template v-else-if="data">
        <section
          class="mb-4 rounded-lg border border-n-weak bg-white dark:bg-n-solid-2"
        >
          <div class="px-4 py-3 border-b border-n-weak">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('HUB.PAYMENTS.DETAILS.COSTS') }}
            </h3>
          </div>
          <div class="divide-y divide-n-weak text-sm">
            <div class="flex items-center justify-between px-4 py-3">
              <span class="text-n-slate-10">
                {{ t('HUB.PAYMENTS.DETAILS.LLM_COST') }}
              </span>
              <span class="text-n-slate-12">
                {{ formatCurrency(costs.llm_cost_usd, 'USD') }}
              </span>
            </div>
            <div class="flex items-center justify-between px-4 py-3">
              <span class="text-n-slate-10">
                {{ t('HUB.PAYMENTS.DETAILS.BOT_FIXED_COST') }}
              </span>
              <span class="text-n-slate-12">
                {{ formatCurrency(costs.bot_fixed_cost_usd, 'USD') }}
              </span>
            </div>
            <div class="flex items-center justify-between px-4 py-3">
              <span class="text-n-slate-10">
                {{ t('HUB.PAYMENTS.DETAILS.API_SUBTOTAL') }}
              </span>
              <span class="text-n-slate-12 font-medium">
                {{ formatCurrency(costs.api_cost_usd, 'USD') }}
              </span>
            </div>
            <div class="flex items-center justify-between px-4 py-3">
              <span class="text-n-slate-10">
                {{ t('HUB.PAYMENTS.DETAILS.EXCHANGE_RATE') }}
              </span>
              <span
                class="text-n-slate-12"
                :title="
                  costs.rate_is_live
                    ? t('HUB.PAYMENTS.DETAILS.EXCHANGE_RATE_LIVE_HINT')
                    : null
                "
              >
                {{ formatNumber(costs.usd_brl_rate) }}
                <i
                  v-if="costs.rate_is_live"
                  class="i-lucide-info w-3.5 h-3.5 text-n-slate-8 inline-block align-text-top ml-1"
                />
              </span>
            </div>
            <div class="flex items-center justify-between px-4 py-3">
              <span class="text-n-slate-10">
                {{ t('HUB.PAYMENTS.DETAILS.API_COST_BRL') }}
              </span>
              <span class="text-n-slate-12 font-medium">
                {{ formatCurrency(costs.api_cost_brl, 'BRL') }}
              </span>
            </div>
            <div class="flex items-center justify-between px-4 py-3">
              <span class="text-n-slate-10">
                {{ t('HUB.PAYMENTS.DETAILS.MONTHLY_FEE') }}
                <span v-if="isProrated" class="text-n-slate-9">
                  {{
                    t('HUB.PAYMENTS.DETAILS.MONTHLY_FEE_PRORATED', {
                      billed: costs.monthly_fee_billed_days,
                      total: costs.monthly_fee_month_days,
                    })
                  }}
                </span>
              </span>
              <span class="text-n-slate-12">
                {{ formatCurrency(costs.monthly_fee, costs.currency) }}
              </span>
            </div>
            <div class="flex items-center justify-between px-4 py-3">
              <span class="text-n-slate-12 font-semibold">
                {{ t('HUB.PAYMENTS.DETAILS.TOTAL') }}
              </span>
              <span class="text-n-slate-12 font-semibold">
                {{ formatCurrency(costs.total, costs.currency) }}
              </span>
            </div>
          </div>
          <div
            v-if="data.paid_at"
            class="px-4 py-3 border-t border-n-weak text-xs text-n-slate-9"
          >
            {{
              t('HUB.PAYMENTS.DUE_ON', {
                date: formatDate(data.paid_at.slice(0, 10)),
              })
            }}
          </div>
        </section>

        <section
          class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4"
        >
          <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ t('HUB.PAYMENTS.DETAILS.METRICS') }}
          </h3>
          <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <div
              v-for="stat in metricStats"
              :key="stat.key"
              class="rounded-lg border border-n-weak p-4 min-h-24"
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
          </div>
        </section>
      </template>
    </div>
  </div>
</template>
