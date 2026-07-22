require 'rails_helper'

describe Whatsapp::TemplateProcessorService do
  let(:template) do
    {
      'name' => 'products_carousel',
      'language' => 'en_US',
      'status' => 'APPROVED',
      'components' => [
        {
          'type' => 'CAROUSEL',
          'cards' => [
            { 'components' => [{ 'type' => 'HEADER', 'format' => 'IMAGE' }] },
            { 'components' => [{ 'type' => 'HEADER', 'format' => 'IMAGE' }] }
          ]
        }
      ]
    }
  end
  let(:channel) { instance_double(Channel::Whatsapp, message_templates: [template]) }
  let(:template_params) do
    {
      'name' => 'products_carousel',
      'language' => 'en_US',
      'processed_params' => {
        'cards' => [
          { 'header' => { 'media_url' => 'https://cdn.example.com/one.jpg', 'media_type' => 'image' } },
          { 'header' => { 'media_url' => 'https://cdn.example.com/two.jpg', 'media_type' => 'image' } }
        ]
      }
    }
  end

  it 'builds the official carousel payload with a public media URL per card' do
    result = described_class.new(channel: channel, template_params: template_params, message: nil).call

    expect(result.last).to eq(
      [
        {
          type: 'carousel',
          cards: [
            {
              card_index: 0,
              components: [{ type: 'header', parameters: [{ type: 'image', image: { link: 'https://cdn.example.com/one.jpg' } }] }]
            },
            {
              card_index: 1,
              components: [{ type: 'header', parameters: [{ type: 'image', image: { link: 'https://cdn.example.com/two.jpg' } }] }]
            }
          ]
        }
      ]
    )
  end
end
