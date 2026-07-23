import crmAutomationRulesAPI from '../crm/automationRules';
import ApiClient from '../ApiClient';

describe('#CrmAutomationRulesAPI', () => {
  it('creates correct instance', () => {
    expect(crmAutomationRulesAPI).toBeInstanceOf(ApiClient);
    expect(crmAutomationRulesAPI).toHaveProperty('get');
    expect(crmAutomationRulesAPI).toHaveProperty('show');
    expect(crmAutomationRulesAPI).toHaveProperty('create');
    expect(crmAutomationRulesAPI).toHaveProperty('update');
    expect(crmAutomationRulesAPI).toHaveProperty('delete');
    expect(crmAutomationRulesAPI).toHaveProperty('clone');
    expect(crmAutomationRulesAPI.url).toBe('/api/v1/crm_automation_rules');
  });
});
