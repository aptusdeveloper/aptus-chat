class CreateCrmDealConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_deal_conversations, id: :uuid do |t|
      t.references :crm_deal, null: false, foreign_key: true, type: :uuid
      t.bigint :conversation_id, null: false
      t.timestamps
    end

    add_index :crm_deal_conversations, [:crm_deal_id, :conversation_id], unique: true
    add_index :crm_deal_conversations, :conversation_id
  end
end
