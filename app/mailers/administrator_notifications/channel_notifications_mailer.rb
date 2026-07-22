class AdministratorNotifications::ChannelNotificationsMailer < AdministratorNotifications::BaseMailer
  def facebook_disconnect(inbox)
    subject = I18n.t('email_subjects.channel_expired', channel: 'Facebook')
    send_notification(subject, action_url: inbox_url(inbox))
  end

  def instagram_disconnect(inbox)
    subject = I18n.t('email_subjects.channel_expired', channel: 'Instagram')
    send_notification(subject, action_url: inbox_url(inbox))
  end

  def tiktok_disconnect(inbox)
    subject = I18n.t('email_subjects.channel_expired', channel: 'TikTok')
    send_notification(subject, action_url: inbox_url(inbox))
  end

  def whatsapp_disconnect(inbox)
    subject = I18n.t('email_subjects.channel_expired', channel: 'WhatsApp')
    send_notification(subject, action_url: inbox_url(inbox))
  end

  def email_disconnect(inbox)
    subject = I18n.t('email_subjects.email_channel_disconnected')
    send_notification(subject, action_url: inbox_url(inbox))
  end
end
