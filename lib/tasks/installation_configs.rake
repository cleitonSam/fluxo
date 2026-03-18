namespace :installation_configs do
  desc 'Sync installation config values from environment variables'
  task sync_from_env: :environment do
    config_map = {
      'INSTALLATION_PRICING_PLAN' => ENV['INSTALLATION_PRICING_PLAN'],
      'INSTALLATION_PRICING_PLAN_QUANTITY' => ENV['INSTALLATION_PRICING_PLAN_QUANTITY'],
      'INSTALLATION_IDENTIFIER' => ENV['INSTALLATION_IDENTIFIER']
    }.compact

    if config_map.empty?
      puts 'No installation config environment variables were provided.'
      puts 'Set INSTALLATION_PRICING_PLAN, INSTALLATION_PRICING_PLAN_QUANTITY, or INSTALLATION_IDENTIFIER.'
      next
    end

    config_map.each do |name, raw_value|
      value = cast_value(name, raw_value)
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.save!
      puts "Updated #{name} => #{value}"
    end
  end

  def cast_value(name, value)
    return value.to_i if name == 'INSTALLATION_PRICING_PLAN_QUANTITY'

    value
  end
end
