# db/seeds.rb
# Seed file for Hafaloha wholesale platform

#
# This file creates sample data for development/testing.
# For REAL Hafaloha products, use the Shopify import:
#   bin/rails import:shopify[scripts/products_export.csv]

puts "=" * 80
puts "🌺 SEEDING HAFALOHA WHOLESALE PLATFORM"
puts "=" * 80
puts ""
puts "💡 TIP: For real Hafaloha products (50+ items), use:"
puts "   bin/rails import:shopify[scripts/products_export.csv]"
puts ""

# Clean up existing data (for fresh seeds)
if Rails.env.development? && ENV['RESET_DB'] == 'true'
  puts "⚠️  Resetting database..."
  [ProductImage, ProductVariant, ProductCollection, Product, Collection, 
   Participant, Fundraiser, Page].each do |model|
    model.destroy_all
  end
  puts "✓ Database reset complete"
  puts ""
end

# ------------------------------------------------------------------------------
# 1) ADMIN USER
# ------------------------------------------------------------------------------
puts "1️⃣  Creating admin user..."

admin = User.find_or_create_by!(email: "shimizutechnology@gmail.com") do |u|
  u.clerk_id = "seed_admin_#{SecureRandom.hex(8)}"
  u.name = "Leon Shimizu"
  u.phone = "+16714830219"
  u.role = "admin"
  u.admin = true
end

puts "   ✓ Admin: #{admin.email} (admin: #{admin.admin?})"
puts ""

# ------------------------------------------------------------------------------
# 2) COLLECTIONS
# ------------------------------------------------------------------------------
puts "2️⃣  Creating collections..."

mens_apparel = Collection.create!(
  name: "Men's Apparel",
  slug: "mens-apparel",
  description: "High-quality men's clothing featuring Håfaloha and Chamorro designs",
  active: true,
  featured: true,
  position: 1
)

womens_apparel = Collection.create!(
  name: "Women's Apparel",
  slug: "womens-apparel",
  description: "Stylish women's clothing with island-inspired designs",
  active: true,
  featured: true,
  position: 2
)

hats_accessories = Collection.create!(
  name: "Hats & Accessories",
  slug: "hats-accessories",
  description: "Complete your look with our selection of hats and accessories",
  active: true,
  featured: false,
  position: 3
)

bags = Collection.create!(
  name: "Bags & Totes",
  slug: "bags-totes",
  description: "Durable bags perfect for the beach or everyday use",
  active: true,
  featured: false,
  position: 4
)

athletic = Collection.create!(
  name: "Athletic Wear",
  slug: "athletic-wear",
  description: "Performance clothing for active lifestyles",
  active: true,
  featured: false,
  position: 5
)

puts "   ✓ Created #{Collection.count} collections"
puts ""

# ------------------------------------------------------------------------------
# 3) PRODUCTS - MEN'S APPAREL
# ------------------------------------------------------------------------------
puts "3️⃣  Creating products..."

# Men's Championship T-Shirt (already exists from test data, update it)
champ_tshirt = Product.find_or_create_by!(slug: "hafaloha-championship-t-shirt") do |p|
  p.name = "Håfaloha Championship T-Shirt"
  p.description = <<~DESC
    Premium cotton t-shirt featuring the iconic Håfaloha logo with Chamorro tribal designs.
    
    Made with 100% organic cotton for maximum comfort and durability. Perfect for casual wear or showing your island pride.
    
    Features:
    • 100% organic cotton
    • Pre-shrunk fabric
    • Ribbed crew neck
    • Shoulder-to-shoulder taping
    • Double-needle sleeve and bottom hem
  DESC
  p.base_price_cents = 2999
  p.sku_prefix = "HAF-TSHIRT-CHAMP"
  p.published = true
  p.featured = true
  p.product_type = "apparel"
  p.vendor = "Håfaloha"
  p.track_inventory = true
  p.weight_oz = 6.5
  p.meta_title = "Håfaloha Championship T-Shirt - Premium Island Apparel"
  p.meta_description = "Show your island pride with our premium Håfaloha Championship T-Shirt. 100% organic cotton, featuring authentic Chamorro designs."
end

champ_tshirt.collections << mens_apparel unless champ_tshirt.collections.include?(mens_apparel)

