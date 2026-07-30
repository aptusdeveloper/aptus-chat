class AgendaAppointmentPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    administrator? || agent? || agent_bot?
  end

  def update?
    create?
  end

  def cancel?
    create?
  end

  def reschedule?
    create?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def agent?
    account_user&.agent?
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end
end

AgendaAppointmentPolicy.prepend_mod_with('AgendaAppointmentPolicy')
