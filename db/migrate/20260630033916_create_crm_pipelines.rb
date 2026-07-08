class CreateCrmPipelines < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_pipelines, id: :uuid do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.float :position, null: false, default: 0.0
      t.timestamps
    end

    add_index :crm_pipelines, :account_id
    add_index :crm_pipelines, [:account_id, :active]
  end
end
