json.id resource.id
json.name resource.name
json.active resource.active
json.conditions resource.conditions
json.actions resource.actions
json.actions_count resource.actions.length

json.triggers resource.triggers do |trigger|
  trigger = trigger.with_indifferent_access
  json.trigger_type trigger[:trigger_type]
  json.crm_pipeline_id trigger[:crm_pipeline_id]
  json.stage_ids trigger[:stage_ids] || []
  json.days trigger[:days]
  json.crm_pipeline_name pipelines_by_id[trigger[:crm_pipeline_id]]&.name
  json.stage_names Array(trigger[:stage_ids]).filter_map { |id| stages_by_id[id]&.name }
end

json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
