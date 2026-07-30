class CreateAgendaSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :agenda_schedules, id: :uuid do |t|
      t.bigint :account_id, null: false
      t.references :agenda_professional, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false, default: 'Padrão'
      t.string :timezone
      t.timestamps
    end

    add_index :agenda_schedules, :account_id
  end
end
