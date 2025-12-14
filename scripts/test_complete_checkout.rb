#!/usr/bin/env ruby
# Complete end-to-end checkout flow test
# Run with: bin/rails runner scripts/test_complete_checkout.rb

puts "=" * 80
puts "🧪 HAFALOHA COMPLETE CHECKOUT TEST"
puts "=" * 80
puts ""

errors = []
warnings = []

# Step 1: Verify Site Settings
puts "1️⃣  Checking Site Settings..."
begin
  settings = SiteSetting.instance
  puts "   ✅ Site Settings loaded"
  puts "      Test Mode: #{settings.test_mode? ? '⚙️  ENABLED' : '💳 DISABLED'}"
  puts "      Payment Processor: #{settings.payment_processor}"
  puts "      Store Email: #{settings.store_email}"
  puts "      Fallback Shipping: #{settings.fallback_shipping_rates.present? ? 'CONFIGURED' : 'NOT SET'}"
rescue => e
  errors << "Site Settings error: #{e.message}"
end
puts ""

# Step 2: Check Products & Variants
puts "2️⃣  Checking Products & Variants..."
begin
  products = Product.published.includes(:product_variants, :product_images)
  if products.any?
    puts "   ✅ Found #{products.count} published products"
    products.first(2).each do |product|
      in_stock_variants = product.product_variants.select { |v| v.in_stock? }
      puts "      • #{product.name} (#{in_stock_variants.count} in stock variants)"
    end
  else
    warnings << "No published products found"
  end
rescue => e
  errors << "Product check error: #{e.message}"
end
puts ""

# Step 3: Simulate Cart Creation (Guest)
puts "3️⃣  Simulating Guest Cart..."
begin
  session_id = "test_session_#{SecureRandom.hex(8)}"
  product = Product.published.first
  variant = product.product_variants.where("stock_quantity > 0").first
  
  if variant
    cart_item = CartItem.create!(
      session_id: session_id,
      product_variant: variant,
      quantity: 1
    )
    puts "   ✅ Cart item created"
    puts "      Session ID: #{session_id}"
    puts "      Product: #{product.name}"
    puts "      Variant: #{variant.display_name}"
    puts "      Price: $#{'%.2f' % (variant.price_cents / 100.0)}"
    puts "      Stock Before: #{variant.stock_quantity}"
  else
    warnings << "No in-stock variants found for testing"
  end
rescue => e
  errors << "Cart creation error: #{e.message}"
end
puts ""

# Step 4: Test Fallback Shipping Calculation
puts "4️⃣  Testing Fallback Shipping..."
begin
  if defined?(cart_item) && cart_item
    total_weight_oz = cart_item.product_variant.weight_oz * cart_item.quantity
    destination = { country: 'US', state: 'GU' }
    fallback_rates = ShippingService.calculate_fallback_rates(total_weight_oz, destination)
    fallback_rate = fallback_rates.first # Get first rate
    
    puts "   ✅ Fallback shipping calculated"
    puts "      Total Weight: #{total_weight_oz} oz"
    puts "      Available Rates: #{fallback_rates.count}"
    puts "      First Rate: $#{'%.2f' % fallback_rate[:rate]} (#{fallback_rate[:service]})"
  end
rescue => e
  errors << "Fallback shipping error: #{e.message}"
end
puts ""

# Step 5: Simulate Order Creation
puts "5️⃣  Simulating Order Creation..."
begin
  if defined?(cart_item) && cart_item && defined?(fallback_rate) && fallback_rate
    shipping_cost_cents = (fallback_rate[:rate] * 100).to_i
    
    test_order = Order.new(
      order_type: 'retail',
      status: 'pending',
      customer_email: 'test@example.com',
      customer_phone: '671-777-1234',
      customer_name: 'Test Customer',
      shipping_address_line1: '123 Test St',
      shipping_city: 'Hagatna',
      shipping_state: 'GU',
      shipping_zip: '96910',
      shipping_country: 'US',
      shipping_method: 'Standard Ground',
      shipping_cost_cents: shipping_cost_cents,
      subtotal_cents: variant.price_cents,
      tax_cents: 0,
      total_cents: variant.price_cents + shipping_cost_cents,
      payment_status: 'pending'
    )
    
    test_order.order_items.build(
      product_variant: variant,
      product: product,
      quantity: 1,
      unit_price_cents: variant.price_cents,
      total_price_cents: variant.price_cents,
      product_name: product.name,
      product_sku: variant.sku
    )
    
    puts "   ✅ Test order created (not saved)"
    puts "      Subtotal: $#{'%.2f' % (test_order.subtotal_cents / 100.0)}"
    puts "      Shipping: $#{'%.2f' % (test_order.shipping_cost_cents / 100.0)}"
    puts "      Total: $#{'%.2f' % (test_order.total_cents / 100.0)}"
  end
