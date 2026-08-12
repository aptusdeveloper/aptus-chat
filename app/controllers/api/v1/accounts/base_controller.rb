class Api::V1::Accounts::BaseController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper

  # The only account-scoped controller a Hub-only client reaches. Everything else under this
  # base controller belongs to product areas those clients do not have (conversations,
  # contacts, CRM, agenda, settings). The account payload the dashboard boots with comes from
  # Api::V1::AccountsController, which descends from Api::BaseController and is not gated here.
  HUB_ONLY_CONTROLLERS = %w[api/v1/accounts/aptus_hub].freeze

  before_action :current_account
  before_action :ensure_hub_only_scope!
  around_action :switch_locale_using_account_locale

  private

  def ensure_hub_only_scope!
    return unless AptusHub::AccountConfig.new(Current.account).hub_only?
    return if HUB_ONLY_CONTROLLERS.include?(controller_path)

    render_not_found_error('Recurso indisponivel para esta conta.')
  end
end
