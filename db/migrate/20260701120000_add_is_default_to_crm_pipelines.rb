class AddIsDefaultToCrmPipelines < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_pipelines, :is_default, :boolean, null: false, default: false

    add_index :crm_pipelines, [:account_id, :is_default],
              unique: true,
              where: 'is_default = true',
              name: 'index_crm_pipelines_one_default_per_account'
  end
end