# Men's Guam Flag T-Shirt
guam_flag_tshirt = Product.create!(
  name: "Guam Flag T-Shirt",
  slug: "guam-flag-tshirt",
  description: <<~DESC
    Represent Guam with pride! Features the Guam flag design with 'Guahan' text.
    
    Made from soft, breathable cotton blend that's perfect for the island heat.
    
    Features:
    • 60% cotton, 40% polyester blend
    • Moisture-wicking
    • Tagless design
    • Printed with eco-friendly inks
  DESC
,  base_price_cents: 2799,
  sku_prefix: "HAF-TSHIRT-GUAM",
  published: true,
  featured: true,
  product_type: "apparel",
  vendor: "Håfaloha",
  track_inventory: true,
  weight_oz: 6.0,
  meta_title: "Guam Flag T-Shirt - Håfaloha",
  meta_description: "Represent Guam with this premium flag t-shirt featuring authentic island designs."
)

guam_flag_tshirt.collections << mens_apparel

# Men's Chamorro Warrior Hoodie
warrior_hoodie = Product.create!(
  name: "Chamorro Warrior Hoodie",
  slug: "chamorro-warrior-hoodie",
  description: <<~DESC
    Stay warm with our premium Chamorro Warrior hoodie featuring traditional tribal designs.
    
    Perfect for cool evenings or air-conditioned spaces. Features detailed artwork celebrating Chamorro heritage.
    
    Features:
    • 80% cotton, 20% polyester fleece
    • Adjustable drawstring hood
    • Front kangaroo pocket
    • Ribbed cuffs and waistband
    • Unisex sizing
  DESC
  base_price_cents: 4995,
  sku_prefix: "HAF-HOODIE-WARRIOR",
  published: true,
  featured: false,
  product_type: "apparel",
  vendor: "Håfaloha",
  track_inventory: true,
  weight_oz: 18.0,
  meta_title: "Chamorro Warrior Hoodie - Premium Island Apparel",
  meta_description: "Premium hoodie featuring authentic Chamorro warrior designs. Perfect for showing your island pride."
)

warrior_hoodie.collections << mens_apparel

# Men's Tank Top
mens_tank = Product.create!(
  name: "Håfaloha Island Tank Top",
  slug: "hafaloha-island-tank",
  description: <<~DESC
    Lightweight tank top perfect for the beach or gym.
    
    Features minimalist Håfaloha logo design. Made from moisture-wicking fabric.
    
    Features:
    • 100% polyester performance fabric
    • Moisture-wicking
    • Athletic fit
    • Racerback design
  DESC
  base_price_cents: 2499,
  sku_prefix: "HAF-TANK-MENS",
  published: true,
  featured: false,
  product_type: "apparel",
  vendor: "Håfaloha",
  track_inventory: true,
  weight_oz: 4.0
)

mens_tank.collections << [mens_apparel, athletic]

# ------------------------------------------------------------------------------
# 4) PRODUCTS - WOMEN'S APPAREL
# ------------------------------------------------------------------------------

# Women's V-Neck T-Shirt
womens_vneck = Product.create!(
  name: "Women's Håfaloha V-Neck",
  slug: "womens-hafaloha-vneck",
  description: <<~DESC
    Flattering v-neck t-shirt with Håfaloha logo.
    
    Soft, comfortable fit that's perfect for any occasion. Features a modern cut designed specifically for women.
    
    Features:
    • 100% combed ring-spun cotton
    • Side-seamed construction
    • Curved bottom hem
    • Shoulder-to-shoulder taping
  DESC
  base_price_cents: 2899,
  sku_prefix: "HAF-VNECK-WOMENS",
  published: true,
  featured: true,
  product_type: "apparel",
  vendor: "Håfaloha",
  track_inventory: true,
  weight_oz: 5.5
)

womens_vneck.collections << womens_apparel

# Women's Flowy Tank
womens_flowy_tank = Product.create!(
  name: "Women's Island Flowy Tank",
  slug: "womens-island-flowy-tank",
  description: <<~DESC
    Lightweight and flowy tank top perfect for island life.
    
    Features relaxed fit and soft fabric that drapes beautifully.
    
    Features:
    • 65% polyester, 35% viscose
    • Side-seamed
    • Curved bottom hem
    • Relaxed fit
  DESC
  base_price_cents: 2699,
  sku_prefix: "HAF-TANK-FLOWY",
  published: true,
  featured: false,
  product_type: "apparel",
  vendor: "Håfaloha",
  track_inventory: true,
  weight_oz: 4.5
)

