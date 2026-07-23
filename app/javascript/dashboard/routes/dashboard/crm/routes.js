import { frontendURL } from '../../../helper/URLHelper';
import CrmLayout from 'dashboard/components-next/Crm/CrmLayout.vue';
import CrmBoard from 'dashboard/components-next/Crm/CrmBoard.vue';
import CrmAutomationsIndex from 'dashboard/components-next/Crm/automations/CrmAutomationsIndex.vue';
import CrmAutomationForm from 'dashboard/components-next/Crm/automations/CrmAutomationForm.vue';

const commonMeta = {
  permissions: ['administrator', 'agent'],
};

const automationMeta = {
  permissions: ['administrator'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    component: CrmLayout,
    name: 'crm',
    meta: commonMeta,
    redirect: { name: 'crm_kanban' },
    children: [
      {
        path: '',
        component: CrmBoard,
        name: 'crm_kanban',
        meta: commonMeta,
      },
      {
        path: 'automations',
        component: CrmAutomationsIndex,
        name: 'crm_automations',
        meta: automationMeta,
      },
      {
        path: 'automations/new',
        component: CrmAutomationForm,
        name: 'crm_automation_new',
        meta: automationMeta,
      },
      {
        path: 'automations/:automationId',
        component: CrmAutomationForm,
        name: 'crm_automation_edit',
        meta: automationMeta,
      },
    ],
  },
];
