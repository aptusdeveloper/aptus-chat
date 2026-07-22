require 'rails_helper'

describe Conversations::TypingStatusManager do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe '#toggle_typing_status' do
    context 'when the conversation belongs to a whatsapp_cloud inbox' do
      let(:whatsapp_channel) do
        create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
      end
      let(:conversation) { create(:conversation, account: account, inbox: whatsapp_channel.inbox) }

      before do
        create(:message, conversation: conversation, account: account, message_type: :incoming,
                         inbox: whatsapp_channel.inbox, source_id: 'wamid.123')
        allow(conversation.inbox.channel).to receive(:send_typing_indicator)
      end

      it 'sends the whatsapp typing indicator for a public typing-on event' do
        described_class.new(conversation, user, { typing_status: 'on', is_private: false }).toggle_typing_status

        expect(conversation.inbox.channel).to have_received(:send_typing_indicator).with('wamid.123')
      end

      it 'does not send when the typing event is private' do
        described_class.new(conversation, user, { typing_status: 'on', is_private: true }).toggle_typing_status

        expect(conversation.inbox.channel).not_to have_received(:send_typing_indicator)
      end

      it 'does not send anything on typing-off' do
        described_class.new(conversation, user, { typing_status: 'off', is_private: false }).toggle_typing_status

        expect(conversation.inbox.channel).not_to have_received(:send_typing_indicator)
      end

      it 'does not send when there is no incoming message yet' do
        conversation.messages.destroy_all

        described_class.new(conversation, user, { typing_status: 'on', is_private: false }).toggle_typing_status

        expect(conversation.inbox.channel).not_to have_received(:send_typing_indicator)
      end
    end

    context 'when the conversation belongs to a 360dialog (default provider) whatsapp inbox' do
      let(:whatsapp_channel) do
        create(:channel_whatsapp, account: account, provider: 'default', validate_provider_config: false, sync_templates: false)
      end
      let(:conversation) { create(:conversation, account: account, inbox: whatsapp_channel.inbox) }

      before do
        create(:message, conversation: conversation, account: account, message_type: :incoming,
                         inbox: whatsapp_channel.inbox, source_id: 'wamid.123')
      end

      it 'does not raise, since typing_indicator_supported? guards inside the channel itself' do
        expect do
          described_class.new(conversation, user, { typing_status: 'on', is_private: false }).toggle_typing_status
        end.not_to raise_error
      end
    end

    context 'when the conversation belongs to a non-whatsapp inbox' do
      let(:conversation) { create(:conversation, account: account) }

      it 'does not attempt to send a typing indicator (channel does not even implement it)' do
        expect(conversation.inbox.whatsapp?).to be false

        expect do
          described_class.new(conversation, user, { typing_status: 'on', is_private: false }).toggle_typing_status
        end.not_to raise_error
      end
    end
  end
end
