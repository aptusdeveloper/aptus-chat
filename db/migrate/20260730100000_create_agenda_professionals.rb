class CreateAgendaProfessionals < ActiveRecord::Migration[7.1]
  def change
    create_table :agenda_professionals, id: :uuid do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id
      t.string :name, null: false
      t.string :specialty
      t.string :timezone, null: false, default: 'America/Sao_Paulo'
      t.boolean :active, null: false, default: true
      t.string :color
      t.timestamps
    end

    add_index :agenda_professionals, :account_id
    add_index :agenda_professionals, [:account_id, :active]
    add_index :agenda_professionals, :user_id
  end
end
