class AddCrmPipelineToCustomAttributeDefinitions < ActiveRecord::Migration[7.1]
  def change
    add_reference :custom_attribute_definitions, :crm_pipeline, type: :uuid, foreign_key: true, index: false

    remove_index :custom_attribute_definitions, name: 'attribute_key_model_index'
    add_index :custom_attribute_definitions, [:attribute_key, :attribute_model, :account_id],
              unique: true, where: 'crm_pipeline_id IS NULL', name: 'attribute_key_model_index'
    add_index :custom_attribute_definitions, [:attribute_key, :attribute_model, :account_id, :crm_pipeline_id],
              unique: true, where: 'crm_pipeline_id IS NOT NULL', name: 'attribute_key_model_pipeline_index'
  end
end
