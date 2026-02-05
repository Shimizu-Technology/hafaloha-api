# frozen_string_literal: true

# This script tests the EasyPost shipping integration
# Run with: bin/rails runner scripts/test_shipping_api.rb

puts "================================================================================"
puts "TESTING EASYPOST SHIPPING INTEGRATION"
puts "================================================================================"

# Check if EasyPost is configured
unless ENV['EASYPOST_API_KEY'].present?
  puts "❌ EASYPOST_API_KEY not set in .env file"
  puts ""
  puts "To set up EasyPost:"
  puts "1. Sign up at https://www.easypost.com/signup"
  puts "2. Get your test API key from https://www.easypost.com/account/api-keys"
  puts "3. Add to hafaloha-api/.env:"
  puts "   EASYPOST_API_KEY=EZTEST..."
  puts ""
  exit 1
end

puts "✅ EasyPost API key configured"
puts ""

# Make sure we have cart items with weight
puts "Checking for cart items..."
cart_item = CartItem.includes(product_variant: :product).first

unless cart_item
  puts "❌ No cart items found. Adding sample items..."

  # Find or create a product
  product = Product.find_by(slug: "hafaloha-championship-t-shirt")

  unless product
    puts "❌ No products found. Please run: bin/rails db:seed"
    exit 1
  end

  variant = product.product_variants.first

  unless variant
    puts "❌ No variants found for product"
    exit 1
  end

  # Make sure variant has weight
  if variant.weight_oz.nil? || variant.weight_oz <= 0
    puts "⚠️  Variant has no weight, setting to 8oz..."
    variant.update!(weight_oz: 8)
  end

  # Create a test cart item with a session ID
  session_id = "test_shipping_#{SecureRandom.hex(8)}"
  cart_item = CartItem.create!(
    session_id: session_id,
    product_variant: variant,
    quantity: 2
  )

  puts "✅ Created test cart item (session: #{session_id})"
end

cart_items = CartItem.where(session_id: cart_item.session_id).includes(product_variant: :product)
total_weight = cart_items.sum { |item| (item.product_variant.weight_oz || 0) * item.quantity }

puts "✅ Found #{cart_items.count} cart item(s)"
puts "   Total weight: #{total_weight} oz"
puts ""

# Test destination addresses
test_addresses = [
  {
    name: "Test User - California",
    street1: "388 Townsend St",
    street2: "Apt 20",
    city: "San Francisco",
    state: "CA",
    zip: "94107",
    country: "US",
    phone: "415-555-0100"
  },
  {
    name: "Test User - New York",
    street1: "123 Main Street",
    city: "New York",
    state: "NY",
    zip: "10001",
    country: "US",
    phone: "212-555-0100"
  }
]

test_addresses.each_with_index do |address, index|
  puts "================================================================================"
  puts "TEST #{index + 1}: Calculating rates for #{address[:name]}"
  puts "================================================================================"

  begin
    rates = ShippingService.calculate_rates(cart_items, address)

    if rates.empty?
      puts "⚠️  No shipping rates available"
    else
      puts "✅ Found #{rates.count} shipping option(s):"
      puts ""

      rates.each_with_index do |rate, i|
        puts "#{i + 1}. #{rate[:carrier]} - #{rate[:service]}"
        puts "   Price: #{rate[:rate_formatted]}"
        puts "   Delivery: #{rate[:delivery_days]} days#{rate[:delivery_date_guaranteed] ? ' (guaranteed)' : ''}"
        puts "   Est. Delivery Date: #{rate[:delivery_date] || 'N/A'}"
        puts ""
      end

      cheapest = rates.min_by { |r| r[:rate_cents] }
      fastest = rates.min_by { |r| r[:delivery_days] || 99 }

      puts "💰 Cheapest: #{cheapest[:carrier]} #{cheapest[:service]} - #{cheapest[:rate_formatted]}"
      puts "⚡ Fastest: #{fastest[:carrier]} #{fastest[:service]} - #{fastest[:delivery_days]} days"
    end

  rescue ShippingService::ShippingError => e
    puts "❌ Shipping Error: #{e.message}"
  rescue StandardError => e
    puts "❌ Unexpected Error: #{e.class} - #{e.message}"
    puts e.backtrace.first(5).join("\n")
  end

  puts ""
end

# Test address validation
puts "================================================================================"
puts "TEST: Address Validation"
puts "================================================================================"

test_validation_address = {
  street1: "1600 Amphitheatre Pkwy",  # Google HQ
  city: "Mountain View",
  state: "CA",
  zip: "94043",
  country: "US"
}

begin
  validated = ShippingService.validate_address(test_validation_address)

  if validated[:verified]
    puts "✅ Address verified successfully"
    puts "   Street: #{validated[:street1]}"
    puts "   City: #{validated[:city]}, #{validated[:state]} #{validated[:zip]}"
  else
    puts "⚠️  Address could not be verified"
    if validated[:error]
      puts "   Error: #{validated[:error]}"
    end
  end
rescue ShippingService::ShippingError => e
  puts "❌ Validation Error: #{e.message}"
rescue StandardError => e
  puts "❌ Unexpected Error: #{e.class} - #{e.message}"
end

puts ""
puts "================================================================================"
puts "TESTS COMPLETE"
puts "================================================================================"
puts ""
puts "Next steps:"
puts "1. Review the shipping rates above"
puts "2. Update warehouse address in app/services/shipping_service.rb"
puts "3. Build frontend checkout UI with shipping address form"
puts "4. Test with real addresses"
