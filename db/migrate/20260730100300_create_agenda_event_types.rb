class CreateAgendaEventTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :agenda_event_types, id: :uuid do |t|
      t.bigint :account_id, null: false
      t.references :agenda_professional, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.integer :duration_minutes, null: false
      t.integer :buffer_before_minutes, null: false, default: 0
      t.integer :buffer_after_minutes, null: false, default: 0
      t.integer :minimum_notice_minutes, null: false, default: 0
      t.integer :slot_interval_minutes, null: false, default: 15
      t.boolean :active, null: false, default: true
      t.text :description
      t.string :color
      t.timestamps
    end

    add_index :agenda_event_types, :account_id
    add_index :agenda_event_types, [:account_id, :agenda_professional_id]
  end
end
