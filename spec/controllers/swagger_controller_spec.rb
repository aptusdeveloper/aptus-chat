require 'rails_helper'

describe '/swagger', type: :request do
  describe 'GET /swagger' do
    it 'renders swagger index.html' do
      get '/swagger'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('redoc')
      expect(response.body).to include('/swagger.json')
    end

    it 'does not render files outside the swagger directory' do
      get '/swagger/%2Fetc%2Fpasswd'
      expect(response).to have_http_status(:not_found)
    end

    it 'permanece indisponível em produção' do
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(Rails.env).to receive(:test?).and_return(false)

      get '/swagger'

      expect(response).to have_http_status(:not_found)
    end
  end
end
