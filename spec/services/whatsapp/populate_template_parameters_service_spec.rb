require 'rails_helper'

describe Whatsapp::PopulateTemplateParametersService do
  let(:service) { described_class.new }

  describe '#normalize_url' do
    it 'normalizes URLs with spaces' do
      url_with_spaces = 'https://example.com/path with spaces'
      normalized = service.send(:normalize_url, url_with_spaces)

      expect(normalized).to eq('https://example.com/path%20with%20spaces')
    end

    it 'handles URLs with special characters' do
      url = 'https://example.com/path?query=test value'
      normalized = service.send(:normalize_url, url)

      expect(normalized).to include('https://example.com/path')
      expect(normalized).not_to include(' ')
    end

    it 'returns valid URLs unchanged' do
      url = 'https://example.com/valid-path'
      normalized = service.send(:normalize_url, url)

      expect(normalized).to eq(url)
    end
  end

  describe '#build_media_parameter' do
    context 'when URL is not publicly accessible over HTTPS' do
      it 'rejects HTTP, localhost, loopback and private addresses' do
        invalid_urls = [
          'http://example.com/image.jpg',
          'https://localhost:3000/image.jpg',
          'https://127.0.0.1/image.jpg',
          'https://10.0.0.1/image.jpg',
          'https://172.16.0.1/image.jpg',
          'https://192.168.1.1/image.jpg'
        ]

        invalid_urls.each do |url|
          expect do
            service.build_media_parameter(url, 'IMAGE', nil, require_public_url: true)
          end.to raise_error(ArgumentError)
        end
      end
    end

    context 'when URL contains spaces' do
      it 'normalizes the URL before building media parameter' do
        url_with_spaces = 'https://example.com/image with spaces.jpg'
        result = service.build_media_parameter(url_with_spaces, 'IMAGE')

        expect(result[:type]).to eq('image')
        expect(result[:image][:link]).to eq('https://example.com/image%20with%20spaces.jpg')
      end
    end

    context 'when URL contains special characters in query string' do
      it 'normalizes the URL correctly' do
        url = 'https://example.com/video.mp4?title=My Video'
        result = service.build_media_parameter(url, 'VIDEO', 'test_video')

        expect(result[:type]).to eq('video')
        expect(result[:video][:link]).not_to include(' ')
      end
    end

    context 'when URL is already valid' do
      it 'builds media parameter without changing URL' do
        url = 'https://example.com/document.pdf'
        result = service.build_media_parameter(url, 'DOCUMENT', 'test.pdf')

        expect(result[:type]).to eq('document')
        expect(result[:document][:link]).to eq(url)
        expect(result[:document][:filename]).to eq('test.pdf')
      end
    end

    context 'when URL is blank' do
      it 'returns nil' do
        result = service.build_media_parameter('', 'IMAGE')

        expect(result).to be_nil
      end
    end
  end
end
