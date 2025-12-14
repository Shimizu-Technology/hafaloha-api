# db/seeds.rb
# Seed file for Hafaloha wholesale platform
# 
# This file creates the minimum required data:
# - Admin user
# - Site settings
#
# For real products, use the Admin > Import UI

puts "=" * 80
puts "🌺 SEEDING HAFALOHA WHOLESALE PLATFORM"
puts "=" * 80
puts ""

# ------------------------------------------------------------------------------
# 1) ADMIN USER
# ------------------------------------------------------------------------------
puts "1️⃣  Creating admin user..."

admin = User.find_or_create_by!(email: "shimizutechnology@gmail.com") do |u|
  u.clerk_id = "seed_admin_#{SecureRandom.hex(8)}"
  u.name = "Leon Shimizu"
  u.phone = "+16714830219"
  u.role = "admin"
end

# Ensure the user is always an admin (in case they existed already)
admin.update!(role: "admin") unless admin.admin?

puts "   ✓ Admin: #{admin.email} (role: #{admin.role})"
puts ""

# ------------------------------------------------------------------------------
# 2) SITE SETTINGS
# ------------------------------------------------------------------------------
puts "2️⃣  Ensuring site settings exist..."

settings = SiteSetting.instance
puts "   ✓ Site Settings: test_mode=#{settings.payment_test_mode?}, emails=#{settings.send_customer_emails}"
puts ""

# ------------------------------------------------------------------------------
# 3) SAMPLE DATA (Development Only)
# ------------------------------------------------------------------------------
if Rails.env.development? || Rails.env.test?
  puts "3️⃣  Creating sample development data..."
  
  if Product.count == 0
    # Create a simple collection
    collection = Collection.find_or_create_by!(slug: "sample-collection") do |c|
      c.name = "Sample Collection"
      c.description = "Sample products for development"
      c.active = true
      c.published = true
      c.position = 1
    end
    
    # Create a simple product
    product = Product.find_or_create_by!(slug: "sample-tshirt") do |p|
      p.name = "Sample T-Shirt"
      p.description = "A sample product for development and testing"
      p.base_price_cents = 2999
      p.sku_prefix = "SAMPLE"
      p.published = true
      p.featured = true
      p.product_type = "apparel"
      p.vendor = "Hafaloha"
      p.inventory_level = "none"
      p.weight_oz = 6.5
    end
    
    product.collections << collection unless product.collections.include?(collection)
    
    # Create variants if none exist
    if product.product_variants.count == 0
      ["Small", "Medium", "Large"].each do |size|
        ["Black", "White"].each do |color|
          product.product_variants.create!(
            option1: size,
            option2: color,
            price_cents: product.base_price_cents,
            stock_quantity: 0,
            weight_oz: 6.5,
            available: true
          )
        end
      end
    end
    
    puts "   ✓ Created 1 sample product with #{product.product_variants.count} variants"
  else
    puts "   ⏭️  Products already exist, skipping sample data"
  end
  puts ""
else
  puts "3️⃣  Production environment - no sample data needed"
  puts ""
  puts "   💡 To import products, use the Admin dashboard:"
  puts "      1. Sign in as admin"
  puts "      2. Go to Admin > Import"
  puts "      3. Upload products_export.csv"
  puts ""
end

# ------------------------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------------------------
puts "=" * 80
puts "✅ SEED COMPLETE"
puts "=" * 80
puts ""
puts "📊 Summary:"
puts "   • Admin User: #{admin.email}"
puts "   • Collections: #{Collection.count}"
puts "   • Products: #{Product.count}"
puts "   • Variants: #{ProductVariant.count}"
puts ""
puts "🎉 Ready!"
puts "=" * 80