womens_flowy_tank.collections << [womens_apparel, athletic]

# ------------------------------------------------------------------------------
# 5) PRODUCTS - HATS & ACCESSORIES
# ------------------------------------------------------------------------------

# Baseball Cap (already exists, update it)
baseball_cap = Product.find_or_create_by!(slug: "hafaloha-baseball-cap") do |p|
  p.name = "Håfaloha Baseball Cap"
  p.description = <<~DESC
    Classic snapback baseball cap with embroidered Håfaloha logo.
    
    Adjustable fit for all head sizes. Perfect for sunny island days.
    
    Features:
    • Structured 6-panel design
    • Embroidered logo
    • Adjustable snapback closure
    • Curved visor
    • One size fits most
  DESC
  p.base_price_cents = 2499
  p.sku_prefix = "HAF-CAP-SNAP"
  p.published = true
  p.featured = true
  p.product_type = "accessories"
  p.vendor = "Håfaloha"
  p.track_inventory = true
  p.weight_oz = 5.0
end

baseball_cap.collections << hats_accessories unless baseball_cap.collections.include?(hats_accessories)

# Trucker Hat
trucker_hat = Product.create!(
  name: "Håfaloha Trucker Hat",
  slug: "hafaloha-trucker-hat",
  description: <<~DESC
    Breathable mesh trucker hat with embroidered Håfaloha logo.
    
    Features:
    • Foam front panels
    • Mesh back for breathability
    • Adjustable snapback
    • Curved visor
  DESC
  base_price_cents: 2799,
  sku_prefix: "HAF-HAT-TRUCKER",
  published: true,
  featured: false,
  product_type: "accessories",
  vendor: "Håfaloha",
  track_inventory: true,
  weight_oz: 4.5
)

trucker_hat.collections << hats_accessories

# Beanie
beanie = Product.create!(
  name: "Håfaloha Beanie",
  slug: "hafaloha-beanie",
  description: <<~DESC
    Warm knit beanie with embroidered Håfaloha logo.
    
    Perfect for cool evenings or mountain trips.
    
    Features:
    • 100% acrylic knit
    • Cuffed design
    • Embroidered patch logo
    • One size fits most
  DESC
  base_price_cents: 1999,
  sku_prefix: "HAF-BEANIE",
  published: true,
  featured: false,
  product_type: "accessories",
  vendor: "Håfaloha",
  track_inventory: true,
  weight_oz: 3.0
)

beanie.collections << hats_accessories

# ------------------------------------------------------------------------------
# 6) PRODUCTS - BAGS
# ------------------------------------------------------------------------------

# Tote Bag
tote_bag = Product.create!(
  name: "Håfaloha Canvas Tote Bag",
  slug: "hafaloha-canvas-tote",
  description: <<~DESC
    Large canvas tote bag perfect for groceries, beach trips, or everyday use.
    
    Features screen-printed Håfaloha logo.
    
    Features:
    • 100% cotton canvas
    • Screen-printed design
    • Reinforced handles
    • Large capacity (15" x 16")
  DESC
  base_price_cents: 1499,
  sku_prefix: "HAF-TOTE",
  published: true,
  featured: false,
  product_type: "accessories",
  vendor: "Håfaloha",
  track_inventory: true,
  weight_oz: 8.0
)

tote_bag.collections << bags

# Drawstring Bag
drawstring_bag = Product.create!(
  name: "Håfaloha Drawstring Bag",
  slug: "hafaloha-drawstring-bag",
  description: <<~DESC
    Lightweight drawstring bag perfect for gym or beach.
    
    Features:
    • 100% polyester
    • Screen-printed logo
    • Drawstring closure
    • Reinforced corners
  DESC
  base_price_cents: 1299,
  sku_prefix: "HAF-DRAWSTRING",
  published: true,
  featured: false,
  product_type: "accessories",
  vendor: "Håfaloha",
  track_inventory: true,
  weight_oz: 3.5
)

drawstring_bag.collections << bags

puts "   ✓ Created #{Product.count} products"
puts ""

# ------------------------------------------------------------------------------
# 7) PRODUCT VARIANTS
# ------------------------------------------------------------------------------
puts "4️⃣  Creating product variants..."

variant_count = 0

# Championship T-Shirt Variants (S, M, L, XL, 2XL × Red, Black, White, Navy)
sizes = ["Small", "Medium", "Large", "X-Large", "2X-Large"]
colors = ["Red", "Black", "White", "Navy"]

