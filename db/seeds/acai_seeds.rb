# frozen_string_literal: true

# Acai Cakes Seed Data
# Run with: bin/rails runner db/seeds/acai_seeds.rb

puts "🍰 Seeding Acai Cakes data..."

# Create default settings (singleton will create with defaults if not exists)
settings = AcaiSetting.instance
puts "  ✅ AcaiSetting created/loaded: #{settings.name} - #{settings.formatted_price}"

# Create crust options matching hafaloha.com pricing
crust_options = [
  { name: 'Peanut Butter', description: 'Creamy peanut butter base for a nutty twist', price_cents: 0, position: 1 },
  { name: 'Nutella', description: 'Rich chocolate hazelnut spread base', price_cents: 450, position: 2 },
  { name: 'Honey', description: 'Simple sweet honey drizzle base', price_cents: 450, position: 3 }
]

crust_options.each do |attrs|
  option = AcaiCrustOption.find_or_create_by!(name: attrs[:name]) do |o|
    o.description = attrs[:description]
    o.price_cents = attrs[:price_cents]
    o.position = attrs[:position]
    o.available = true
  end
  puts "  ✅ Crust Option: #{option.name} (#{option.formatted_price})"
end

# Create placard options
placard_options = [
  { name: 'Happy Birthday', description: 'Birthday celebration placard', price_cents: 0, position: 1 },
  { name: 'Happy Anniversary', description: 'Anniversary celebration placard', price_cents: 0, position: 2 },
  { name: 'Congratulations', description: 'Congratulations placard', price_cents: 0, position: 3 },
  { name: 'Happy Mother\'s Day', description: 'Mother\'s Day special placard', price_cents: 0, position: 4 },
  { name: 'Happy Father\'s Day', description: 'Father\'s Day special placard', price_cents: 0, position: 5 },
  { name: 'Thank You', description: 'Appreciation placard', price_cents: 0, position: 6 },
  { name: 'Custom Message', description: 'Write your own message', price_cents: 0, position: 7 }
]

placard_options.each do |attrs|
  option = AcaiPlacardOption.find_or_create_by!(name: attrs[:name]) do |o|
    o.description = attrs[:description]
    o.price_cents = attrs[:price_cents]
    o.position = attrs[:position]
    o.available = true
  end
  puts "  ✅ Placard Option: #{option.name}"
end

# Create pickup windows (based on their hours of operation)
# Monday: Closed
# Tue-Thur: 11 AM - 9 PM
# Fri-Sat: 11 AM - 10 PM  
# Sunday: 11 AM - 9 PM

pickup_windows = [
  { day_of_week: 1, start_time: '09:00', end_time: '16:00', active: true },  # Monday
  { day_of_week: 2, start_time: '09:00', end_time: '16:00', active: true },  # Tuesday
  { day_of_week: 3, start_time: '09:00', end_time: '16:00', active: true },  # Wednesday
  { day_of_week: 4, start_time: '09:00', end_time: '16:00', active: true },  # Thursday
  { day_of_week: 5, start_time: '09:00', end_time: '16:00', active: true },  # Friday
  { day_of_week: 6, start_time: '09:00', end_time: '16:00', active: true },  # Saturday
]

pickup_windows.each do |attrs|
  window = AcaiPickupWindow.find_or_create_by!(day_of_week: attrs[:day_of_week]) do |w|
    w.start_time = attrs[:start_time]
    w.end_time = attrs[:end_time]
    w.active = attrs[:active]
    w.capacity = 5  # Max 5 orders per 30-min slot
  end
  puts "  ✅ Pickup Window: #{window.display_name}"
end

puts ""
puts "🎉 Acai Cakes seed data complete!"
puts "   - #{AcaiCrustOption.count} crust options"
puts "   - #{AcaiPlacardOption.count} placard options"
puts "   - #{AcaiPickupWindow.count} pickup windows"
puts ""
puts "💡 To test, visit: GET /api/v1/acai/config"
