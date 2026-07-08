class CreateCrmAutomationRules < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_automation_rules, id: :uuid do |t|
      t.bigint :account_id, null: false
      t.references :crm_pipeline, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :trigger_type, null: false
      t.jsonb :conditions, null: false, default: []
      t.jsonb :actions, null: false, default: []
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :crm_automation_rules, [:account_id, :active]
    add_index :crm_automation_rules, :trigger_type
    add_index :crm_automation_rules, :conditions, using: :gin
  end
end
