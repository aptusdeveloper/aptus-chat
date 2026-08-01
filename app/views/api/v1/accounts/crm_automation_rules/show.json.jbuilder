json.payload do
  json.partial! 'api/v1/accounts/crm_automation_rules/partials/crm_automation_rule',
                formats: [:json], resource: @crm_automation_rule,
                pipelines_by_id: @pipelines_by_id, stages_by_id: @stages_by_id
end
