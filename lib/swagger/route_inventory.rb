require 'yaml'

# O namespace ainda não existe quando as tarefas Rake são carregadas fora do boot completo.
module Swagger; end

class Swagger::RouteInventory
  HTTP_METHODS = %w[GET POST PUT PATCH DELETE].freeze
  API_CONTROLLER_PREFIXES = %w[api/ platform/api/ public/api/ enterprise/api/ webhooks/].freeze
  MACHINE_PATHS = %r{\A/(auth|resend_confirmation|health|api(?:/|\z)|webhooks|hc/|survey/responses|
                     twitter/callback|linear/callback|shopify/callback|twilio/|microsoft/callback|
                     google/callback|instagram/callback|tiktok/callback|notion/callback|\.well-known/)}x
  EXCLUDED_PATHS = %r{\A/(app(?:/|\z)|super_admin|monitoring|swagger|widget_tests)}
  DISABLED_CONTROLLERS = {
    %r{(?:\A|/)captain/} => 'Os recursos Captain e Copilot estão ocultos no MVP do AptusChat.',
    %r{(?:\A|/)companies(?:/|\z)} => 'O módulo Empresas está oculto no MVP do AptusChat.',
    %r{(?:\A|/)(?:reports|summary_reports|live_reports)(?:/|\z)} => 'Os relatórios estão ocultos no MVP do AptusChat.',
    %r{(?:\A|/)campaigns(?:/|\z)} => 'As campanhas estão ocultas no MVP do AptusChat.',
    %r{(?:\A|/)portals(?:/|\z)|(?:\A|/)(?:articles|categories)(?:/|\z)} => 'O Help Center e os portais estão ocultos no MVP do AptusChat.'
  }.freeze
  ACTIONS = {
    'index' => 'Listar', 'show' => 'Consultar', 'create' => 'Criar', 'update' => 'Atualizar',
    'destroy' => 'Excluir', 'delete' => 'Excluir', 'search' => 'Pesquisar', 'filter' => 'Filtrar',
    'move' => 'Mover', 'toggle_status' => 'Alternar status', 'sync' => 'Sincronizar',
    'verify' => 'Verificar', 'events' => 'Receber eventos', 'process_payload' => 'Processar evento'
  }.freeze

  class << self
    def paths
      api_routes.each_with_object({}) do |route, paths|
        route[:methods].each do |method|
          paths[route[:path]] ||= {}
          paths[route[:path]][method.downcase] ||= operation(route, method)
        end
      end
    end

    def write!(target = Rails.root.join('swagger/generated_paths.yml'))
      File.write(target, YAML.safe_dump(paths, line_width: -1))
    end

    def operation_keys
      paths.flat_map { |path, item| item.keys.map { |method| [method.upcase, path] } }.to_set
    end

    def api_routes
      Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller].to_s
        path = normalize_path(route.path.spec.to_s)
        methods = route.verb.to_s.scan(Regexp.union(HTTP_METHODS))
        next if methods.empty? || excluded?(path)
        next unless api_controller?(controller) || path.match?(MACHINE_PATHS)

        { path: path, methods: methods, controller: controller, action: route.defaults[:action].to_s }
      end
    end

    def exclusions
      {
        'Interface web' => %w[/ /app /widget],
        'Administração e monitoramento' => %w[/super_admin /monitoring/sidekiq],
        'Documentação e desenvolvimento' => %w[/swagger /widget_tests],
        'Engines Rack sem contrato Rails enumerável' => %w[/bot]
      }
    end

    private

    def api_controller?(controller)
      API_CONTROLLER_PREFIXES.any? { |prefix| controller.start_with?(prefix) }
    end

    def excluded?(path)
      path.match?(EXCLUDED_PATHS)
    end

    def normalize_path(path)
      path.sub('(.:format)', '').gsub(/\(.*?\)/, '').gsub(/:([a-zA-Z0-9_]+)/, '{\1}').sub(%r{/*\z}, '')
    end

    def operation(route, method)
      disabled_reason = disabled_reason(route[:controller], route[:path])
      operation = {
        'tags' => [tag_for(route[:controller], route[:path])],
        'operationId' => operation_id(route, method),
        'summary' => summary(route, disabled_reason),
        'description' => description(route, method, disabled_reason),
        'parameters' => path_parameters(route[:path]),
        'responses' => responses(route),
        'x-aptus-controller' => "#{route[:controller]}##{route[:action]}",
        'x-aptus-status' => disabled_reason ? 'disabled' : 'enabled'
      }
      operation['x-aptus-disabled-reason'] = disabled_reason if disabled_reason
      operation['security'] = security(route) if security(route).present?
      operation['requestBody'] = generic_request_body if %w[POST PUT PATCH].include?(method)
      operation.compact
    end

    def disabled_reason(controller, path)
      DISABLED_CONTROLLERS.each do |pattern, reason|
        return reason if controller.match?(pattern) || path.match?(pattern)
      end
      nil
    end

    def summary(route, disabled_reason)
      action = ACTIONS[route[:action]]
      text = action ? "#{action} #{resource_name(route[:controller])}" : "Executar operação de #{resource_name(route[:controller])}"
      disabled_reason ? "Desabilitada no AptusChat — #{text}" : text
    end

    def description(route, method, disabled_reason)
      warning = disabled_reason ? "**DESABILITADA NO APTUSCHAT:** #{disabled_reason}\n\n" : ''
      "#{warning}Executa `#{method} #{route[:path]}`. Operação implementada por `#{route[:controller]}##{route[:action]}`."
    end

    def resource_name(controller)
      controller.split('/').last.to_s.tr('_', ' ').downcase
    end

    def operation_id(route, method)
      "#{method.downcase}-#{route[:controller]}-#{route[:action]}-#{route[:path]}".parameterize
    end

    def path_parameters(path)
      path.scan(/\{([^}]+)\}/).flatten.map do |name|
        { 'name' => name, 'in' => 'path', 'required' => true, 'description' => "Identificador `#{name}`.", 'schema' => { 'type' => 'string' } }
      end
    end

    def responses(route)
      result = {
        '200' => { 'description' => 'Operação realizada com sucesso.' },
        '422' => { 'description' => 'Parâmetros inválidos ou regra de negócio não atendida.' }
      }
      if security(route).present?
        result['401'] = { 'description' => 'Token ausente ou inválido.' }
        result['403'] = { 'description' => 'Usuário sem permissão para executar a operação.' }
      end
      result
    end

    def security(route)
      return [] if route[:path].match?(%r{\A/(auth|resend_confirmation|health|webhooks|public/api|hc/|survey/|\.well-known/)})
      return [{ 'platformAppApiKey' => [] }] if route[:path].start_with?('/platform/api')

      [{ 'userApiKey' => [] }, { 'agentBotApiKey' => [] }]
    end

    def generic_request_body
      {
        'required' => false,
        'description' => 'Corpo JSON aceito pela operação. Consulte os campos específicos do recurso quando houver schema detalhado.',
        'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'additionalProperties' => true } } }
      }
    end

    # A ordem é significativa: algumas famílias compartilham os mesmos prefixos de API.
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def tag_for(controller, path)
      return 'CRM' if controller.include?('crm_')
      return 'Autenticação' if path.start_with?('/auth', '/resend_confirmation')
      return 'Webhooks e callbacks' if path.include?('webhook') || controller.start_with?('webhooks/') || path.include?('callback')
      return 'API da Plataforma' if path.start_with?('/platform/api')
      return 'API Pública' if path.start_with?('/public/api', '/hc/')
      return 'Widget' if controller.include?('/widget/')
      return 'Relatórios' if controller.match?(%r{/(reports|summary_reports|live_reports)})
      return 'Captain e Copilot' if controller.include?('/captain/')
      return 'Empresas' if controller.include?('/companies')
      return 'Campanhas' if controller.include?('/campaigns')
      return 'Portais e Help Center' if controller.match?(%r{/(portals|articles|categories)})

      'API da Aplicação'
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
end
