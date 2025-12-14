require 'csv'
require 'open-uri'
require 'tempfile'

namespace :fix do
  desc "Fix missing images for products by fetching from Shopify CSV"
  task :missing_images, [:csv_file] => :environment do |t, args|
    csv_file = args[:csv_file] || '../products_export.csv'
    
    unless File.exist?(csv_file)
      puts "❌ Error: CSV file not found: #{csv_file}"
      exit 1
    end
    
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "🔧 FIX MISSING IMAGES"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "CSV file: #{csv_file}"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts
    
    # Find products without images
    products_without_images = Product.left_joins(:product_images)
                                    .group('products.id')
                                    .having('COUNT(product_images.id) = 0')
                                    .order(:name)
    
    if products_without_images.empty?
      puts "✅ All products have images! Nothing to fix."
      exit 0
    end
    
    puts "📦 Found #{products_without_images.count} products without images:"
    products_without_images.each do |p|
      puts "   - #{p.name}"
    end
    puts
    
    # Parse CSV to get image URLs
    puts "📄 Parsing CSV for image URLs..."
    product_images = {}
    
    CSV.foreach(csv_file, headers: true) do |row|
      handle = row['Handle']
      image_src = row['Image Src']
      image_alt = row['Image Alt Text']
      image_position = row['Image Position']&.to_i || 1
      
      next if handle.blank? || image_src.blank?
      next if skip_image?(image_src, image_alt)
      
      product_images[handle] ||= []
      product_images[handle] << {
        url: image_src,
        alt_text: image_alt || '',
        position: image_position
      }
    end
    
    puts "✅ Found image URLs for #{product_images.keys.count} products in CSV"
    puts
    
    # Fix each product
    stats = { success: 0, errors: 0 }
    
    products_without_images.each do |product|
      images = product_images[product.slug]
      
      if images.nil? || images.empty?
        puts "⚠️  #{product.name}: No images found in CSV"
        stats[:errors] += 1
        next
      end
      
      puts "🔄 #{product.name}: Fetching #{images.size} images..."
      
      images.each_with_index do |image_data, index|
        begin
          download_and_attach_image(product, image_data, index)
          print "   ✓"
        rescue => e
          print "   ✗ (#{e.message})"
          stats[:errors] += 1
        end
      end
      
      puts
      stats[:success] += 1
    end
    
    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "✅ FIX COMPLETE!"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "Products fixed: #{stats[:success]}"
    puts "Errors: #{stats[:errors]}"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  end
  
  def skip_image?(image_src, image_alt_text)
    # Skip specific known logo/placeholder images
    return true if image_src.include?('ChristmasPua.png')
    return true if image_alt_text&.downcase&.include?('christmas placeholder image')
    return true if image_src.include?('Hafaloha-Shirts-August-2023_0055_P1122794.png')
    return true if image_src.include?('Hafaloha-Shirts-August-2023_0056_P1122792.png')
    
    # Skip images with "logo" or "placeholder" in their filename or alt text
    filename = image_src.split('/').last.split('?').first.downcase
    return true if filename.include?('logo') || filename.include?('placeholder')
    return true if image_alt_text&.downcase&.include?('logo') || image_alt_text&.downcase&.include?('placeholder')
    
    false
  end
  
  def download_and_attach_image(product, image_data, index)
    # Download image from Shopify URL
    tempfile = Tempfile.new(['product_image', '.jpg'], binmode: true)
    
    begin
      URI.open(image_data[:url], 'rb') do |file|
        IO.copy_stream(file, tempfile)
        tempfile.rewind
      end
      
      # Extract filename from URL
      filename = image_data[:url].split('/').last.split('?').first
      
      # Determine content type from filename
      content_type = case filename.downcase
                     when /\.png$/ then 'image/png'
                     when /\.jpg$/, /\.jpeg$/ then 'image/jpeg'
                     when /\.gif$/ then 'image/gif'
                     when /\.webp$/ then 'image/webp'
                     else 'image/jpeg'
                     end
      
      # Upload to S3 via Active Storage
      blob = ActiveStorage::Blob.create_and_upload!(
        io: tempfile,
        filename: filename,
        content_type: content_type
      )
      
      # Get S3 key from the blob
      s3_key = blob.key
      
      # Create ProductImage record
      product.product_images.create!(
        s3_key: s3_key,
        alt_text: image_data[:alt_text],
        position: image_data[:position],
        primary: index == 0 && product.product_images.count == 0
      )
      
    ensure
      tempfile.close
      tempfile.unlink
    end
  end
end

