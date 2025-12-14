#!/usr/bin/env ruby
# frozen_string_literal: true

# This script tests the fallback shipping rates system
# Run via: rails runner scripts/test_fallback_shipping.rb

puts "================================================================================"
puts "TESTING FALLBACK SHIPPING RATES"
puts "================================================================================"

# Check fallback rates in database
settings = SiteSetting.instance
puts "\n✓ Fallback rates configured in database:"
puts "  Domestic tiers: #{settings.fallback_shipping_rates['domestic'].count}"
puts "  International tiers: #{settings.fallback_shipping_rates['international'].count}"

# Display the rate tables
puts "\n📊 Domestic Rates (Guam → US):"
settings.fallback_shipping_rates['domestic'].each_with_index do |tier, i|
  max_weight_lb = tier['max_weight_oz'] ? (tier['max_weight_oz'] / 16.0) : "10+"
  rate_dollars = tier['rate_cents'] / 100.0
  puts "  #{i + 1}. Up to #{max_weight_lb} lbs: $#{rate_dollars}"
end

puts "\n📊 International Rates:"
settings.fallback_shipping_rates['international'].each_with_index do |tier, i|
  max_weight_lb = tier['max_weight_oz'] ? (tier['max_weight_oz'] / 16.0) : "10+"
  rate_dollars = tier['rate_cents'] / 100.0
  puts "  #{i + 1}. Up to #{max_weight_lb} lbs: $#{rate_dollars}"
end

# Test fallback rate calculation
puts "\n--- TEST: Calculate Fallback Rates ---"

# Create a test cart item (or use existing)
product = Product.first
unless product
  puts "❌ No products found. Run: rails runner scripts/test_admin_api.rb"
  exit
end

variant = product.product_variants.first
unless variant
  puts "❌ No variants found."
  exit
end

# Create dummy cart items
class DummyCartItem
  attr_accessor :product_variant, :quantity
  def initialize(variant, qty)
    @product_variant = variant
    @quantity = qty
  end
end

# Test scenarios
test_cases = [
  { weight_oz: 8, qty: 1, dest: { country: "US", state: "CA" }, label: "1 light item to California" },
  { weight_oz: 8, qty: 3, dest: { country: "US", state: "NY" }, label: "3 light items to New York" },
  { weight_oz: 8, qty: 10, dest: { country: "US", state: "HI" }, label: "10 items to Hawaii" },
  { weight_oz: 8, qty: 1, dest: { country: "JP", state: "" }, label: "1 item to Japan" },
]

test_cases.each_with_index do |test_case, i|
  puts "\n#{i + 1}. Testing: #{test_case[:label]}"
  
  # Set variant weight
  variant.update_column(:weight_oz, test_case[:weight_oz])
  
  cart_items = [DummyCartItem.new(variant, test_case[:qty])]
  total_weight = test_case[:weight_oz] * test_case[:qty]
  total_weight_lb = total_weight / 16.0
  
  destination = {
    street1: "123 Test St",
    city: "Test City",
    state: test_case[:dest][:state],
    zip: "12345",
    country: test_case[:dest][:country],
    name: "Test User",
    phone: "555-0100"
  }
  
  begin
    # Temporarily unset EasyPost key to force fallback
    original_key = ENV['EASYPOST_API_KEY']
    ENV['EASYPOST_API_KEY'] = nil
    
    rates = ShippingService.calculate_rates(cart_items, destination)
    
    # Restore key
    ENV['EASYPOST_API_KEY'] = original_key
    
    puts "  Total weight: #{total_weight_lb.round(2)} lbs (#{total_weight} oz)"
    puts "  Destination: #{test_case[:dest][:country]}"
    puts "  Rate: $#{'%.2f' % rates.first[:rate]}"
    puts "  Service: #{rates.first[:service]}"
    puts "  Fallback: #{rates.first[:fallback] ? 'YES ✓' : 'NO'}"
    puts "  ✅ Success"
  rescue StandardError => e
    puts "  ❌ Error: #{e.message}"
  end
end

puts "\n================================================================================"
puts "FALLBACK SHIPPING TESTS COMPLETE ✅"
puts "================================================================================"
puts "\n💡 How it works:"
puts "  1. Try EasyPost API first (if configured and working)"
puts "  2. If EasyPost fails or unavailable → use fallback rates"
puts "  3. Fallback rates are based on weight + destination"
puts "  4. Admins can customize rates in Admin Settings (future feature)"
puts "\n🎯 Benefits:"
puts "  ✅ Site always works, even if EasyPost is down"
puts "  ✅ Reasonable rates based on weight"
puts "  ✅ No customer sees an error"
puts "  ✅ Logs warning so you know to check EasyPost"

