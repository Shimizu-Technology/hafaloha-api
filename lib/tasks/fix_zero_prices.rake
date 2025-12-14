namespace :fix do
  desc "Fix products with $0 base price by removing $0 default variants"
  task zero_prices: :environment do
    puts "🔧 Fixing $0 Products..."
    puts
    
    products = Product.where(base_price_cents: 0)
    
    if products.empty?
      puts "✅ No products with $0 base price found!"
      exit 0
    end
    
    products.each do |product|
      puts "\n📦 #{product.name} (inventory: #{product.inventory_level})"
      
      # Delete the auto-generated DEFAULT variant (with $0)
      default_variants = product.product_variants.where(is_default: true)
      default_variants.each do |dv|
        if dv.price_cents == 0
          puts "  🗑️  Deleting $0 default variant: #{dv.sku}"
          dv.destroy!
        end
      end
      
      # Get the lowest real variant price (now that default is gone)
      lowest_price = product.product_variants.where('price_cents > 0').minimum(:price_cents)
      
      if lowest_price
        puts "  💰 Setting base price to $#{lowest_price / 100.0} (lowest variant)"
        product.update!(base_price_cents: lowest_price)
      else
        puts "  ⚠️  No variants with price > 0 found"
      end
      
      # Regenerate default variant if needed (for inventory_level: none/product)
      if ['none', 'product'].include?(product.inventory_level) && product.product_variants.none?
        puts "  🆕 Regenerating default variant (inventory_level: #{product.inventory_level})"
        product.ensure_default_variant!
      end
    end
    
    puts "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "✅ FIXED! Results:"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    Product.where('id IN (?)', products.pluck(:id)).each do |p|
      puts "  #{p.name}: $#{p.base_price_cents / 100.0} (#{p.product_variants.count} variants)"
    end
    
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  end
end

