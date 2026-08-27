# Provider WhatsApp "gupshup" no aptus-chat

> **Status: implementado e testado end-to-end em 2026-08-27** contra o sandbox real da Gupshup.
> Ainda não posto em produção (falta conectar um número real via "Go Live" da Gupshup).
>
> **Testado e funcionando (sandbox `+917834811114`, conta 2 local):**
> - criação da inbox (valida a API key contra a Gupshup no `validate_provider_config?`)
> - entrada: texto e imagem (WhatsApp → webhook v3 → conversa no aptus-chat)
> - saída: texto, imagem e áudio (aptus-chat → API Gupshup → WhatsApp; status `read` confirmado)
>
> **Notas do teste:**
> - Saída de mídia exige `FRONTEND_URL` público (a Meta baixa o anexo pela URL). Em dev deu
>   `erro 131053 "localhost is private"` até apontar `FRONTEND_URL` pro túnel; em **produção
>   funciona sozinho** (domínio real). Não é bug do provider.
> - Entrada de mídia: a URL do `filemanager.gupshup.io` é pré-assinada e pública — baixa sem
>   header de auth. Um 429 inicial era tempestade de retry do Sidekiq; resolvido rescue +
>   log em vez de re-tentar (mensagem é criada sem o anexo se o download falhar).
> - "Esta imagem não está mais disponível" ao colar+enviar rápido = race de upload do
>   ActiveStorage no próprio Chatwoot, pré-existente, sem relação com a Gupshup.
>
> Verificação: `rubocop` e `eslint` limpos; `spec/models/channel/whatsapp_spec.rb` e
> `spec/jobs/webhooks/whatsapp_events_job_spec.rb` passando (48 ex). Sem specs novos,
> conforme a convenção do `CLAUDE.md`.

## Contexto

O aptus-chat precisa oferecer WhatsApp oficial aos clientes com **custo marginal quase zero**
para competir com a Kommo (ticket-alvo ~R$100/mês). Twilio (US$0,005/msg) e 360dialog
(€49/número/mês) inviabilizam a conta. **Gupshup self-serve** cobra US$0,001/msg, sem
mensalidade, e mensagem de sessão/atendimento é grátis na Meta — validado nos payloads de
teste (`pricing.type = free_customer_service`).

O caminho travado (não temos): app Meta verificado da APTUS → sem Embedded Signup, sem
Tech Provider próprio. Com Gupshup, **a Gupshup é o Tech Provider**; a APTUS (ou o cliente)
só precisa de um Meta Business Manager sem verificação (teto 250 conv/24h basta).

## Como a Gupshup difere da Cloud API

| | Cloud API (Meta) | Gupshup |
|---|---|---|
| Envio | `graph.facebook.com/.../messages`, JSON, Bearer | `api.gupshup.io/wa/api/v1/msg`, **form-urlencoded**, header `apikey` |
| Resposta do envio | `{ messages: [{ id }] }` | `{ status: "submitted", messageId }` |
| Webhook de entrada | formato Meta | **configurável no console** — "Formato Meta (v3)" ≈ verbatim |
| Mídia recebida | `id` → `GET /{media-id}` → download | payload v3 já traz `image.url` (mas expira ~7d, precisa header `apikey`) |
| Status extra | — | `enqueued` (antes de `sent`) |
| Templates | por `name` | por `id` (UUID Gupshup) |

Conclusão: **entrada** cai no parser Cloud existente; **saída** precisa de provider próprio.

## O que foi implementado

