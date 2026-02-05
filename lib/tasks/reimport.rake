namespace :import do
  desc "Archive all products and reimport from Shopify CSV with smart collection mapping"
  task reimport: :environment do
    csv_path = Rails.root.join("scripts/products_export.csv")

    unless File.exist?(csv_path)
      puts "❌ CSV not found at #{csv_path}"
      exit 1
    end

    puts "📊 Current state:"
    puts "  Products: #{Product.count} (#{Product.active.count} active, #{Product.archived.count} archived)"
    puts "  Collections: #{Collection.count}"
    puts "  Product-Collection links: #{ProductCollection.count}"
    puts ""

    # Step 1: Archive all existing products (import will unarchive + update them)
    active_count = Product.active.count
    if active_count > 0
      puts "📦 Archiving #{active_count} active products..."
      Product.active.update_all(archived: true)
      puts "  ✅ Archived"
    end

    # Step 2: Clear all product-collection associations (reimport will recreate)
    pc_count = ProductCollection.count
    if pc_count > 0
      puts "🔗 Clearing #{pc_count} product-collection associations..."
      ProductCollection.delete_all
      puts "  ✅ Cleared"
    end

    # Step 3: Create an Import record and copy CSV to temp location
    puts "\n🚀 Starting reimport from #{csv_path}..."
    admin_user = User.find_by(role: "admin") || User.first
    import = Import.create!(
      status: "pending",
      filename: "products_export.csv",
      user: admin_user
    )

    # Copy CSV to temp file (import job deletes it after)
    temp_path = Rails.root.join("tmp", "reimport_#{import.id}.csv")
    FileUtils.cp(csv_path, temp_path)

    # Step 4: Run import synchronously (not as background job)
    csv_lines = File.readlines(csv_path).count
    puts "  Processing #{csv_lines} CSV rows..."
    ProcessImportJob.perform_now(import.id, temp_path.to_s)

    # Step 5: Report results
    import.reload
    puts "\n✅ Import complete! (Status: #{import.status})"
    puts ""
    puts "📊 Results:"
    puts "  Products created/updated: #{import.products_count || 0}"
    puts "  Products skipped: #{import.skipped_count || 0}"
    puts "  Variants created: #{import.variants_count || 0}"
    puts "  Variants skipped: #{import.variants_skipped_count || 0}"
    puts "  Images downloaded: #{import.images_count || 0}"
    puts "  Collections: #{import.collections_count || 0}"

    # Final state
    puts "\n📊 Final state:"
    puts "  Products: #{Product.count} (#{Product.active.count} active, #{Product.archived.count} archived)"
    puts "  Collections: #{Collection.count}"
    puts "  Product-Collection links: #{ProductCollection.count}"
    puts ""

    # Show collection breakdown
    puts "📁 Collections:"
    Collection.order(:name).each do |c|
      puts "  #{c.name} (#{c.slug}): #{c.products.count} products"
    end
  end
end
