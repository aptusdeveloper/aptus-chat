import { frontendURL } from '../../../helper/URLHelper';
import HubLayout from 'dashboard/components-next/Hub/HubLayout.vue';
import HubOverview from 'dashboard/components-next/Hub/HubOverview.vue';
import HubPerformance from 'dashboard/components-next/Hub/HubPerformance.vue';
import HubTester from 'dashboard/components-next/Hub/HubTester.vue';
import HubPayments from 'dashboard/components-next/Hub/HubPayments.vue';

const commonMeta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/hub'),
    component: HubLayout,
    name: 'hub',
    meta: commonMeta,
    redirect: { name: 'hub_overview' },
    children: [
      {
        path: '',
        component: HubOverview,
        name: 'hub_overview',
        meta: commonMeta,
      },
      {
        path: 'performance',
        component: HubPerformance,
        name: 'hub_performance',
        meta: commonMeta,
      },
      {
        path: 'test',
        component: HubTester,
        name: 'hub_tester',
        meta: commonMeta,
      },
      {
        path: 'payments',
        component: HubPayments,
        name: 'hub_payments',
        meta: commonMeta,
      },
    ],
  },
];