| Arquivo | Papel |
|---|---|
| `app/services/whatsapp/providers/gupshup_service.rb` | Envio (texto, anexo, quick_reply, list), `send_template`, `process_response`/`error_message` para o shape da Gupshup, `media_url`, `api_headers` |
| `app/services/whatsapp/gupshup_templates_service.rb` | `GET /wa/app/{appId}/template` → mapeia para o formato de components da Meta que o `TemplateProcessorService` e o picker do frontend esperam; guarda `gupshup_id` |
| `app/services/whatsapp/incoming_message_gupshup_service.rb` | Subclasse de `IncomingMessageWhatsappCloudService`; só sobrescreve `download_attachment_file` (usa `payload[:url]` + `apikey`) e ignora status `enqueued` |
| `app/models/channel/whatsapp.rb` | `PROVIDERS` ganha `gupshup`; `provider_service` vira `case` |
| `app/jobs/webhooks/whatsapp_events_job.rb` | `handle_message_events` roteia `when 'gupshup'` |
| `GupshupWhatsapp.vue` + `Whatsapp.vue` + `inboxMgmt.json` | Form de criação, acessível por `?provider=gupshup` (escondido dos cards, igual ao 360dialog) |

### provider_config

```
api_key             API key permanente (aba Settings do app Gupshup)
app_name            nome do app — enviado como src.name
app_id              UUID do app — usado no listing de templates
phone_number_id     phone number id da Meta — casa com metadata do webhook v3
business_account_id  WABA id (opcional, paridade com o provider Cloud)
```

### send_template

`SendOnWhatsappService` sempre passa pelo `TemplateProcessorService`, que devolve params no
formato de components da Meta. O `GupshupService#send_template`:

1. acha o template em `channel.message_templates` por `name` + `language` (precisa de `gupshup_id`);
2. achata o component `body` para o array plano que a Gupshup espera (`template.params`);
3. mídia de header vira o parâmetro `message` (`{ type: "image", image: { link } }`).

Cobre o caso comum (template com corpo + placeholders posicionais). Header/botões dinâmicos
mais elaborados ficam para depois.

## Configuração de um número (produção)

1. Cliente (ou APTUS) tem um Meta Business Manager — **sem verificação** já serve para começar.
2. No console Gupshup: **Go Live** no app → conecta o número real via embedded signup da Gupshup.
3. No app Gupshup → **Webhooks** → adiciona webhook:
   - URL: `https://<host>/webhooks/whatsapp/+<phone>`
   - **Formato de carga útil: Formato Meta (v3)**
   - Eventos: grupo "Eventos de Mensagens" inteiro
4. No aptus-chat: Configurações → Inboxes → `?provider=gupshup` → preenche `api_key`,
   `app_name`, `app_id`, `phone_number_id`, número.
5. Carrega a carteira Gupshup (aceita cartão BR).

## Pendências conhecidas

- **Não posto em produção.** Falta conectar um número real: cliente (ou APTUS) com um Meta
  Business Manager → "Go Live" no app Gupshup (embedded signup da Gupshup) → webhook v3
  apontado para `https://<host prod>/webhooks/whatsapp/+<numero>` → criar a inbox no aptus-chat.
  Candidato a primeiro cliente: Dra. Bárbarah (pré-lançamento, número novo, sem migração).
- **Template (`send_template`) não testado** — o sandbox só tem templates compartilhados e
  exige conversa fora da janela de 24h. Testar com um cliente real.
- **`enqueued` sem metadata** não resolve o canal no `WhatsappEventsJob` (fica um log
  "Inactive WhatsApp channel"). Inofensivo — o status seria descartado de qualquer forma.
- **Verificação do webhook é fraca:** só a URL + o match de `phone_number_id` no payload. A
  Gupshup não assina como a Meta (`X-Hub-Signature-256`). Aceitável para v1; melhorar com um
  token em header customizado ("Inclui cabeçalhos" no modal de webhook).
- **Status `enqueued`** chega sem `metadata`, então `WhatsappEventsJob` não resolve o canal e
  loga "Inactive WhatsApp channel". Inofensivo (o `enqueued` seria descartado de qualquer
  forma), mas gera ruído de log.
- **`sync_templates` no `after_create`**: se a listagem de templates da Gupshup falhar, o
  canal é criado sem templates e re-sincroniza depois (mesmo comportamento dos outros providers).
