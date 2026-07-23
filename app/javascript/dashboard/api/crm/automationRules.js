/* global axios */
import ApiClient from '../ApiClient';

class CrmAutomationRulesAPI extends ApiClient {
  constructor() {
    super('crm_automation_rules', { accountScoped: true });
  }

  clone(id) {
    return axios.post(`${this.url}/${id}/clone`);
  }
}

export default new CrmAutomationRulesAPI();
