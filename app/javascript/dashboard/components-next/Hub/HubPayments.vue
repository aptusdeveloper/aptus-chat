<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import AptusHubAPI from 'dashboard/api/aptusHub';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  formatCurrency,
  formatDate,
  formatMonthLabel,
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

function openDetails(month) {
  router.push({
    name: 'hub_payment_details',
    params: { accountId: route.params.accountId, month },
  });
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
      <Button
        ghost
        slate
        icon="i-lucide-refresh-cw"
        :label="t('HUB.ACTIONS.REFRESH')"
        :is-loading="isLoading"
        @click="loadPayments"
      />
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

      <h3 class="text-sm font-semibold text-n-slate-12 mb-2">
        {{ t('HUB.PAYMENTS.LAST_MONTHS') }}
      </h3>

      <div
        v-if="history.length"
        class="overflow-hidden rounded-lg border border-n-weak bg-white dark:bg-n-solid-2"
      >
        <table class="w-full text-sm">
          <thead class="bg-n-alpha-1 text-xs uppercase text-n-slate-9">
            <tr>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('HUB.PAYMENTS.LIST.COLUMNS.MONTH') }}
              </th>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('HUB.PAYMENTS.LIST.COLUMNS.VALUE') }}
              </th>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('HUB.PAYMENTS.LIST.COLUMNS.DUE_DATE') }}
              </th>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('HUB.PAYMENTS.LIST.COLUMNS.STATUS') }}
              </th>
              <th class="px-4 py-3 text-left font-semibold">
                {{ t('HUB.PAYMENTS.LIST.COLUMNS.PAID_AT') }}
              </th>
              <th class="px-4 py-3 text-right font-semibold">
                {{ t('HUB.PAYMENTS.LIST.COLUMNS.MANAGE') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="payment in history"
              :key="payment.month"
              class="border-t border-n-weak hover:bg-n-alpha-1"
            >
              <td class="px-4 py-3 font-medium text-n-slate-12 capitalize">
                {{ formatMonthLabel(payment.month) }}
              </td>
              <td class="px-4 py-3 text-n-slate-11">
                {{ formatCurrency(payment.total, payment.currency) }}
              </td>
              <td class="px-4 py-3 text-n-slate-11">
                {{ formatDate(payment.due_on) }}
              </td>
              <td class="px-4 py-3">
                <span
                  class="inline-flex items-center h-7 px-2 rounded-md text-xs font-medium"
                  :class="paymentStatusClass(payment.status)"
                >
                  {{ paymentStatusLabel(payment.status) }}
                </span>
              </td>
              <td class="px-4 py-3 text-n-slate-11">
                {{
                  payment.paid_at
                    ? formatDate(payment.paid_at.slice(0, 10))
                    : t('HUB.PAYMENTS.EMPTY_VALUE')
                }}
              </td>
              <td class="px-4 py-3">
                <div class="flex items-center justify-end">
                  <Button
                    ghost
                    slate
                    sm
                    icon="i-lucide-receipt-text"
                    :label="t('HUB.PAYMENTS.DETAILS_BUTTON')"
                    @click="openDetails(payment.month)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div
        v-else
        class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 px-4 py-6 text-sm text-n-slate-10"
      >
        {{ t('HUB.PAYMENTS.NO_PAYMENTS') }}
      </div>
    </template>
  </div>
</template>