sizes.each do |size|
  colors.each do |color|
    stock = case size
            when "Medium", "Large" then 50
            when "Small", "X-Large" then 30
            when "2X-Large" then 15
            end
    
    champ_tshirt.product_variants.create!(
      option1: size,
      option2: color,
      price_cents: champ_tshirt.base_price_cents,
      stock_quantity: stock,
      weight_oz: 6.5,
      active: true
    )
    variant_count += 1
  end
end

# Guam Flag T-Shirt Variants
sizes.each do |size|
  ["White", "Navy", "Gray"].each do |color|
    stock = rand(20..40)
    guam_flag_tshirt.product_variants.create!(
      option1: size,
      option2: color,
      price_cents: guam_flag_tshirt.base_price_cents,
      stock_quantity: stock,
      weight_oz: 6.0,
      active: true
    )
    variant_count += 1
  end
end

# Warrior Hoodie Variants
sizes.each do |size|
  ["Black", "Gray", "Navy"].each do |color|
    stock = rand(15..30)
    warrior_hoodie.product_variants.create!(
      option1: size,
      option2: color,
      price_cents: warrior_hoodie.base_price_cents,
      stock_quantity: stock,
      weight_oz: 18.0,
      active: true
    )
    variant_count += 1
  end
end

# Men's Tank Variants
["Small", "Medium", "Large", "X-Large"].each do |size|
  ["Black", "Gray", "White"].each do |color|
    mens_tank.product_variants.create!(
      option1: size,
      option2: color,
      price_cents: mens_tank.base_price_cents,
      stock_quantity: rand(20..35),
      weight_oz: 4.0,
      active: true
    )
    variant_count += 1
  end
end

# Women's V-Neck Variants
["Small", "Medium", "Large", "X-Large"].each do |size|
  ["Pink", "White", "Black", "Turquoise"].each do |color|
    womens_vneck.product_variants.create!(
      option1: size,
      option2: color,
      price_cents: womens_vneck.base_price_cents,
      stock_quantity: rand(25..40),
      weight_oz: 5.5,
      active: true
    )
    variant_count += 1
  end
end

# Women's Flowy Tank Variants
["Small", "Medium", "Large"].each do |size|
  ["White", "Pink", "Coral", "Mint"].each do |color|
    womens_flowy_tank.product_variants.create!(
      option1: size,
      option2: color,
      price_cents: womens_flowy_tank.base_price_cents,
      stock_quantity: rand(20..30),
      weight_oz: 4.5,
      active: true
    )
    variant_count += 1
  end
end

# Baseball Cap Variants (One Size × Multiple Colors)
["Black", "Red", "White", "Navy", "Gray"].each do |color|
  baseball_cap.product_variants.create!(
    option1: "One Size",
    option2: color,
    price_cents: baseball_cap.base_price_cents,
    stock_quantity: rand(40..60),
    weight_oz: 5.0,
    active: true
  )
  variant_count += 1
end

# Trucker Hat Variants
["Black/White", "Red/White", "Navy/White"].each do |color|
  trucker_hat.product_variants.create!(
    option1: "One Size",
    option2: color,
    price_cents: trucker_hat.base_price_cents,
    stock_quantity: rand(30..50),
    weight_oz: 4.5,
    active: true
  )
  variant_count += 1
end

# Beanie Variants
["Black", "Gray", "Navy", "Red"].each do |color|
  beanie.product_variants.create!(
    option1: "One Size",
    option2: color,
    price_cents: beanie.base_price_cents,
    stock_quantity: rand(25..40),
    weight_oz: 3.0,
    active: true
  )
  variant_count += 1
end

# Tote Bag Variants (Natural color only, but different styles)
["Natural Canvas", "Black Canvas"].each do |style|
  tote_bag.product_variants.create!(
    option1: style,
    price_cents: tote_bag.base_price_cents,
    stock_quantity: rand(40..70),
    weight_oz: 8.0,
    active: true
  )
  variant_count += 1
end

# Drawstring Bag Variants
["Black", "Red", "Navy", "Gray"].each do |color|
  drawstring_bag.product_variants.create!(
    option1: color,
    price_cents: drawstring_bag.base_price_cents,
    stock_quantity: rand(50..80),
    weight_oz: 3.5,
    active: true
  )
  variant_count += 1
end

puts "   ✓ Created #{variant_count} product variants"
puts ""

