require 'rails_helper'

RSpec.describe 'completude das traduções pt_BR' do
  def leaf_keys(value, prefix = nil)
    return [prefix] unless value.is_a?(Hash)

    value.flat_map do |key, child|
      leaf_keys(child, [prefix, key].compact.join('.'))
    end
  end

  it 'possui todas as chaves Rails disponíveis em inglês' do
    locale_files = Dir[Rails.root.join('{config,enterprise/config}/locales/**/*.{yml,yaml}')]
    translations = locale_files.each_with_object(en: {}, pt_BR: {}) do |file, result|
      locale_data = YAML.safe_load_file(file, aliases: true) || {}
      result[:en].deep_merge!(locale_data.fetch('en', {}))
      result[:pt_BR].deep_merge!(locale_data.fetch('pt_BR', {}))
    end

    expect(leaf_keys(translations[:en]) - leaf_keys(translations[:pt_BR])).to be_empty
  end

  it 'possui todos os arquivos e chaves do dashboard disponíveis em inglês' do
    locale_root = Rails.root.join('app/javascript/dashboard/i18n/locale')
    english_files = Dir[locale_root.join('en/*.json')]

    missing = english_files.flat_map do |english_file|
      portuguese_file = locale_root.join('pt_BR', File.basename(english_file))
      next [File.basename(english_file)] unless portuguese_file.exist?

      english = JSON.parse(File.read(english_file))
      portuguese = JSON.parse(portuguese_file.read)
      leaf_keys(english).to_set.difference(leaf_keys(portuguese).to_set).map do |key|
        "#{File.basename(english_file)}:#{key}"
      end
    end

    expect(missing).to be_empty
  end

  it 'possui todas as chaves do widget disponíveis em inglês' do
    locale_root = Rails.root.join('app/javascript/widget/i18n/locale')
    english = JSON.parse(locale_root.join('en.json').read)
    portuguese = JSON.parse(locale_root.join('pt_BR.json').read)

    expect(leaf_keys(english) - leaf_keys(portuguese)).to be_empty
  end

  it 'possui uma variante pt_BR para cada template de e-mail ativo' do
    roots = %w[app/views/mailers app/views/devise/mailer enterprise/app/views/devise/mailer]
    templates = roots.flat_map { |root| Dir[Rails.root.join(root, '**/*.{liquid,html.erb}')] }
    active_english_templates = templates.reject do |file|
      file.include?('.pt_BR.') || file.include?('portal_instructions_mailer')
    end

    missing = active_english_templates.reject do |file|
      localized = file.sub(/(\.liquid|\.html\.erb)\z/, '.pt_BR\1')
      File.exist?(localized)
    end

    expect(missing.map { |file| file.delete_prefix("#{Rails.root}/") }).to be_empty
  end
end
