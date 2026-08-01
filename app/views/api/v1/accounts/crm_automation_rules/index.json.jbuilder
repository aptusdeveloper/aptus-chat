json.payload do
  json.array! @crm_automation_rules do |rule|
    json.partial! 'api/v1/accounts/crm_automation_rules/partials/crm_automation_rule',
                  formats: [:json], resource: rule,
                  pipelines_by_id: @pipelines_by_id, stages_by_id: @stages_by_id
  end
end
