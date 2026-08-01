class RestructureCrmAutomationRuleTriggers < ActiveRecord::Migration[7.1]
  def up
    add_column :crm_automation_rules, :triggers, :jsonb, null: false, default: []
    add_index :crm_automation_rules, :triggers, using: :gin

    backfill_triggers

    remove_foreign_key :crm_automation_rules, :crm_pipelines
    remove_index :crm_automation_rules, :crm_pipeline_id
    remove_index :crm_automation_rules, :trigger_type
    remove_column :crm_automation_rules, :crm_pipeline_id
    remove_column :crm_automation_rules, :trigger_type
  end

  def down
    add_column :crm_automation_rules, :trigger_type, :string
    add_column :crm_automation_rules, :crm_pipeline_id, :uuid

    execute(<<~SQL.squish)
      UPDATE crm_automation_rules
      SET trigger_type = triggers->0->>'trigger_type',
          crm_pipeline_id = NULLIF(triggers->0->>'crm_pipeline_id', '')::uuid
    SQL

    change_column_null :crm_automation_rules, :trigger_type, false
    add_index :crm_automation_rules, :trigger_type
    add_index :crm_automation_rules, :crm_pipeline_id
    add_foreign_key :crm_automation_rules, :crm_pipelines

    remove_index :crm_automation_rules, :triggers
    remove_column :crm_automation_rules, :triggers
  end

  private

  # Extrai o parametro de gatilho hoje sintetizado como a 1a condition (system condition)
  # gerada pelo frontend antigo, movendo-o para a nova coluna `triggers` e removendo-o
  # do array `conditions` (que passa a conter so as condicoes genuinamente do usuario).
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def backfill_triggers
    connection = ActiveRecord::Base.connection
    rows = connection.select_all('SELECT id, trigger_type, crm_pipeline_id, conditions FROM crm_automation_rules')
    deactivated_ids = []

    rows.each do |row|
      conditions = row['conditions'].is_a?(String) ? JSON.parse(row['conditions']) : Array(row['conditions'])
      trigger_type = row['trigger_type']
      stage_ids, days, remaining_conditions = extract_trigger_params(trigger_type, conditions)

      should_deactivate = trigger_type == 'deal_entered_stage' && stage_ids.empty?
      deactivated_ids << row['id'] if should_deactivate

      trigger_item = {
        trigger_type: trigger_type,
        crm_pipeline_id: row['crm_pipeline_id'],
        stage_ids: stage_ids,
        days: days
      }

      connection.exec_query(
        <<~SQL.squish,
          UPDATE crm_automation_rules
          SET triggers = $1::jsonb,
              conditions = $2::jsonb,
              active = (active AND NOT $3::boolean)
          WHERE id = $4::uuid
        SQL
        'Backfill CRM automation rule triggers',
        [
          bind_param([trigger_item].to_json),
          bind_param(remaining_conditions.to_json),
          bind_param(should_deactivate),
          bind_param(row['id'])
        ]
      )
    end

    return if deactivated_ids.empty?

    say "Deactivated #{deactivated_ids.size} deal_entered_stage rule(s) with no stage selected: #{deactivated_ids.join(', ')}"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def bind_param(value)
    ActiveRecord::Relation::QueryAttribute.new(nil, value, ActiveRecord::Type::Value.new)
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def extract_trigger_params(trigger_type, conditions)
    first = conditions.first
    system_signature = {
      'deal_entered_stage' => { attribute_key: 'crm_stage_id', filter_operator: 'equal_to' },
      'deal_stagnant' => { attribute_key: 'days_in_stage', filter_operator: 'gte' },
      'deal_close_date_approaching' => { attribute_key: 'close_date', filter_operator: 'days_before' }
    }[trigger_type]

    unless system_signature && first &&
           first['attribute_key'] == system_signature[:attribute_key] &&
           first['filter_operator'] == system_signature[:filter_operator]
      return [[], nil, conditions]
    end

    remaining_conditions = conditions[1..] || []
    if trigger_type == 'deal_entered_stage'
      [Array(first['values']).compact, nil, remaining_conditions]
    else
      [[], first['values']&.first, remaining_conditions]
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
