namespace :crm do
  desc 'Create the default CRM pipeline for all accounts that do not have one yet'
  task seed_default_pipelines: :environment do
    accounts = Account.where.not(id: CrmPipeline.where(is_default: true).select(:account_id))
    total = accounts.count
    puts "Creating default CRM pipeline for #{total} account(s)..."

    accounts.find_each.with_index(1) do |account, idx|
      Crm::DefaultPipelineSetupService.new(account).perform
      puts "  [#{idx}/#{total}] Account ##{account.id} (#{account.name}) — OK"
    rescue StandardError => e
      puts "  [#{idx}/#{total}] Account ##{account.id} — ERROR: #{e.message}"
    end

    puts 'Done.'
  end
end
