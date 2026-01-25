# lib/tasks/migrate_variants_to_options.rake
# Migrate existing product variants from legacy size/color/material columns to options JSONB

namespace :variants do
  desc "Migrate legacy size/color/material columns to options JSONB field"
  task migrate_to_options: :environment do
    puts "Starting migration of variants to options format..."
    
    total = ProductVariant.count
    migrated = 0
    skipped = 0
    
    ProductVariant.find_each do |variant|
      options = {}
      
      # Build options hash from legacy columns
      options["Size"] = variant.size if variant.size.present?
      options["Color"] = variant.color if variant.color.present?
      options["Material"] = variant.material if variant.material.present?
      
      if options.present?
        # Only update if options hash has content
        variant.update_column(:options, options)
        migrated += 1
        print "." if migrated % 10 == 0
      else
        skipped += 1
      end
    end
    
    puts ""
    puts "Migration complete!"
    puts "  Total variants: #{total}"
    puts "  Migrated: #{migrated}"
    puts "  Skipped (no legacy data): #{skipped}"
    
    # Verification
    empty_options = ProductVariant.where("options = '{}'::jsonb OR options IS NULL").count
    puts ""
    puts "Verification:"
    puts "  Variants with empty options: #{empty_options}"
    
    if empty_options > 0
      puts "  ⚠️  Some variants have empty options - this may be expected for default variants"
    else
      puts "  ✓ All variants have options populated"
    end
  end

  desc "Show current state of variant options migration"
  task options_status: :environment do
    total = ProductVariant.count
    with_options = ProductVariant.where("options != '{}'::jsonb").count
    without_options = ProductVariant.where("options = '{}'::jsonb OR options IS NULL").count
    
    puts "Variant Options Status:"
    puts "  Total variants: #{total}"
    puts "  With options: #{with_options}"
    puts "  Without options: #{without_options}"
    
    if with_options > 0
      puts ""
      puts "Sample options:"
      ProductVariant.where("options != '{}'::jsonb").limit(5).each do |v|
        puts "  - #{v.sku}: #{v.options.inspect}"
      end
    end
  end

  desc "Rollback options to legacy columns (if needed)"
  task rollback_options: :environment do
    puts "Rolling back options to legacy columns..."
    
    ProductVariant.where("options != '{}'::jsonb").find_each do |variant|
      updates = {}
      updates[:size] = variant.options["Size"] if variant.options["Size"].present?
      updates[:color] = variant.options["Color"] if variant.options["Color"].present?
      updates[:material] = variant.options["Material"] if variant.options["Material"].present?
      
      variant.update_columns(updates) if updates.present?
      print "."
    end
    
    puts ""
    puts "Rollback complete!"
  end
end
