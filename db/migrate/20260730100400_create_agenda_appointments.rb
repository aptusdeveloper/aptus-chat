class CreateAgendaAppointments < ActiveRecord::Migration[7.1]
  # rubocop:disable Metrics/MethodLength
  def change
    create_table :agenda_appointments, id: :uuid do |t|
      t.bigint :account_id, null: false
      t.references :agenda_professional, null: false, foreign_key: true, type: :uuid
      t.references :agenda_event_type, null: false, foreign_key: true, type: :uuid
      t.integer :contact_id
      t.integer :conversation_id
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :status, null: false, default: 0
      t.boolean :rescheduled, null: false, default: false
      t.uuid :rescheduled_from_id
      t.datetime :cancelled_at
      t.string :cancellation_reason
      t.integer :source, null: false, default: 0
      t.string :patient_name
      t.string :patient_phone
      t.text :notes
      t.timestamps
    end

    add_index :agenda_appointments, [:account_id, :agenda_professional_id, :starts_at],
              name: 'index_agenda_appointments_on_account_professional_starts'
    add_index :agenda_appointments, :contact_id
    add_index :agenda_appointments, :conversation_id
    add_index :agenda_appointments, [:account_id, :status]
    add_index :agenda_appointments, :rescheduled_from_id

    add_foreign_key :agenda_appointments, :agenda_appointments, column: :rescheduled_from_id
  end
  # rubocop:enable Metrics/MethodLength
end
