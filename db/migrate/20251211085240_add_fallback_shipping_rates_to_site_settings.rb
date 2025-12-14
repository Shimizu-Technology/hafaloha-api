class AddFallbackShippingRatesToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :fallback_shipping_rates, :jsonb, default: {
      "domestic" => [
        { "max_weight_oz" => 16, "rate_cents" => 800 },    # 0-1 lb: $8
        { "max_weight_oz" => 48, "rate_cents" => 1500 },   # 1-3 lbs: $15
        { "max_weight_oz" => 80, "rate_cents" => 2000 },   # 3-5 lbs: $20
        { "max_weight_oz" => 160, "rate_cents" => 3000 },  # 5-10 lbs: $30
        { "max_weight_oz" => nil, "rate_cents" => 5000 }   # 10+ lbs: $50
      ],
      "international" => [
        { "max_weight_oz" => 16, "rate_cents" => 2500 },   # 0-1 lb: $25
        { "max_weight_oz" => 48, "rate_cents" => 4000 },   # 1-3 lbs: $40
        { "max_weight_oz" => 80, "rate_cents" => 6000 },   # 3-5 lbs: $60
        { "max_weight_oz" => 160, "rate_cents" => 9000 },  # 5-10 lbs: $90
        { "max_weight_oz" => nil, "rate_cents" => 15000 }  # 10+ lbs: $150
      ]
    }, null: false
  end
end

