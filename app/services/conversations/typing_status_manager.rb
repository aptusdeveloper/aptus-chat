class Conversations::TypingStatusManager
  include Events::Types

  attr_reader :conversation, :user, :params

  def initialize(conversation, user, params)
    @conversation = conversation
    @user = user
    @params = params
  end

  def trigger_typing_event(event, is_private)
    Rails.configuration.dispatcher.dispatch(event, Time.zone.now, conversation: @conversation, user: @user, is_private: is_private)
  end

  def toggle_typing_status
    case params[:typing_status]
    when 'on'
      trigger_typing_event(CONVERSATION_TYPING_ON, params[:is_private])
      send_whatsapp_typing_indicator
    when 'off'
      trigger_typing_event(CONVERSATION_TYPING_OFF, params[:is_private])
    end
    # Return the head :ok response from the controller
  end

  private

  # Best-effort: propagates the human agent's "typing" from the dashboard to
  # WhatsApp Cloud API's native indicator. This is today's trigger (human agent
  # typing in the panel); a future bot/Botpress integration that needs the same
  # indicator should call `channel.send_typing_indicator` from its own trigger
  # point -- it doesn't need to go through this manager.
  def send_whatsapp_typing_indicator
    return if params[:is_private]
    return unless conversation.inbox.whatsapp?

    last_incoming_message = conversation.last_incoming_message
    return if last_incoming_message.blank? || last_incoming_message.source_id.blank?

    conversation.inbox.channel.send_typing_indicator(last_incoming_message.source_id)
  end
end
