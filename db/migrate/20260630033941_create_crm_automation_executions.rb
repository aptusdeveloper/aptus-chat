class CreateCrmAutomationExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_automation_executions, id: :uuid do |t|
      t.references :crm_automation_rule, null: false, foreign_key: true, type: :uuid
      t.references :crm_deal, null: false, foreign_key: true, type: :uuid
      t.string :trigger_type, null: false
      t.string :status, null: false
      t.datetime :executed_at, null: false
      t.text :error_message
      t.timestamps
    end

    add_index :crm_automation_executions, [:crm_deal_id, :executed_at]
    add_index :crm_automation_executions, [:crm_automation_rule_id, :status]
    add_index :crm_automation_executions,
              [:crm_deal_id, :crm_automation_rule_id, :executed_at],
              name: 'idx_crm_executions_idempotency'
  end
end
