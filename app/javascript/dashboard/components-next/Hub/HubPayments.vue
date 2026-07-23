<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AptusHubAPI from 'dashboard/api/aptusHub';
import {
  formatCurrency,
  formatDate,
  hubErrorMessage,
  paymentStatusClass,
  paymentStatusLabel,
} from './utils';

const { t } = useI18n();
const data = ref(null);
const isLoading = ref(false);
const error = ref('');

const plan = computed(() => data.value?.plan || {});
const currentMonth = computed(() => data.value?.current_month || {});
const history = computed(() => data.value?.history || []);

async function loadPayments() {
  isLoading.value = true;
  error.value = '';

  try {
    const response = await AptusHubAPI.payments();
    data.value = response.data;
  } catch (apiError) {
    error.value = hubErrorMessage(apiError);
  } finally {
    isLoading.value = false;
  }
}

onMounted(loadPayments);
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4">
    <div class="flex items-center gap-3 mb-4">
      <div class="mr-auto min-w-0">
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('HUB.PAYMENTS.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-10">
          {{ t('HUB.PAYMENTS.SUBTITLE') }}
        </p>
      </div>
      <button
        class="inline-flex items-center gap-2 h-9 px-3 rounded-lg text-sm font-medium text-n-slate-11 border border-n-weak hover:bg-n-alpha-2 disabled:opacity-60"
        :disabled="isLoading"
        @click="loadPayments"
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
      {{ t('HUB.PAYMENTS.LOADING') }}
    </div>

    <template v-else-if="data">
      <section class="grid gap-3 md:grid-cols-3 mb-4">
        <div
          class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4"
        >
          <div class="text-xs font-medium text-n-slate-9">
            {{ t('HUB.PAYMENTS.MONTHLY_PLAN') }}
          </div>
          <div class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ formatCurrency(plan.monthly_fee, plan.currency) }}
          </div>
        </div>
        <div
          class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4"
        >
          <div class="text-xs font-medium text-n-slate-9">
            {{ t('HUB.PAYMENTS.DUE_DAY') }}
          </div>
          <div class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ t('HUB.PAYMENTS.DAY', { day: plan.payment_day }) }}
          </div>
        </div>
        <div
          class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4"
        >
          <div class="text-xs font-medium text-n-slate-9">
            {{ t('HUB.PAYMENTS.CURRENT_MONTH') }}
          </div>
          <div class="mt-3">
            <span
              class="inline-flex items-center h-7 px-2 rounded-md text-xs font-medium"
              :class="paymentStatusClass(currentMonth.status)"
            >
              {{ paymentStatusLabel(currentMonth.status) }}
            </span>
          </div>
        </div>
      </section>

      <section
        class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2"
      >
        <div class="px-4 py-3 border-b border-n-weak">
          <h3 class="text-sm font-semibold text-n-slate-12">
            {{ t('HUB.PAYMENTS.LAST_MONTHS') }}
          </h3>
        </div>

        <div v-if="history.length" class="divide-y divide-n-weak">
          <div
            v-for="payment in history"
            :key="payment.month"
            class="grid grid-cols-[1fr_auto_auto] items-center gap-3 px-4 py-3"
          >
            <div class="min-w-0">
              <p class="text-sm font-medium text-n-slate-12">
                {{ payment.month }}
              </p>
              <p class="text-xs text-n-slate-9">
                {{
                  t('HUB.PAYMENTS.DUE_ON', { date: formatDate(payment.due_on) })
                }}
              </p>
            </div>
            <span
              class="inline-flex items-center h-7 px-2 rounded-md text-xs font-medium"
              :class="paymentStatusClass(payment.status)"
            >
              {{ paymentStatusLabel(payment.status) }}
            </span>
            <span class="text-xs text-n-slate-9 min-w-24 text-right">
              {{
                payment.paid_at
                  ? formatDate(payment.paid_at.slice(0, 10))
                  : t('HUB.PAYMENTS.EMPTY_VALUE')
              }}
            </span>
          </div>
        </div>
        <div v-else class="px-4 py-6 text-sm text-n-slate-10">
          {{ t('HUB.PAYMENTS.NO_PAYMENTS') }}
        </div>
      </section>
    </template>
  </div>
</template>
