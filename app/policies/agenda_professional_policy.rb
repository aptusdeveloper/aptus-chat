class AgendaProfessionalPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def available_slots?
    true
  end

  def create?
    administrator?
  end

  def update?
    administrator?
  end

  def destroy?
    administrator?
  end

  private

  def administrator?
    account_user&.administrator?
  end
end

AgendaProfessionalPolicy.prepend_mod_with('AgendaProfessionalPolicy')
