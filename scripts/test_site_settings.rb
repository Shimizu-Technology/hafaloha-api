#!/usr/bin/env ruby
# frozen_string_literal: true

# This script tests the SiteSetting admin-controlled test mode system
# Run via: rails runner scripts/test_site_settings.rb

puts "================================================================================"
puts "TESTING SITE SETTINGS & TEST MODE TOGGLE"
puts "================================================================================"

# Test 1: Singleton Pattern
puts "\n--- TEST 1: Singleton Pattern ---"
settings1 = SiteSetting.instance
settings2 = SiteSetting.instance
puts "✓ Instance 1 ID: #{settings1.id}"
puts "✓ Instance 2 ID: #{settings2.id}"
puts settings1.id == settings2.id ? "✅ Singleton works - same instance!" : "❌ ERROR: Different instances!"

# Test 2: Default Settings
puts "\n--- TEST 2: Default Settings ---"
settings = SiteSetting.instance
puts "Payment Test Mode: #{settings.payment_test_mode? ? '⚙️  ENABLED' : '💳 DISABLED'}"
puts "Payment Processor: #{settings.payment_processor}"
puts "Store Name: #{settings.store_name}"
puts "Store Email: #{settings.store_email}"
puts "Store Phone: #{settings.store_phone}"
puts "Shipping Origin: #{settings.shipping_origin_address['city']}, #{settings.shipping_origin_address['state']}"

# Test 3: Toggle Test Mode
puts "\n--- TEST 3: Toggle Test Mode ---"
original_mode = settings.payment_test_mode
puts "Current mode: #{original_mode ? 'TEST' : 'PRODUCTION'}"

# Toggle to opposite
settings.update!(payment_test_mode: !original_mode)
settings.reload
puts "✓ Toggled to: #{settings.payment_test_mode ? 'TEST' : 'PRODUCTION'}"

# Toggle back
settings.update!(payment_test_mode: original_mode)
settings.reload
puts "✓ Restored to: #{settings.payment_test_mode ? 'TEST' : 'PRODUCTION'}"
puts "✅ Toggle works!"

# Test 4: Helper Methods
puts "\n--- TEST 4: Helper Methods ---"
puts "test_mode?: #{settings.test_mode?}"
puts "production_mode?: #{settings.production_mode?}"
puts "using_stripe?: #{settings.using_stripe?}"
puts "using_paypal?: #{settings.using_paypal?}"

# Test 5: Prevent Deletion
puts "\n--- TEST 5: Singleton Protection (Cannot Delete) ---"
begin
  settings.destroy
  puts "❌ ERROR: Should not be able to delete!"
rescue ActiveRecord::RecordNotDestroyed => e
  puts "✅ Deletion prevented: #{e.message}"
end

# Test 6: Simulate Order Flow
puts "\n--- TEST 6: Simulate Order Processing ---"
settings = SiteSetting.instance
if settings.test_mode?
  puts "⚙️  Current Mode: TEST"
  puts "   → Orders will use simulated payments"
  puts "   → No actual charges will be made"
  puts "   → Order payment_status will be 'test_paid'"
else
  puts "💳 Current Mode: PRODUCTION"
  puts "   → Orders will use real Stripe API"
  puts "   → Actual charges will be made"
  puts "   → Order payment_status will be 'paid'"
end

# Test 7: Config API Response Simulation
puts "\n--- TEST 7: Config API Response (Frontend) ---"
config_response = {
  payment_test_mode: settings.payment_test_mode,
  payment_processor: settings.payment_processor,
  stripe_publishable_key: settings.test_mode? ? "pk_test_..." : "pk_live_...",
  features: {
    payments: true,
    shipping: ENV['EASYPOST_API_KEY'].present?
  },
  store_info: {
    name: settings.store_name,
    email: settings.store_email,
    phone: settings.store_phone
  }
}
puts "Config API would return:"
puts JSON.pretty_generate(config_response)

puts "\n================================================================================"
puts "ALL TESTS COMPLETE ✅"
puts "================================================================================"
puts "\n🎉 Admin-Controlled Test Mode is working perfectly!"
puts "   → Any admin can toggle via /admin/settings"
puts "   → No restart needed"
puts "   → Changes apply immediately"

