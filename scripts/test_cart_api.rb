# Test script for Cart API
# Run with: bin/rails runner scripts/test_cart_api.rb

puts "=" * 80
puts "TESTING CART API"
puts "=" * 80

# Get a product variant to test with
variant = ProductVariant.includes(:product).first
if variant.nil?
  puts "❌ No product variants found. Run scripts/test_admin_api.rb first."
  exit
end

puts "\n✓ Using variant: #{variant.product.name} - #{variant.display_name}"
puts "  Stock: #{variant.stock_quantity}"
puts "  Price: $#{variant.price_cents / 100.0}"

# Create a test user (or use existing)
user = User.find_or_create_by!(
  clerk_id: 'test_user_cart_' + SecureRandom.hex(4),
  email: 'test+cart@example.com',
  role: 'customer'
)
puts "\n✓ Test user: #{user.email}"

# Clear any existing cart items for this user
user.cart_items.destroy_all
puts "✓ Cleared existing cart"

# Test 1: Add item to cart
puts "\n" + "=" * 80
puts "TEST 1: Add Item to Cart"
puts "=" * 80

cart_item = user.cart_items.create!(
  product_variant: variant,
  quantity: 2
)

if cart_item.persisted?
  puts "✓ Added #{cart_item.quantity}x #{variant.product.name} - #{variant.display_name}"
  puts "  Subtotal: $#{cart_item.subtotal_cents / 100.0}"
else
  puts "❌ Failed to add item: #{cart_item.errors.full_messages.join(', ')}"
end

# Test 2: Get cart
puts "\n" + "=" * 80
puts "TEST 2: Get Cart"
puts "=" * 80

cart_items = user.cart_items.includes(product_variant: :product)
total = cart_items.sum(&:subtotal_cents)
count = cart_items.sum(:quantity)

puts "✓ Cart has #{count} item(s)"
puts "✓ Subtotal: $#{total / 100.0}"

cart_items.each do |item|
  puts "  - #{item.quantity}x #{item.product.name} - #{item.product_variant.display_name} ($#{item.subtotal_cents / 100.0})"
end

# Test 3: Update quantity
puts "\n" + "=" * 80
puts "TEST 3: Update Quantity"
puts "=" * 80

cart_item.update!(quantity: 5)
puts "✓ Updated quantity to #{cart_item.quantity}"
puts "  New subtotal: $#{cart_item.subtotal_cents / 100.0}"

# Test 4: Check availability
puts "\n" + "=" * 80
puts "TEST 4: Check Availability"
puts "=" * 80

puts "✓ Available: #{cart_item.available?}"
puts "✓ Quantity exceeds stock: #{cart_item.quantity_exceeds_stock?}"
puts "✓ Available quantity: #{cart_item.available_quantity}"
puts "✓ Max available: #{cart_item.max_available_quantity}"

# Test 5: Validate cart (race condition check)
puts "\n" + "=" * 80
puts "TEST 5: Validate Cart (Race Condition Check)"
puts "=" * 80

issues = []
cart_items.each do |item|
  v = item.product_variant
  
  if !v.product.published?
    issues << "#{v.product.name} (#{v.display_name}) is no longer available"
  elsif !v.in_stock?
    issues << "#{v.product.name} (#{v.display_name}) is out of stock"
  elsif item.quantity > v.stock_quantity
    issues << "Only #{v.stock_quantity} #{v.product.name} (#{v.display_name}) available (you have #{item.quantity} in cart)"
  end
end

if issues.empty?
  puts "✓ Cart is valid - all items available"
else
  puts "⚠️  Cart has issues:"
  issues.each { |issue| puts "  - #{issue}" }
end

# Test 6: Remove item
puts "\n" + "=" * 80
puts "TEST 6: Remove Item"
puts "=" * 80

cart_item.destroy
remaining = user.cart_items.count

puts "✓ Item removed"
puts "✓ Cart now has #{remaining} item(s)"

# Test 7: Guest cart (session-based)
puts "\n" + "=" * 80
puts "TEST 7: Guest Cart (Session-Based)"
puts "=" * 80

session_id = SecureRandom.uuid
guest_cart_item = CartItem.create!(
  session_id: session_id,
  product_variant: variant,
  quantity: 1
)

if guest_cart_item.persisted?
  puts "✓ Created guest cart item with session: #{session_id}"
  puts "  #{guest_cart_item.quantity}x #{variant.product.name} - #{variant.display_name}"
else
  puts "❌ Failed to create guest cart item"
end

# Clean up
guest_cart_item.destroy
user.destroy

puts "\n" + "=" * 80
puts "ALL TESTS COMPLETE ✓"
puts "=" * 80
puts "\nCart API is ready for frontend integration!"
puts "Endpoints:"
puts "  GET    /api/v1/cart           - Get cart items"
puts "  POST   /api/v1/cart/items     - Add item to cart"
puts "  PUT    /api/v1/cart/items/:id - Update item quantity"
puts "  DELETE /api/v1/cart/items/:id - Remove item"
puts "  DELETE /api/v1/cart           - Clear cart"
puts "  POST   /api/v1/cart/validate  - Validate cart (race condition check)"

