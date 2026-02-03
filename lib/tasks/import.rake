require 'csv'
require 'open-uri'
require 'aws-sdk-s3'

namespace :import do
  desc "Import products from Shopify CSV export (optionally with inventory CSV)"
  task :shopify_csv, [:products_file, :inventory_file] => :environment do |_t, args|
    unless args[:products_file]
      puts "❌ Usage: rails import:shopify_csv[products_export.csv] or rails import:shopify_csv[products_export.csv,inventory.csv]"
      exit 1
    end

    products_file = args[:products_file]
    inventory_file = args[:inventory_file]

    unless File.exist?(products_file)
      puts "❌ Products file not found: #{products_file}"
      exit 1
    end

    if inventory_file && !File.exist?(inventory_file)
      puts "❌ Inventory file not found: #{inventory_file}"
      exit 1
    end

    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "📦 SHOPIFY CSV IMPORTER"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "Products file: #{products_file}"
    puts "Inventory file: #{inventory_file || 'None (inventory tracking OFF)'}"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts ""

    importer = ShopifyImporter.new(products_file, inventory_file)
    importer.import!
  end
end

class ShopifyImporter
  attr_reader :products_file, :inventory_file, :stats

  def initialize(products_file, inventory_file = nil)
    @products_file = products_file
    @inventory_file = inventory_file
    @stats = {
      products_created: 0,
      variants_created: 0,
      images_created: 0,
      collections_created: 0,
      errors: []
    }
    @inventory_data = {}
    @s3_client = initialize_s3_client
  end

  def import!
    ActiveRecord::Base.transaction do
      load_inventory_data if @inventory_file
      parse_and_import_products
      print_summary
    end
  rescue => e
    puts "❌ Import failed: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    raise ActiveRecord::Rollback
  end

  private

  def initialize_s3_client
    Aws::S3::Client.new(
      region: ENV['AWS_REGION'] || 'us-west-2',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
  end

  def load_inventory_data
    puts "📊 Loading inventory data..."
    CSV.foreach(@inventory_file, headers: true) do |row|
      sku = row['SKU'] || row['sku'] || row['Variant SKU']
      quantity = (row['Quantity'] || row['quantity'] || row['Stock'] || row['stock'] || row['Available'] || 0).to_i
      @inventory_data[sku] = quantity if sku
    end
    puts "✅ Loaded inventory for #{@inventory_data.size} SKUs"
    puts ""
  end

  def parse_and_import_products
    puts "📦 Parsing products CSV..."
    
    # Group rows by Handle (product)
    products_data = {}
    
    CSV.foreach(@products_file, headers: true) do |row|
      handle = row['Handle']
      next if handle.blank?
      
      products_data[handle] ||= { product_info: nil, variants: [], images: {}, option_names: {} }
      
      # First row for this handle = product info + option names
      if products_data[handle][:product_info].nil?
        products_data[handle][:product_info] = extract_product_info(row)
        # Preserve Option1 Name and Option2 Name from first row
        # Shopify CSVs only include option names in the first row per product
        products_data[handle][:option_names] = {
          option1_name: row['Option1 Name'],
          option2_name: row['Option2 Name'],
          option3_name: row['Option3 Name']
        }
      end
      
      # Every row = variant (use preserved option names if row is empty)
      products_data[handle][:variants] << extract_variant_info(row, products_data[handle][:option_names])
      
      # Collect images
      if row['Image Src'].present?
        position = row['Image Position'].to_i
        products_data[handle][:images][position] = {
          url: row['Image Src'],
          alt_text: row['Image Alt Text'],
          position: position
        }
      end
    end
    
    puts "✅ Found #{products_data.size} unique products"
    puts ""
    
    # Import each product
    products_data.each do |handle, data|
      import_product(handle, data)
    end
  end

  def extract_product_info(row)
    {
      handle: row['Handle'],
      title: row['Title'],
      description: row['Body (HTML)'],
      vendor: row['Vendor'],
      product_type: row['Type'],
      tags: row['Tags'],
      published: row['Published']&.downcase == 'true',
      status: row['Status']
    }
  end

  def extract_variant_info(row, option_names = {})
    # Use option names from first row if current row's option name is blank
    # This fixes Shopify's CSV format where option names only appear in first row
    {
      option1_name: row['Option1 Name'].presence || option_names[:option1_name],
      option1_value: row['Option1 Value'],
      option2_name: row['Option2 Name'].presence || option_names[:option2_name],
      option2_value: row['Option2 Value'],
      option3_name: row['Option3 Name'].presence || option_names[:option3_name],
      option3_value: row['Option3 Value'],
      sku: row['Variant SKU'],
      price: row['Variant Price'].to_f,
      compare_at_price: row['Variant Compare At Price'].to_f,
      cost: row['Cost per item'].to_f,
      grams: row['Variant Grams'].to_f,
      barcode: row['Variant Barcode']
    }
  end

  def import_product(handle, data)
    product_info = data[:product_info]
    variants = data[:variants]
    images = data[:images]
    
    puts "📦 Importing: #{product_info[:title]}"
    
    # Check if product already exists (duplicate)
    existing_product = Product.find_by(slug: product_info[:handle])
    if existing_product
      puts "   ⏭️  Product already exists (slug: #{product_info[:handle]}), skipping..."
      @stats[:skipped] ||= 0
      @stats[:skipped] += 1
      return
    end
    
    # Check for duplicate SKUs
    duplicate_skus = variants.map { |v| v[:sku] }.compact.select { |sku| ProductVariant.exists?(sku: sku) }
    if duplicate_skus.any?
      puts "   ⏭️  Duplicate SKUs found (#{duplicate_skus.first}), skipping..."
      @stats[:skipped] ||= 0
      @stats[:skipped] += 1
      return
    end
    
    # Determine inventory level
    inventory_level = @inventory_file ? 'variant' : 'none'
    
    # Use a database transaction to ensure ALL-or-NOTHING import
    ActiveRecord::Base.transaction do
      # Extract SKU prefix from first variant
      first_sku = variants.first[:sku]
      sku_prefix = extract_sku_prefix(first_sku)
      
      # Calculate base price (lowest variant price)
      base_price_cents = (variants.map { |v| v[:price] }.min * 100).to_i
      
      # Calculate average weight
      avg_weight_grams = variants.map { |v| v[:grams] }.compact.sum / variants.size.to_f
      weight_oz = grams_to_oz(avg_weight_grams)
      
      # Create product
      product = Product.create!(
        name: product_info[:title],
        slug: product_info[:handle],
        description: product_info[:description],
        vendor: product_info[:vendor],
        product_type: product_info[:product_type],
        sku_prefix: sku_prefix,
        base_price_cents: base_price_cents,
        weight_oz: weight_oz,
        published: product_info[:published] && product_info[:status]&.downcase == 'active',
        inventory_level: inventory_level,
        featured: false
      )
      
      @stats[:products_created] += 1
      
      # Create variants
      variants.each do |variant_data|
        create_variant(product, variant_data)
      end
      
      # Fix $0 base price - use lowest variant price if base is $0
      if product.base_price_cents == 0
        lowest_variant_price = product.product_variants.where('price_cents > 0').minimum(:price_cents)
        if lowest_variant_price
          product.update!(base_price_cents: lowest_variant_price)
          puts "   💡 Fixed $0 base price → $#{lowest_variant_price / 100.0}"
        end
      end
      
      # Create images
      images.values.sort_by { |img| img[:position] }.each do |image_data|
        create_image(product, image_data)
      end
      
      # Create collections from tags
      create_collections(product, product_info[:tags])
      
      puts "   ✅ Product: #{product.name}"
      puts "   ✅ Variants: #{variants.size}"
      puts "   ✅ Images: #{images.size}"
      puts ""
    end
    
  rescue ActiveRecord::RecordInvalid => e
    @stats[:errors] << "#{product_info[:title]}: Validation error - #{e.message}"
    puts "   ❌ Validation Error: #{e.message}"
    puts "   💡 Tip: Check for duplicate SKUs or missing required fields"
    puts ""
  rescue => e
    @stats[:errors] << "#{product_info[:title]}: #{e.message}"
    puts "   ❌ Error: #{e.message}"
    puts "   💡 Product import rolled back (transaction)"
    puts ""
  end

  def create_variant(product, variant_data)
    # Determine size and color from options
    size = nil
    color = nil
    
    if variant_data[:option1_name]&.downcase == 'size'
      size = variant_data[:option1_value]
    elsif variant_data[:option1_name]&.downcase == 'color'
      color = variant_data[:option1_value]
    end
    
    if variant_data[:option2_name]&.downcase == 'color'
      color = variant_data[:option2_value]
    elsif variant_data[:option2_name]&.downcase == 'size'
      size = variant_data[:option2_value]
    end
    
    # Default to "Default" if no size/color
    size ||= variant_data[:option1_value] || 'Default'
    
    # Build variant name
    variant_name = [size, color].compact.join(' - ')
    
    # Get stock quantity from inventory file (if provided)
    stock_quantity = @inventory_data[variant_data[:sku]] || 0
    
    # Convert prices to cents
    price_cents = (variant_data[:price] * 100).to_i
    compare_at_price_cents = variant_data[:compare_at_price].positive? ? (variant_data[:compare_at_price] * 100).to_i : nil
    cost_cents = variant_data[:cost].positive? ? (variant_data[:cost] * 100).to_i : nil
    
    # Convert weight
    weight_oz = grams_to_oz(variant_data[:grams])
    
    variant = product.product_variants.create!(
      size: size,
      color: color,
      variant_name: variant_name,
      sku: variant_data[:sku],
      price_cents: price_cents,
      compare_at_price_cents: compare_at_price_cents,
      cost_cents: cost_cents,
      weight_oz: weight_oz,
      barcode: variant_data[:barcode],
      stock_quantity: stock_quantity,
      available: true,
      is_default: false
    )
    
    @stats[:variants_created] += 1
  end

  def create_image(product, image_data)
    return if image_data[:url].blank?
    
    # Skip logo/placeholder images
    if skip_image?(image_data)
      puts "   ⏭️  Skipped logo/placeholder image"
      return
    end
    
    begin
      # Download image from Shopify CDN
      image_url = image_data[:url]
      
      # Generate S3 key
      file_extension = File.extname(URI.parse(image_url).path)
      s3_key = "products/#{product.slug}/#{SecureRandom.uuid}#{file_extension}"
      
      # Download and upload to S3
      URI.open(image_url) do |image|
        @s3_client.put_object(
          bucket: ENV['AWS_S3_BUCKET'],
          key: s3_key,
          body: image,
          acl: 'private',
          content_type: content_type_for_extension(file_extension)
        )
      end
      
      # Create ProductImage record
      product.product_images.create!(
        s3_key: s3_key,
        url: image_url, # Keep original URL as reference
        position: image_data[:position],
        primary: image_data[:position] == 1,
        alt_text: image_data[:alt_text]
      )
      
      @stats[:images_created] += 1
    rescue => e
      puts "   ⚠️  Image upload failed: #{e.message}"
    end
  end

  def skip_image?(image_data)
    url = image_data[:url]
    alt_text = image_data[:alt_text]
    
    # Skip Hafaloha logo/icon images
    return true if url&.include?('ChristmasPua.png')
    return true if url&.include?('HafalohaIcon')
    return true if url&.include?('logo')
    return true if alt_text&.downcase&.include?('placeholder')
    return true if alt_text&.downcase&.include?('logo')
    
    false
  end

  def create_collections(product, tags_string)
    return if tags_string.blank?
    
    tags = tags_string.split(',').map(&:strip)
    
    tags.each do |tag|
      next if tag.blank?
      
      slug = tag.parameterize
      
      collection = Collection.find_or_create_by!(slug: slug) do |c|
        c.name = tag
        c.published = true
        c.featured = false
        @stats[:collections_created] += 1
      end
      
      # Link product to collection
      ProductCollection.find_or_create_by!(
        product: product,
        collection: collection
      )
    end
  end

  def extract_sku_prefix(sku)
    return nil if sku.blank?
    
    # Remove last part after hyphen (usually size)
    parts = sku.split('-')
    parts.pop if parts.size > 1
    parts.join('-')
  end

  def grams_to_oz(grams)
    return nil if grams.nil? || grams.zero?
    (grams * 0.035274).round(2)
  end

  def content_type_for_extension(ext)
    case ext.downcase
    when '.jpg', '.jpeg' then 'image/jpeg'
    when '.png' then 'image/png'
    when '.gif' then 'image/gif'
    when '.webp' then 'image/webp'
    else 'application/octet-stream'
    end
  end

  def print_summary
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "✅ IMPORT COMPLETE!"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "Products created: #{@stats[:products_created]}"
    puts "Products skipped (duplicates): #{@stats[:skipped] || 0}"
    puts "Variants created: #{@stats[:variants_created]}"
    puts "Images created: #{@stats[:images_created]}"
    puts "Collections created: #{@stats[:collections_created]}"
    
    if @inventory_file
      puts "Inventory tracking: ON (variant-level)"
    else
      puts "Inventory tracking: OFF (all products available)"
    end
    
    if @stats[:errors].any?
      puts ""
      puts "⚠️  Errors (#{@stats[:errors].size}):"
      @stats[:errors].each { |err| puts "  - #{err}" }
    end
    
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  end
end

