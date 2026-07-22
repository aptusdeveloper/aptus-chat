require 'rails_helper'
require Rails.root.join 'spec/mailers/administrator_notifications/shared/smtp_config_shared.rb'

RSpec.describe AdministratorNotifications::IntegrationsNotificationMailer do
  include_context 'with smtp config'

  let!(:account) { create(:account) }
  let!(:administrator) { create(:user, :administrator, email: 'admin@example.com', account: account) }
  let!(:another_administrator) { create(:user, :administrator, email: 'owner@example.com', account: account) }

  describe 'slack_disconnect' do
    let(:mail) { described_class.with(account: account).slack_disconnect.deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq('Sua integração com Slack expirou')
    end

    it 'renders the receiver email' do
      expect(mail.to).to contain_exactly(administrator.email, another_administrator.email)
    end

    it 'includes reconnect instructions in the body' do
      expected_text = 'Para continuar recebendo mensagens no Slack, exclua a integração ' \
                      'e conecte seu workspace novamente'
      expect(mail.body.encoded).to include(expected_text)
    end
  end

  describe 'dialogflow_disconnect' do
    let(:mail) { described_class.with(account: account).dialogflow_disconnect.deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq('Sua integração com Dialogflow foi desconectada')
    end

    it 'renders the content' do
      expect(mail.body.encoded).to include('Sua integração do Dialogflow foi desconectada devido a problemas de permissão')
    end

    it 'renders the receiver email' do
      expect(mail.to).to contain_exactly(administrator.email, another_administrator.email)
    end
  end

  describe 'openai_disconnect' do
    let(:mail) { described_class.with(account: account).openai_disconnect.deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq('Sua integração com OpenAI foi desconectada')
    end

    it 'renders the content' do
      expect(mail.body.encoded).to include('a chave de API configurada é inválida ou revogada')
    end

    it 'renders the receiver email' do
      expect(mail.to).to contain_exactly(administrator.email, another_administrator.email)
    end
  end
end
