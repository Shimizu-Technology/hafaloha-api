# Usage: bin/rails runner scripts/make_admin.rb EMAIL
#
# Examples:
#   bin/rails runner scripts/make_admin.rb rheada@hafaloha.com
#   bin/rails runner scripts/make_admin.rb someone@example.com

email = ARGV[0]

if email.blank?
  puts "❌ Usage: bin/rails runner scripts/make_admin.rb EMAIL"
  puts ""
  puts "Current users:"
  User.order(:email).each do |user|
    role_badge = user.admin? ? "👑 ADMIN" : "👤 customer"
    puts "  #{role_badge} - #{user.email}"
  end
  exit 1
end

user = User.find_by(email: email.downcase.strip)

if user.nil?
  puts "❌ User with email '#{email}' not found in database."
  puts ""
  puts "This could mean:"
  puts "  1. They haven't signed in yet (ask them to visit the site while logged in)"
  puts "  2. The email is misspelled"
  puts ""
  puts "Current users in database:"
  User.order(:email).each do |user|
    role_badge = user.admin? ? "👑 ADMIN" : "👤 customer"
    puts "  #{role_badge} - #{user.email}"
  end
  exit 1
end

if user.admin?
  puts "ℹ️  #{user.email} is already an admin!"
else
  user.update!(role: 'admin')
  puts "✅ #{user.email} is now an admin!"
end

puts ""
puts "Current admins:"
User.admins.order(:email).each do |admin|
  puts "  👑 #{admin.email}"
end
