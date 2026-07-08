import { frontendURL } from '../../../helper/URLHelper';
import CrmBoard from 'dashboard/components-next/Crm/CrmBoard.vue';

const commonMeta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    component: CrmBoard,
    name: 'crm_kanban',
    meta: commonMeta,
  },
];
