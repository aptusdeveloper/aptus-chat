class CreateAgendaAvailabilities < ActiveRecord::Migration[7.1]
  def change
    create_table :agenda_availabilities, id: :uuid do |t|
      t.bigint :account_id, null: false
      t.references :agenda_schedule, null: false, foreign_key: true, type: :uuid
      t.integer :day_of_week
      t.date :date
      t.integer :start_hour
      t.integer :start_minutes
      t.integer :end_hour
      t.integer :end_minutes
      t.boolean :unavailable, null: false, default: false
      t.timestamps
    end

    add_index :agenda_availabilities, [:account_id, :agenda_schedule_id]
    add_index :agenda_availabilities, [:agenda_schedule_id, :day_of_week]
    add_index :agenda_availabilities, [:agenda_schedule_id, :date]
  end
end
