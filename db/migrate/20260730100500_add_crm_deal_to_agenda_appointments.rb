class AddCrmDealToAgendaAppointments < ActiveRecord::Migration[7.1]
  def change
    add_reference :agenda_appointments, :crm_deal, type: :uuid, foreign_key: true
  end
end
