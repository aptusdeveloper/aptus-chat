json.payload do
  json.partial! 'api/v1/accounts/crm_automation_rules/partials/crm_automation_rule', formats: [:json], resource: @crm_automation_rule
end
