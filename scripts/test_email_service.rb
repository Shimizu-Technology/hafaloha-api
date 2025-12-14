#!/usr/bin/env ruby
# frozen_string_literal: true

# This script tests the email notification system
# Run via: rails runner scripts/test_email_service.rb

puts "================================================================================"
puts "TESTING EMAIL SERVICE & ORDER NOTIFICATIONS"
puts "================================================================================"

# Check if Resend API key is configured
unless ENV['RESEND_API_KEY'].present?
  puts "❌ RESEND_API_KEY is not set in your .env file"
  puts "   Please add it to test email functionality"
  puts "   Get your key from: https://resend.com"
  exit
end

puts "✓ Resend API Key is configured"

# Find or create a test order
order = Order.where(email: 'shimizutechnology@gmail.com').last

unless order
  puts "\n❌ No orders found for shimizutechnology@gmail.com"
  puts "   Please create an order through the checkout flow first"
  puts "   Or run: rails runner scripts/test_admin_api.rb"
  exit
end

puts "\n✓ Found test order: ##{order.id}"
puts "  Email: #{order.email}"
puts "  Total: $#{'%.2f' % (order.total_cents / 100.0)}"
puts "  Status: #{order.payment_status}"
puts "  Items: #{order.order_items.count}"

# Test 1: Send Customer Confirmation
puts "\n--- TEST 1: Customer Confirmation Email ---"
result = EmailService.send_order_confirmation(order)

if result[:success]
  puts "✅ Customer confirmation email sent!"
  puts "   Message ID: #{result[:message_id]}"
else
  puts "❌ Failed to send customer confirmation"
  puts "   Error: #{result[:error]}"
end

# Test 2: Send Admin Notification
puts "\n--- TEST 2: Admin Notification Email ---"
result = EmailService.send_admin_notification(order)

if result[:success]
  puts "✅ Admin notification email sent!"
  puts "   Message ID: #{result[:message_id]}"
  puts "   Sent to: #{SiteSetting.instance.order_notification_emails.join(', ')}"
else
  puts "❌ Failed to send admin notification"
  puts "   Error: #{result[:error]}"
end

# Test 3: Test Background Jobs
puts "\n--- TEST 3: Background Job Queueing ---"
begin
  SendOrderConfirmationEmailJob.perform_later(order.id)
  puts "✅ Order confirmation job queued"
  
  SendAdminNotificationEmailJob.perform_later(order.id)
  puts "✅ Admin notification job queued"
  
  puts "\n💡 Jobs queued! They will be processed by Solid Queue."
  puts "   In production, these run automatically."
  puts "   For dev, run: rails solid_queue:start"
rescue StandardError => e
  puts "❌ Error queueing jobs: #{e.message}"
end

puts "\n================================================================================"
puts "EMAIL TESTING COMPLETE"
puts "================================================================================"
puts "\n📧 Check your email inbox:"
puts "   - Customer: #{order.email}"
puts "   - Admin: #{SiteSetting.instance.order_notification_emails.join(', ')}"
puts "\n💡 Tips:"
puts "   - Check spam folder if you don't see the emails"
puts "   - Resend may require domain verification for production"
puts "   - Test emails work immediately without verification"

