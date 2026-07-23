#!/bin/bash
set -euo pipefail

PHONE_NUMBER_ID="998814986651149"
API_KEY="EAAOjpZBIBjE0BRyE6EWxb1QWuaKqZBHWJZBVPCkyx5yka9CVJsoHuUGvIYZAy69pUWsoXDbOs8Lwwrgr4ZBgMGTqWJ8LxdiJuMZBjll7fvu0LBAAkTlC3HHeEuVQni0h6dHfRRXvN0dAvWqHmSnBpkIWEzUGbHOLNFKWL3uxWYouM8kILLmSjpAW0C0fN1rXNnIfKjkan3dd2eP7gcJ7ctzH0mZBJrLGgIvFo0QOE4gjcgxUEMrHE6kze7SiniZCWiPIUikNRoRstyUl3N5S7eLTdHUitUcZD"

TO="${1:?Uso: ./send_whatsapp.sh <numero_com_ddi_sem_+> <mensagem>}"
MESSAGE="${2:?Uso: ./send_whatsapp.sh <numero_com_ddi_sem_+> <mensagem>}"

curl -s -X POST "https://graph.facebook.com/v22.0/${PHONE_NUMBER_ID}/messages" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"messaging_product\": \"whatsapp\",
    \"to\": \"${TO}\",
    \"type\": \"text\",
    \"text\": { \"body\": \"${MESSAGE}\" }
  }" | python3 -m json.tool
