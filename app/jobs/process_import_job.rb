require 'csv'
require 'open-uri'
require 'set'

class ProcessImportJob < ApplicationJob
  queue_as :default

  def perform(import_id, products_csv_path, inventory_csv_path = nil)
    import = Import.find(import_id)
    import.processing!
    
    Rails.logger.info "🚀 Starting import ##{import.id}"
    
    begin
      stats = {
        products_created: 0,
        variants_created: 0,
        variants_skipped: 0,  # Track skipped variants (missing SKU, etc.)
        images_created: 0,
        collections_created: 0,
        products_skipped: 0,
        warnings: [],
        created_products: [] # Track names of created products
      }
      
      # Parse products CSV
      csv_data = CSV.read(products_csv_path, headers: true, encoding: 'UTF-8')
      
      # Group rows by Handle (Shopify format)
      products_data = {}
      csv_data.each do |row|
        handle = row['Handle']
        products_data[handle] ||= []
        products_data[handle] << row
      end
      
      Rails.logger.info "📦 Found #{products_data.keys.length} unique products in CSV"
      
      # Prime import progress tracking
      total_products = products_data.keys.length
      import.update_progress(processed: 0, total: total_products, step: 'Preparing import')

      # Cache collections by slug to avoid repetitive lookups
      collection_cache = Collection.all.index_by(&:slug)

      # Process each product
      processed_products = 0
      products_data.each do |handle, rows|
        begin
          product_name = process_product(rows, stats, collection_cache)
          processed_products += 1
          import.update_progress(
            processed: processed_products,
            total: total_products,
            step: product_name ? "Processed #{product_name}" : "Processed #{processed_products} of #{total_products}"
          )
        rescue => e
          Rails.logger.error "❌ Failed to process product #{handle}: #{e.message}"
          stats[:warnings] << "ERROR processing #{handle}: #{e.message}"
          # Don't increment skip count here - only in process_product when intentionally skipping
          processed_products += 1
          import.update_progress(
            processed: processed_products,
            total: total_products,
            step: "Skipped #{handle} due to error"
          )
        end
      end
      
      # Parse inventory CSV if provided
      # NOTE: This feature is disabled in the UI until we receive real inventory data from Hafaloha
      # TODO: Test with actual Hafaloha inventory export before enabling
      if inventory_csv_path.present? && File.exist?(inventory_csv_path)
        update_inventory(inventory_csv_path, stats)
      end
      
      stats[:collections_created] = Collection.count
      Rails.logger.info "✅ Import complete: #{stats}"
      import.complete!(stats)
      
    rescue => e
      Rails.logger.error "❌ Import failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      import.fail!(e.message)
    ensure
      # Clean up temporary files
      File.delete(products_csv_path) if File.exist?(products_csv_path)
      File.delete(inventory_csv_path) if inventory_csv_path && File.exist?(inventory_csv_path)
    end
  end
  
  private
  
  def process_product(rows, stats, collection_cache)
    first_row = rows.first
    handle = first_row['Handle']
    has_variant_sku = rows.any? { |r| r['Variant SKU'].present? }
    
    # Check if product exists (only check active products, ignore archived)
    existing_product = Product.active.find_by(slug: handle)
    if existing_product
      Rails.logger.info "⏭️  Skipping existing product: #{first_row['Title']}"
      stats[:products_skipped] += 1
      stats[:warnings] << "Product already exists: #{first_row['Title']}"
      return
    end
    
    # Check if an archived product exists with this slug
    archived_product = Product.archived.find_by(slug: handle)
    if archived_product
      Rails.logger.info "📦 Found archived product, unarchiving and updating: #{first_row['Title']}"

      unless has_variant_sku
        Rails.logger.warn "⏭️  Skipping product with no variant SKUs: #{first_row['Title']}"
        stats[:products_skipped] += 1
        stats[:warnings] << "Skipped product (missing SKUs): #{first_row['Title']}"
        return
      end
      
      # Unarchive the product
      archived_product.update!(
        archived: false,
        published: first_row['Status'] == 'active',
        name: first_row['Title'],
        description: first_row['Body (HTML)'],
        base_price_cents: (first_row['Variant Price'].to_f * 100).to_i,
        weight_oz: (first_row['Variant Grams'].to_f / 28.3495).round(2),
        vendor: first_row['Vendor'],
        product_type: first_row['Type'],
        featured: false
      )
      
      # Update collections
      archived_product.collections.clear
      tags = first_row['Tags']&.split(',')&.map(&:strip) || []
      existing_collection_ids = Set.new
      tags.each do |tag_name|
        next if tag_name.blank?
        slug = tag_name.parameterize
        collection = collection_cache[slug]
        unless collection
          collection = Collection.create!(
            name: tag_name,
            slug: slug,
            published: true
          )
          collection_cache[slug] = collection
          stats[:collections_created] += 1
        end
        unless existing_collection_ids.include?(collection.id)
          archived_product.product_collections.create!(collection_id: collection.id)
          existing_collection_ids.add(collection.id)
        end
      end
      
      stats[:products_created] += 1
      stats[:created_products] << "#{archived_product.name} (unarchived)"
      stats[:warnings] << "Unarchived and updated: #{first_row['Title']}"
      
      # Use the unarchived product for variant processing
      product = archived_product
      
      # Continue to variant processing below
    else
      unless has_variant_sku
        Rails.logger.warn "⏭️  Skipping product with no variant SKUs: #{first_row['Title']}"
        stats[:products_skipped] += 1
        stats[:warnings] << "Skipped product (missing SKUs): #{first_row['Title']}"
        return
      end

      # Create new product (skip auto-default variant callback during import)
      product = Product.create!(
        name: first_row['Title'],
        slug: handle,
        description: first_row['Body (HTML)'],
        base_price_cents: (first_row['Variant Price'].to_f * 100).to_i,
        weight_oz: (first_row['Variant Grams'].to_f / 28.3495).round(2),
        sku_prefix: first_row['Variant SKU']&.split('-')&.first,
        vendor: first_row['Vendor'],
        product_type: first_row['Type'],
        published: first_row['Status'] == 'active',
        featured: false,
        inventory_level: 'none', # Default to no tracking
        product_stock_quantity: 0
      )
      
      # Manually remove auto-created default variant if any real variants exist in CSV
      # (The after_save callback creates a default before we add real variants)
      has_real_variants = rows.any? { |r| r['Variant SKU'].present? }
      if has_real_variants && product.product_variants.where(is_default: true).exists?
        product.product_variants.where(is_default: true).destroy_all
        Rails.logger.info "🗑️  Removed auto-created default variant (has real variants)"
      end
      
      Rails.logger.info "✅ Created product: #{product.name}"
      stats[:products_created] += 1
      stats[:created_products] << product.name # Track created product name
      
      # Create collections from tags
      tags = first_row['Tags']&.split(',')&.map(&:strip) || []
      existing_collection_ids = Set.new
      tags.each do |tag_name|
        next if tag_name.blank?
        slug = tag_name.parameterize
        collection = collection_cache[slug]
        unless collection
          collection = Collection.create!(
            name: tag_name,
            slug: slug,
            published: true
          )
          collection_cache[slug] = collection
          stats[:collections_created] += 1
        end
        unless existing_collection_ids.include?(collection.id)
          product.product_collections.create!(collection_id: collection.id)
          existing_collection_ids.add(collection.id)
        end
      end
    end
    
    # Process variants
    variants_for_this_product = 0
    skipped_for_missing_sku = 0
    
    existing_variant_skus = ProductVariant.where(sku: rows.map { |r| r['Variant SKU'] }.compact).pluck(:sku).to_set

    rows.each do |row|
      # Track rows with missing SKUs
      if row['Variant SKU'].blank?
        size_info = row['Option1 Value'].presence || 'unknown size'
        skipped_for_missing_sku += 1
        stats[:variants_skipped] += 1
        Rails.logger.warn "⚠️  Skipped variant with missing SKU: #{product.name} - #{size_info}"
        next
      end
      
      # Check for existing variant
      if existing_variant_skus.include?(row['Variant SKU'])
        Rails.logger.info "⏭️  Skipping existing variant: #{row['Variant SKU']}"
        stats[:variants_skipped] += 1
        next
      end
      
      variant = product.product_variants.create!(
        sku: row['Variant SKU'],
        size: row['Option1 Value'],
        color: row['Option2 Value'],
        material: row['Option3 Value'],
        price_cents: (row['Variant Price'].to_f * 100).to_i,
        compare_at_price_cents: row['Variant Compare At Price'].present? ? (row['Variant Compare At Price'].to_f * 100).to_i : nil,
        cost_cents: 0,
        stock_quantity: 0,
        available: true,
        is_default: false
      )
      
      variants_for_this_product += 1
      stats[:variants_created] += 1
      existing_variant_skus.add(row['Variant SKU'])
    end
    
    # Warn if variants were skipped due to missing SKUs
    if skipped_for_missing_sku > 0
      stats[:warnings] << "#{product.name}: Skipped #{skipped_for_missing_sku} variant(s) with missing SKU - please add SKUs in Shopify"
    end
    
    # Warn if product has no variants after processing (critical issue!)
    if product.product_variants.reload.count == 0
      stats[:warnings] << "⚠️ CRITICAL: #{product.name} has NO variants - product cannot be purchased!"
      Rails.logger.error "❌ Product #{product.name} has NO variants after import!"
    end
    
    # Download and upload images (in parallel batches for speed)
    image_urls = rows.map { |r| r['Image Src'] }.compact.uniq.reject { |url| skip_image?(url) }
    
    # Use parallel batches (5 at a time to avoid rate limits)
    image_mutex = Mutex.new
    position_counter = product.product_images.count
    
    image_urls.each_slice(5) do |batch_urls|
      threads = batch_urls.map do |url|
        Thread.new do
          begin
            # Download image with timeouts
            file = URI.open(url, read_timeout: 30, open_timeout: 10)
            filename = File.basename(URI.parse(url).path)
            
            # Upload to S3
            blob = ActiveStorage::Blob.create_and_upload!(
              io: file,
              filename: filename,
              content_type: file.content_type
            )
            
            # Thread-safe creation of ProductImage
            image_mutex.synchronize do
              is_primary = product.product_images.empty?
              product.product_images.create!(
                s3_key: blob.key,
                alt_text: product.name,
                primary: is_primary,
                position: position_counter
              )
              position_counter += 1
              stats[:images_created] += 1
            end
            
            Rails.logger.info "📷 Downloaded image: #{filename}"
          rescue => e
            Rails.logger.warn "⚠️  Failed to download image #{url}: #{e.message}"
            image_mutex.synchronize do
              stats[:warnings] << "Failed to download image: #{File.basename(url)}"
            end
          end
        end
      end
      
      # Wait for this batch to complete before starting next batch
      threads.each(&:join)
    end
    
    # Fix $0 base price if needed
    if product.base_price_cents == 0 && product.product_variants.any?
      min_price = product.product_variants.minimum(:price_cents)
      product.update!(base_price_cents: min_price) if min_price > 0
    end

    product.name
  end
  
  def skip_image?(url)
    return true if url.blank?
    
    # Skip known logo/placeholder images
    skip_patterns = [
      'ChristmasPua.png',
      'HafalohaLogo',
      'logo',
      'placeholder'
    ]
    
    skip_patterns.any? { |pattern| url.downcase.include?(pattern.downcase) }
  end
  
  def update_inventory(inventory_csv_path, stats)
    Rails.logger.info "📊 Updating inventory from CSV"
    
    csv_data = CSV.read(inventory_csv_path, headers: true, encoding: 'UTF-8')
    
    csv_data.each do |row|
      sku = row['SKU']
      quantity = row['Quantity'].to_i
      
      variant = ProductVariant.find_by(sku: sku)
      if variant
        variant.update!(stock_quantity: quantity)
        # Update product inventory level to variant tracking
        variant.product.update!(inventory_level: 'variant') unless variant.product.inventory_level == 'variant'
      end
    end
    
    Rails.logger.info "✅ Inventory updated"
  end
end

