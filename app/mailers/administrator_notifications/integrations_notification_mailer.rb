class AdministratorNotifications::IntegrationsNotificationMailer < AdministratorNotifications::BaseMailer
  def slack_disconnect
    subject = I18n.t('email_subjects.integration_expired', integration: 'Slack')
    action_url = settings_url('integrations/slack')
    send_notification(subject, action_url: action_url)
  end

  def dialogflow_disconnect
    subject = I18n.t('email_subjects.integration_disconnected', integration: 'Dialogflow')
    send_notification(subject)
  end

  def openai_disconnect
    subject = I18n.t('email_subjects.integration_disconnected', integration: 'OpenAI')
    action_url = settings_url('integrations/openai')
    send_notification(subject, action_url: action_url)
  end
end
