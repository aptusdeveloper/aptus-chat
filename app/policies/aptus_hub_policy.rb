class AptusHubPolicy < ApplicationPolicy
  def performance?
    view?
  end

  def webchat_config?
    view?
  end

  def payments?
    account_user&.administrator?
  end

  def payment_details?
    account_user&.administrator?
  end

  def feedback?
    view?
  end

  private

  def view?
    account_user&.administrator? || account_user&.agent?
  end
end