# ------------------------------------------------------------------------------
# 8) PAGES
# ------------------------------------------------------------------------------
puts "5️⃣  Creating pages..."

about_page = Page.find_or_create_by!(slug: "about-us") do |p|
  p.title = "About Us"
  p.content = <<~CONTENT
    # About Håfaloha
    
    Håfaloha is more than just a brand—it's a celebration of Chamorro culture and island pride.
    
    ## Our Story
    
    Founded in Guam, Håfaloha started with a simple mission: to create high-quality apparel that represents the unique spirit of the Mariana Islands.
    
    ## Our Values
    
    - **Quality First**: We use only premium materials and printing techniques
    - **Cultural Pride**: Every design celebrates our Chamorro heritage
    - **Community Support**: We give back to local organizations and fundraisers
    - **Sustainability**: We're committed to environmentally responsible practices
    
    ## Contact Us
    
    Have questions? Reach out to us:
    - Email: sales@hafaloha.com
    - Phone: +1 (671) 989-3444
    - Location: 955 Pale San Vitores Rd, Tamuning, Guam 96913
  CONTENT
  p.published = true
  p.seo_title = "About Håfaloha - Island Pride, Chamorro Culture"
  p.seo_description = "Learn about Håfaloha's mission to celebrate Chamorro culture through premium apparel and accessories."
end

shipping_page = Page.create!(
  title: "Shipping & Returns",
  slug: "shipping-returns",
  content: <<~CONTENT
    # Shipping & Returns
    
    ## Shipping Information
    
    We ship worldwide! Shipping rates are calculated at checkout based on your location and order size.
    
    **Processing Time**: 1-3 business days  
    **Shipping Time**: 5-10 business days (domestic), 10-20 business days (international)
    
    ## Returns & Exchanges
    
    We want you to love your Håfaloha gear! If you're not satisfied:
    
    - **30-day return policy**
    - Items must be unworn and in original condition
    - Return shipping costs are the responsibility of the customer
    
    Contact us at sales@hafaloha.com to initiate a return.
  CONTENT
  published: true,
  seo_title: "Shipping & Returns - Håfaloha",
  seo_description: "Learn about Håfaloha's shipping options and return policy."
)

puts "   ✓ Created #{Page.count} pages"
puts ""

# ------------------------------------------------------------------------------
# 9) SAMPLE FUNDRAISER
# ------------------------------------------------------------------------------
puts "6️⃣  Creating sample fundraiser..."

sample_fundraiser = Fundraiser.create!(
  name: "John F. Kennedy High School Athletic Department",
  slug: "jfk-athletics-2025",
  description: <<~DESC
    Support JFK High School Athletics! 
    
    All proceeds go directly to our athletic programs, helping student-athletes compete at the highest level.
    
    Order your Håfaloha gear and support our teams!
  DESC
  start_date: Date.today,
  end_date: Date.today + 30.days,
  goal_amount_cents: 500000, # $5,000 goal
  current_amount_cents: 0,
  contact_name: "Coach Mike Santos",
  contact_email: "coach@jfk.edu",
  contact_phone: "+16717891234",
  pickup_address_line1: "1316 Chalan Kanton Tasi",
  pickup_city: "Tamuning",
  pickup_state: "GU",
  pickup_zip_code: "96913",
  pickup_country: "US",
  active: true
)

# Create participants
5.times do |i|
  Participant.create!(
    fundraiser: sample_fundraiser,
    name: "Student #{i + 1}",
    email: "student#{i + 1}@jfk.edu",
    goal_amount_cents: 100000, # $1,000 per student
    current_amount_cents: 0,
    active: true
  )
end

puts "   ✓ Created fundraiser with #{sample_fundraiser.participants.count} participants"
puts ""

# ------------------------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------------------------
puts "=" * 80
puts "✅ SEED COMPLETE"
puts "=" * 80
puts ""
puts "📊 Summary:"
puts "   • Admin User: #{User.where(admin: true).count} (#{admin.email})"
puts "   • Collections: #{Collection.count}"
puts "   • Products: #{Product.count}"
puts "   • Variants: #{ProductVariant.count}"
puts "   • Pages: #{Page.count}"
puts "   • Fundraisers: #{Fundraiser.count}"
puts "   • Participants: #{Participant.count}"
puts ""
puts "🎉 Ready to browse the catalog!"
puts "=" * 80
