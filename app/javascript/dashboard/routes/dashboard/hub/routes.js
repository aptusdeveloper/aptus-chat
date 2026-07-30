import { frontendURL } from '../../../helper/URLHelper';
import HubLayout from 'dashboard/components-next/Hub/HubLayout.vue';
import HubPerformance from 'dashboard/components-next/Hub/HubPerformance.vue';
import HubTester from 'dashboard/components-next/Hub/HubTester.vue';
import HubPayments from 'dashboard/components-next/Hub/HubPayments.vue';
import HubPaymentDetails from 'dashboard/components-next/Hub/HubPaymentDetails.vue';
import AgendaProfessionalsSettings from 'dashboard/components-next/Hub/Agenda/AgendaProfessionalsSettings.vue';
import AgendaEventTypesSettings from 'dashboard/components-next/Hub/Agenda/AgendaEventTypesSettings.vue';
import AgendaCalendar from 'dashboard/components-next/Hub/Agenda/AgendaCalendar.vue';

const commonMeta = {
  permissions: ['administrator', 'agent'],
};

const adminMeta = {
  permissions: ['administrator'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/hub'),
    component: HubLayout,
    name: 'hub',
    meta: commonMeta,
    redirect: { name: 'hub_performance' },
    children: [
      {
        path: '',
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
        meta: adminMeta,
      },
      {
        path: 'agenda',
        component: AgendaProfessionalsSettings,
        name: 'hub_agenda_professionals',
        meta: commonMeta,
      },
      {
        path: 'agenda/event-types',
        component: AgendaEventTypesSettings,
        name: 'hub_agenda_event_types',
        meta: adminMeta,
      },
      {
        path: 'agenda/appointments',
        component: AgendaCalendar,
        name: 'hub_agenda_appointments',
        meta: commonMeta,
      },
    ],
  },
  {
    path: frontendURL('accounts/:accountId/hub/payments/:month'),
    component: HubPaymentDetails,
    name: 'hub_payment_details',
    meta: adminMeta,
  },
];
