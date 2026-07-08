class CreateCrmDeals < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_deals, id: :uuid do |t|
      t.bigint :account_id, null: false
      t.references :crm_pipeline, null: false, foreign_key: true, type: :uuid
      t.references :crm_stage, null: false, foreign_key: true, type: :uuid
      t.bigint :contact_id
      t.bigint :assignee_id
      t.string :name, null: false
      t.decimal :amount, precision: 15, scale: 2
      t.string :currency, null: false, default: 'BRL'
      t.date :close_date
      t.integer :probability
      t.float :position, null: false, default: 0.0
      t.jsonb :custom_attributes, null: false, default: {}
      t.datetime :stage_entered_at
      t.timestamps
    end

    add_index :crm_deals, :account_id
    add_index :crm_deals, [:account_id, :crm_stage_id]
    add_index :crm_deals, [:account_id, :close_date]
    add_index :crm_deals, [:account_id, :stage_entered_at]
    add_index :crm_deals, :contact_id
    add_index :crm_deals, :assignee_id
    add_index :crm_deals, :custom_attributes, using: :gin
  end
end
