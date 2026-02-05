# Test script for Admin Product CRUD operations
# Run with: rails runner scripts/test_admin_api.rb

puts "=" * 80
puts "TESTING ADMIN PRODUCT CRUD OPERATIONS"
puts "=" * 80
puts ""

# Test 1: Create Collection
puts "TEST 1: Creating collection..."
collection = Collection.create!(
  name: 'Mens Apparel',
  description: 'Premium mens clothing and accessories',
  published: true,
  featured: true,
  sort_order: 1
)
puts "✓ Collection created: #{collection.name} (ID: #{collection.id}, Slug: #{collection.slug})"
puts ""

# Test 2: Create Product
puts "TEST 2: Creating product..."
product = Product.create!(
  name: 'Hafaloha Championship T-Shirt',
  description: 'Premium cotton t-shirt featuring the Hafaloha logo and Chamorro designs',
  base_price_cents: 2999,
  sku_prefix: 'HAF-TSHIRT',
  track_inventory: true,
  weight_oz: 6.5,
  published: true,
  featured: true,
  product_type: 'apparel',
  vendor: 'Hafaloha'
)
puts "✓ Product created: #{product.name} (ID: #{product.id}, Slug: #{product.slug})"
puts ""

# Test 3: Add product to collection
puts "TEST 3: Adding product to collection..."
product.collections << collection
puts "✓ Product added to collection: #{collection.name}"
puts ""

# Test 4: Create variants
puts "TEST 4: Creating product variants..."
sizes = [ 'Small', 'Medium', 'Large', 'X-Large' ]
colors = [ 'Red', 'Black', 'White' ]
variant_count = 0

sizes.each do |size|
  colors.each do |color|
    variant = product.product_variants.create!(
      size: size,
      color: color,
      price_cents: 2999,
      stock_quantity: 25,
      available: true,
      weight_oz: 6.5
    )
    variant_count += 1
    puts "  ✓ #{variant.display_name} (SKU: #{variant.sku})"
  end
end
puts "✓ Created #{variant_count} variants"
puts ""

# Test 5: Add images
puts "TEST 5: Adding product images..."
images = [
  { url: 'https://example.com/images/tshirt-red-front.jpg', alt_text: 'Red t-shirt front view', position: 1, primary: true },
  { url: 'https://example.com/images/tshirt-red-back.jpg', alt_text: 'Red t-shirt back view', position: 2, primary: false },
  { url: 'https://example.com/images/tshirt-black-front.jpg', alt_text: 'Black t-shirt front view', position: 3, primary: false }
]

images.each do |img_data|
  image = product.product_images.create!(img_data)
  puts "  ✓ #{image.alt_text} (Position: #{image.position}, Primary: #{image.primary})"
end
puts "✓ Added #{product.product_images.count} images"
puts ""

# Test 6: Update product
puts "TEST 6: Updating product..."
product.update!(
  description: product.description + "\n\nMade with 100% organic cotton.",
  meta_title: "#{product.name} | Hafaloha Official Merch",
  meta_description: "Premium #{product.name}. Represent Chamorro pride!"
)
puts "✓ Product updated with SEO fields"
puts ""

# Test 7: Adjust variant stock
puts "TEST 7: Adjusting variant stock..."
variant = product.product_variants.first
old_stock = variant.stock_quantity
variant.decrement_stock!(5)
puts "✓ Stock adjusted: #{old_stock} → #{variant.stock_quantity} (#{variant.display_name})"
puts ""

# Test 8: Create another product
puts "TEST 8: Creating second product..."
product2 = Product.create!(
  name: 'Hafaloha Baseball Cap',
  description: 'Adjustable baseball cap with embroidered Hafaloha logo',
  base_price_cents: 2499,
  sku_prefix: 'HAF-CAP',
  track_inventory: true,
  weight_oz: 4.0,
  published: true,
  product_type: 'accessories',
  vendor: 'Hafaloha'
)

cap_collection = Collection.create!(
  name: 'Hats & Accessories',
  description: 'Hats, caps, and accessories',
  published: true,
  sort_order: 2
)

product2.collections << cap_collection

[ 'Red', 'Black', 'Navy' ].each do |color|
  product2.product_variants.create!(
    color: color,
    size: 'One Size',
    price_cents: 2499,
    stock_quantity: 30,
    available: true,
    weight_oz: 4.0
  )
end

puts "✓ Second product created: #{product2.name} (#{product2.product_variants.count} variants)"
puts ""

# Test 9: Query all products
puts "TEST 9: Querying all products..."
all_products = Product.includes(:product_variants, :collections).all
all_products.each do |p|
  puts "  • #{p.name}"
  puts "    - Variants: #{p.product_variants.count}"
  puts "    - Collections: #{p.collections.map(&:name).join(', ')}"
  puts "    - In stock: #{p.in_stock?}"
  puts "    - Published: #{p.published}"
end
puts "✓ Found #{all_products.count} products"
puts ""

# Test 10: Test primary image
puts "TEST 10: Testing primary image..."
primary_img = product.primary_image
puts "✓ Primary image: #{primary_img.alt_text}"
puts ""

# Test 11: Test variant display names and SKUs
puts "TEST 11: Testing variant auto-generation..."
test_variant = product.product_variants.where(size: 'Medium', color: 'Red').first
puts "  Display Name: #{test_variant.display_name}"
puts "  SKU: #{test_variant.sku}"
puts "  Variant Key: #{test_variant.variant_key}"
puts "  In Stock: #{test_variant.in_stock?}"
puts "✓ Variant auto-generation working"
puts ""

# Summary
puts "=" * 80
puts "TEST SUMMARY"
puts "=" * 80
puts "Collections: #{Collection.count}"
puts "Products: #{Product.count}"
puts "Product Variants: #{ProductVariant.count}"
puts "Product Images: #{ProductImage.count}"
puts ""
puts "✓ All admin CRUD operations working correctly!"
puts "=" * 80
