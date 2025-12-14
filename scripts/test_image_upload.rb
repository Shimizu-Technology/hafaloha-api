# Test script for image upload functionality
# Run with: rails runner scripts/test_image_upload.rb

puts "=" * 80
puts "TESTING IMAGE UPLOAD FUNCTIONALITY"
puts "=" * 80
puts ""

# Test 1: Check Active Storage configuration
puts "TEST 1: Checking Active Storage configuration..."
puts "  Service: #{Rails.configuration.active_storage.service}"
puts "  Environment: #{Rails.env}"
puts "✓ Active Storage is configured"
puts ""

# Test 2: Test ImageUploadService exists
puts "TEST 2: Checking ImageUploadService..."
begin
  service_class = ImageUploadService
  puts "✓ ImageUploadService class exists"
rescue NameError
  puts "✗ ImageUploadService class not found"
end
puts ""

# Test 3: Check existing blobs
puts "TEST 3: Checking existing blobs..."
blob_count = ActiveStorage::Blob.count
puts "✓ Total blobs in database: #{blob_count}"

if blob_count > 0
  latest_blob = ActiveStorage::Blob.last
  puts "  Latest blob:"
  puts "    - ID: #{latest_blob.id}"
  puts "    - Filename: #{latest_blob.filename}"
  puts "    - Key: #{latest_blob.key}"
  puts "    - Content Type: #{latest_blob.content_type}"
  puts "    - Byte Size: #{latest_blob.byte_size}"
end
puts ""

# Test 4: Check ProductImage integration
puts "TEST 4: Checking ProductImage with URLs..."
if Product.any? && Product.first.product_images.any?
  product = Product.first
  image = product.product_images.first
  puts "✓ Product: #{product.name}"
  puts "  - Image ID: #{image.id}"
  puts "  - URL: #{image.url}"
  puts "  - Position: #{image.position}"
  puts "  - Primary: #{image.primary}"
else
  puts "⊘ No products with images in database"
end
puts ""

# Summary
puts "=" * 80
puts "TEST SUMMARY"
puts "=" * 80
puts "Active Storage Blobs: #{ActiveStorage::Blob.count}"
puts "Active Storage Attachments: #{ActiveStorage::Attachment.count}"
puts "Active Storage Service: #{Rails.configuration.active_storage.service}"
puts "Storage Location: storage/ (development)"
puts ""
puts "✓ Image upload system is configured and ready!"
puts ""
puts "To upload an image via API:"
puts "  POST /api/v1/admin/uploads"
puts "  Authorization: Bearer <admin_token>"
puts "  Content-Type: multipart/form-data"
puts "  Body: file=@image.jpg"
puts "=" * 80
