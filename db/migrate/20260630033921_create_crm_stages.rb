class CreateCrmStages < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_stages, id: :uuid do |t|
      t.references :crm_pipeline, null: false, foreign_key: true, type: :uuid
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :color, default: '#6B7280'
      t.float :position, null: false, default: 0.0
      t.boolean :is_win, null: false, default: false
      t.boolean :is_loss, null: false, default: false
      t.timestamps
    end

    add_index :crm_stages, :account_id
    add_index :crm_stages, [:crm_pipeline_id, :position]
  end
end
