class AptusHubPolicy < ApplicationPolicy
  def performance?
    view?
  end

  def webchat_config?
    view?
  end

  def payments?
    view?
  end

  def payment_details?
    view?
  end

  def feedback?
    view?
  end

  private

  def view?
    account_user&.administrator? || account_user&.agent?
  end
end
