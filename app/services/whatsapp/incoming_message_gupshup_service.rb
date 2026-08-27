# Gupshup delivers inbound webhooks in Meta's "v3" format (configured in the Gupshup
# console), so the Cloud API parser handles the envelope as-is. Only two things differ:
#
# 1. Media: the v3 payload carries a ready-to-use `url` (a pre-signed filemanager.gupshup.io
#    link with a `urlExpiry`), so there is no `GET /{media-id}` indirection and no auth
#    header — it is downloaded directly. A fetch failure is logged and the message is still
#    created (without the attachment) instead of storming the job's retries.
# 2. Statuses: Gupshup emits an extra `enqueued` status that has no Chatwoot equivalent
#    and is immediately followed by `sent`; it is dropped.
class Whatsapp::IncomingMessageGupshupService < Whatsapp::IncomingMessageWhatsappCloudService
  private

  def process_statuses
    return if processed_params.dig(:statuses, 0, :status) == 'enqueued'

    super
  end

  def download_attachment_file(attachment_payload)
    return super if attachment_payload[:url].blank?

    Down.download(attachment_payload[:url])
  rescue Down::Error => e
    Rails.logger.error "[WHATSAPP GUPSHUP] media download failed: #{e.message} url=#{attachment_payload[:url]}"
    nil
  end
end