rescue => e
  errors << "Order creation error: #{e.message}"
end
puts ""

# Step 6: Test Payment Service (Test Mode)
puts "6️⃣  Testing Payment Service (Test Mode)..."
begin
  if defined?(test_order) && test_order
    payment_result = PaymentService.process_payment(
      amount_cents: test_order.total_cents,
      payment_method: { type: 'test', token: nil },
      order: test_order,
      customer_email: test_order.email,
      test_mode: true
    )
    
    if payment_result[:success]
      puts "   ✅ Test payment processed"
      puts "      Charge ID: #{payment_result[:charge_id]}"
      puts "      Payment Method: #{payment_result[:payment_method]}"
      puts "      Card: #{payment_result[:card_brand]} ending in #{payment_result[:card_last4]}"
    else
      errors << "Payment failed: #{payment_result[:error]}"
    end
  end
rescue => e
  errors << "Payment processing error: #{e.message}"
end
puts ""

# Step 7: Test Email Service (without actually sending)
puts "7️⃣  Checking Email Service..."
begin
  if ENV['RESEND_API_KEY'].present?
    puts "   ✅ Resend API key configured"
    puts "      From: #{settings.store_email}"
    puts "      Notification Emails: #{settings.order_notification_emails.join(', ')}"
  else
    warnings << "RESEND_API_KEY not set - emails will not be sent"
    puts "   ⚠️  Resend API key missing"
    puts "      Add to .env: RESEND_API_KEY=re_..."
  end
rescue => e
  errors << "Email service error: #{e.message}"
end
puts ""

# Step 8: Check Background Jobs
puts "8️⃣  Checking Background Jobs..."
begin
  if defined?(Sidekiq)
    puts "   ✅ Sidekiq configured"
    puts "      Queues: #{Sidekiq::Queue.all.map(&:name).join(', ')}"
  else
    warnings << "Sidekiq not configured - emails will be sent synchronously"
  end
rescue => e
  warnings << "Background jobs warning: #{e.message}"
end
puts ""

# Cleanup
puts "9️⃣  Cleaning Up Test Data..."
begin
  if defined?(cart_item) && cart_item
    cart_item.destroy
    puts "   ✅ Test cart item removed"
  end
rescue => e
  warnings << "Cleanup error: #{e.message}"
end
puts ""

# Summary
puts "=" * 80
puts "📊 TEST SUMMARY"
puts "=" * 80

if errors.empty? && warnings.empty?
  puts "✅ ALL TESTS PASSED!"
  puts ""
  puts "🎉 Your application is ready for end-to-end testing!"
  puts ""
  puts "📝 Next Steps:"
  puts "   1. Start both servers:"
  puts "      • Backend: cd hafaloha-api && bin/rails server"
  puts "      • Frontend: cd hafaloha-web && npm run dev"
  puts ""
  puts "   2. Open browser: http://localhost:5173"
  puts ""
  puts "   3. Test complete checkout flow:"
  puts "      • Browse products"
  puts "      • Add items to cart"
  puts "      • Go to checkout"
  puts "      • Fill shipping info"
  puts "      • Complete order (test mode)"
  puts ""
  puts "   4. Verify:"
  puts "      • Order confirmation page displays"
  puts "      • Email sent (if Resend configured)"
  puts "      • Inventory decremented"
  puts ""
elsif errors.any?
  puts "❌ ERRORS FOUND:"
  errors.each { |e| puts "   • #{e}" }
  puts ""
  puts "⚠️  Fix these errors before testing."
  exit 1
elsif warnings.any?
  puts "⚠️  WARNINGS:"
  warnings.each { |w| puts "   • #{w}" }
  puts ""
  puts "✅ Core functionality works, but some features may be limited."
  puts ""
  puts "You can proceed with testing, but consider:"
  puts "   • Adding Resend API key for email notifications"
  puts "   • Waiting for EasyPost approval for real shipping rates"
end

puts "=" * 80
puts ""

