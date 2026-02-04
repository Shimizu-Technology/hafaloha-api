# frozen_string_literal: true

class EmailService
  class EmailError < StandardError; end

  # Send order confirmation email to customer
  # @param order [Order] - The completed order
  # @return [Hash] - { success: boolean, message_id: string, error: string }
  def self.send_order_confirmation(order)
    return { success: false, error: "Resend API key not configured" } unless ENV['RESEND_API_KEY'].present?

    begin
      params = {
        from: from_address,
        to: [order.email],
        subject: "Order Confirmation ##{order.id.to_s.rjust(6, '0')} - Hafaloha",
        html: order_confirmation_html(order)
      }

      response = Resend::Emails.send(params)
      
      Rails.logger.info "✅ Order confirmation email sent to #{order.email} (Order ##{order.id})"
      { success: true, message_id: response["id"] }

    rescue Resend::Error => e
      Rails.logger.error "Resend Error sending confirmation: #{e.message}"
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "Email Error: #{e.class} - #{e.message}"
      { success: false, error: "Failed to send email" }
    end
  end

  # Send order notification to admin
  # @param order [Order] - The completed order
  # @return [Hash] - { success: boolean, message_id: string, error: string }
  def self.send_admin_notification(order)
    return { success: false, error: "Resend API key not configured" } unless ENV['RESEND_API_KEY'].present?

    settings = SiteSetting.instance
    admin_emails = settings.order_notification_emails || ['shimizutechnology@gmail.com']

    begin
      params = {
        from: from_address,
        to: admin_emails,
        subject: "🛍️ New Order ##{order.id.to_s.rjust(6, '0')} - #{order.email}",
        html: admin_notification_html(order)
      }

      response = Resend::Emails.send(params)
      
      Rails.logger.info "✅ Admin notification email sent (Order ##{order.id})"
      { success: true, message_id: response["id"] }

    rescue Resend::Error => e
      # In development, domain verification errors are expected - log as info, not error
      if Rails.env.development? && e.message.include?("domain is not verified")
        Rails.logger.info "ℹ️  Resend domain not verified (expected in development): #{e.message}"
      else
        Rails.logger.error "Resend Error sending admin notification: #{e.message}"
      end
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "Email Error: #{e.class} - #{e.message}"
      { success: false, error: "Failed to send admin notification" }
    end
  end

  # Send order shipped notification with tracking info
  # @param order [Order] - The shipped order
  # @return [Hash] - { success: boolean, message_id: string, error: string }
  def self.send_order_shipped_email(order)
    return { success: false, error: "Resend API key not configured" } unless ENV['RESEND_API_KEY'].present?

    begin
      params = {
        from: from_address,
        to: [order.email],
        subject: "Your Order Has Shipped! 📦 - Order ##{order.order_number}",
        html: order_shipped_html(order)
      }

      response = Resend::Emails.send(params)
      
      Rails.logger.info "✅ Shipped notification email sent to #{order.email} (Order ##{order.order_number})"
      { success: true, message_id: response["id"] }

    rescue Resend::Error => e
      Rails.logger.error "Resend Error sending shipped notification: #{e.message}"
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "Email Error: #{e.class} - #{e.message}"
      { success: false, error: "Failed to send shipped notification" }
    end
  end

  # Send order ready for pickup notification
  # @param order [Order] - The order that's ready for pickup
  # @return [Hash] - { success: boolean, message_id: string, error: string }
  def self.send_order_ready_email(order)
    return { success: false, error: "Resend API key not configured" } unless ENV['RESEND_API_KEY'].present?

    begin
      emoji = order.acai? ? '🍰' : '📦'
      subject = "Your Order is Ready for Pickup! #{emoji} - Order ##{order.order_number}"
      
      params = {
        from: from_address,
        to: [order.email],
        subject: subject,
        html: order_ready_html(order)
      }

      response = Resend::Emails.send(params)
      
      Rails.logger.info "✅ Ready for pickup email sent to #{order.email} (Order ##{order.order_number})"
      { success: true, message_id: response["id"] }

    rescue Resend::Error => e
      Rails.logger.error "Resend Error sending ready notification: #{e.message}"
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "Email Error: #{e.class} - #{e.message}"
      { success: false, error: "Failed to send ready notification" }
    end
  end

  # Send refund notification email to customer
  # @param order [Order] - The refunded order
  # @param refund_amount [Integer] - Refund amount in cents
  # @param reason [String] - Reason for the refund
  # @return [Hash] - { success: boolean, message_id: string, error: string }
  def self.send_refund_notification(order, refund_amount, reason = nil)
    return { success: false, error: "Resend API key not configured" } unless ENV['RESEND_API_KEY'].present?

    begin
      amount_formatted = "$#{'%.2f' % (refund_amount / 100.0)}"
      refund_date = Time.current.strftime('%B %d, %Y')

      params = {
        from: from_address,
        to: [order.email],
        subject: "Hafaloha — Refund Processed for Order ##{order.order_number}",
        html: refund_notification_html(order, amount_formatted, reason, refund_date)
      }

      response = Resend::Emails.send(params)

      Rails.logger.info "✅ Refund notification email sent to #{order.email} (Order ##{order.order_number})"
      { success: true, message_id: response["id"] }

    rescue Resend::Error => e
      Rails.logger.error "Resend Error sending refund notification: #{e.message}"
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "Email Error: #{e.class} - #{e.message}"
      { success: false, error: "Failed to send refund notification" }
    end
  end

  # Send contact form submission notification to admin
  # @param submission [ContactSubmission] - The contact form submission
  # @return [Hash] - { success: boolean, message_id: string, error: string }
  def self.send_contact_notification(submission)
    return { success: false, error: "Resend API key not configured" } unless ENV['RESEND_API_KEY'].present?

    begin
      # Send to site admin emails (same as order notifications)
      settings = SiteSetting.instance
      admin_emails = settings.order_notification_emails || ['shimizutechnology@gmail.com']

      params = {
        from: from_address,
        to: admin_emails,
        reply_to: submission.email,
        subject: "📬 New Contact Form: #{submission.subject} — from #{submission.name}",
        html: contact_notification_html(submission)
      }

      response = Resend::Emails.send(params)

      Rails.logger.info "✅ Contact form notification sent (from: #{submission.email}, subject: #{submission.subject})"
      { success: true, message_id: response["id"] }

    rescue Resend::Error => e
      if Rails.env.development? && e.message.include?("domain is not verified")
        Rails.logger.info "ℹ️  Resend domain not verified (expected in development): #{e.message}"
      else
        Rails.logger.error "Resend Error sending contact notification: #{e.message}"
      end
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "Email Error: #{e.class} - #{e.message}"
      { success: false, error: "Failed to send contact notification" }
    end
  end

  private

  # Configurable from address - uses RESEND_FROM_EMAIL env var
  # Falls back to shimizu-technology.com until hafaloha.com is verified on Resend
  def self.from_address
    email = ENV.fetch("RESEND_FROM_EMAIL", "noreply@shimizu-technology.com")
    "Hafaloha <#{email}>"
  end

  # Generate customer confirmation HTML
  def self.order_confirmation_html(order)
    # Route to appropriate template based on order type
    if order.order_type == 'acai'
      return acai_order_confirmation_html(order)
    end
    
    settings = SiteSetting.instance
    test_mode_badge = settings.test_mode? ? '<span style="background: #FEF3C7; color: #92400E; padding: 4px 12px; border-radius: 4px; font-size: 12px; font-weight: 600;">⚙️ TEST ORDER</span>' : ''

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Order Confirmation</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f3f4f6; padding: 20px 0;">
          <tr>
            <td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                
                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #C1191F 0%, #8B0000 100%); padding: 40px 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">Hafaloha</h1>
                    <p style="color: #FFD700; margin: 10px 0 0 0; font-size: 14px;">Chamorro Pride. Island Style.</p>
                  </td>
                </tr>

                <!-- Order Confirmation -->
                <tr>
                  <td style="padding: 40px 30px; text-align: center;">
                    <h2 style="color: #111827; margin: 0 0 10px 0; font-size: 24px;">Thank You For Your Order! 🎉</h2>
                    #{test_mode_badge}
                    <p style="color: #6B7280; margin: 20px 0 0 0; font-size: 16px;">Order ##{order.id.to_s.rjust(6, '0')}</p>
                    <p style="color: #9CA3AF; margin: 5px 0 0 0; font-size: 14px;">#{order.created_at.strftime('%B %d, %Y at %I:%M %p')}</p>
                  </td>
                </tr>

                <!-- Order Items -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="border: 1px solid #E5E7EB; border-radius: 8px; overflow: hidden;">
                      <thead>
                        <tr style="background-color: #F9FAFB;">
                          <th style="padding: 15px; text-align: left; font-size: 14px; color: #6B7280; font-weight: 600;">Item</th>
                          <th style="padding: 15px; text-align: center; font-size: 14px; color: #6B7280; font-weight: 600;">Qty</th>
                          <th style="padding: 15px; text-align: right; font-size: 14px; color: #6B7280; font-weight: 600;">Price</th>
                        </tr>
                      </thead>
                      <tbody>
                        #{order_items_html(order)}
                      </tbody>
                      <tfoot>
                        <tr style="border-top: 2px solid #E5E7EB;">
                          <td colspan="2" style="padding: 15px; text-align: right; font-size: 14px; color: #6B7280;">Subtotal:</td>
                          <td style="padding: 15px; text-align: right; font-size: 14px; color: #111827; font-weight: 600;">$#{format_price(order.subtotal_cents)}</td>
                        </tr>
                        <tr>
                          <td colspan="2" style="padding: 0 15px 15px 15px; text-align: right; font-size: 14px; color: #6B7280;">Shipping:</td>
                          <td style="padding: 0 15px 15px 15px; text-align: right; font-size: 14px; color: #111827; font-weight: 600;">$#{format_price(order.shipping_cost_cents)}</td>
                        </tr>
                        <tr style="background-color: #F9FAFB;">
                          <td colspan="2" style="padding: 15px; text-align: right; font-size: 16px; color: #111827; font-weight: bold;">Total:</td>
                          <td style="padding: 15px; text-align: right; font-size: 16px; color: #C1191F; font-weight: bold;">$#{format_price(order.total_cents)}</td>
                        </tr>
                      </tfoot>
                    </table>
                  </td>
                </tr>

                <!-- Shipping Address -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td width="50%" style="padding-right: 10px;">
                          <div style="background-color: #F9FAFB; border-radius: 8px; padding: 20px;">
                            <h3 style="color: #111827; margin: 0 0 10px 0; font-size: 16px; font-weight: 600;">Shipping Address</h3>
                            <p style="color: #6B7280; margin: 5px 0; font-size: 14px; line-height: 1.6;">
                              #{order.name}<br>
                              #{order.shipping_address_line1}<br>
                              #{order.shipping_address_line2.present? ? "#{order.shipping_address_line2}<br>" : ""}
                              #{order.shipping_city}, #{order.shipping_state} #{order.shipping_zip}<br>
                              #{order.shipping_country}
                            </p>
                          </div>
                        </td>
                        <td width="50%" style="padding-left: 10px;">
                          <div style="background-color: #F9FAFB; border-radius: 8px; padding: 20px;">
                            <h3 style="color: #111827; margin: 0 0 10px 0; font-size: 16px; font-weight: 600;">Shipping Method</h3>
                            <p style="color: #6B7280; margin: 5px 0; font-size: 14px; line-height: 1.6;">
                              #{order.shipping_method}
                            </p>
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background-color: #F9FAFB; padding: 30px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #6B7280; margin: 0 0 10px 0; font-size: 14px;">Questions about your order?</p>
                    <p style="color: #C1191F; margin: 0; font-size: 14px;"><a href="mailto:info@hafaloha.com" style="color: #C1191F; text-decoration: none;">info@hafaloha.com</a> | (671) 777-1234</p>
                    <p style="color: #9CA3AF; margin: 20px 0 0 0; font-size: 12px;">&copy; #{Time.current.year} Hafaloha. All rights reserved.</p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    HTML
  end

  # Generate admin notification HTML
  def self.admin_notification_html(order)
    # Route to appropriate template based on order type
    if order.order_type == 'acai'
      return acai_admin_notification_html(order)
    end
    
    settings = SiteSetting.instance
    test_mode_badge = settings.test_mode? ? '<span style="background: #FEF3C7; color: #92400E; padding: 4px 12px; border-radius: 4px; font-size: 12px; font-weight: 600;">⚙️ TEST ORDER</span>' : ''

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>New Order</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f3f4f6; padding: 20px 0;">
          <tr>
            <td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                
                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #1F2937 0%, #111827 100%); padding: 40px 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">🛍️ New Order Received</h1>
                    #{test_mode_badge}
                  </td>
                </tr>

                <!-- Order Info -->
                <tr>
                  <td style="padding: 30px;">
                    <h2 style="color: #111827; margin: 0 0 20px 0; font-size: 20px;">Order ##{order.id.to_s.rjust(6, '0')}</h2>
                    
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 20px;">
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Customer:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{order.email}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Phone:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{order.phone || 'N/A'}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Date:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{order.created_at.strftime('%B %d, %Y at %I:%M %p')}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Payment Status:</strong>
                          <span style="color: #10B981; font-size: 14px; float: right;">#{order.payment_status.titleize}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0;">
                          <strong style="color: #6B7280; font-size: 14px;">Total:</strong>
                          <span style="color: #C1191F; font-size: 18px; font-weight: bold; float: right;">$#{format_price(order.total_cents)}</span>
                        </td>
                      </tr>
                    </table>

                    <!-- Items -->
                    <h3 style="color: #111827; margin: 30px 0 15px 0; font-size: 16px;">Order Items:</h3>
                    <table width="100%" cellpadding="0" cellspacing="0" style="border: 1px solid #E5E7EB; border-radius: 8px; overflow: hidden;">
                      <tbody>
                        #{order_items_html(order)}
                      </tbody>
                    </table>

                    <!-- Shipping Info -->
                    <h3 style="color: #111827; margin: 30px 0 15px 0; font-size: 16px;">Shipping Details:</h3>
                    <div style="background-color: #F9FAFB; border-radius: 8px; padding: 20px;">
                      <p style="color: #111827; margin: 0 0 10px 0; font-size: 14px; font-weight: 600;">#{order.name}</p>
                      <p style="color: #6B7280; margin: 0; font-size: 14px; line-height: 1.6;">
                        #{order.shipping_address_line1}<br>
                        #{order.shipping_address_line2.present? ? "#{order.shipping_address_line2}<br>" : ""}
                        #{order.shipping_city}, #{order.shipping_state} #{order.shipping_zip}<br>
                        #{order.shipping_country}
                      </p>
                      <p style="color: #6B7280; margin: 15px 0 0 0; font-size: 14px;">
                        <strong>Method:</strong> #{order.shipping_method}
                      </p>
                    </div>
                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background-color: #F9FAFB; padding: 20px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #6B7280; margin: 0; font-size: 12px;">This is an automated notification from Hafaloha Order System</p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    HTML
  end

  # Generate Acai admin notification HTML
  def self.acai_admin_notification_html(order)
    settings = SiteSetting.instance
    acai_settings = AcaiSetting.instance
    test_mode_badge = settings.test_mode? ? '<span style="background: #FEF3C7; color: #92400E; padding: 4px 12px; border-radius: 4px; font-size: 12px; font-weight: 600;">⚙️ TEST ORDER</span>' : ''
    
    pickup_date = order.acai_pickup_date&.strftime('%A, %B %d, %Y') || 'TBD'
    pickup_time = order.acai_pickup_time || 'TBD'

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>New Acai Cake Order</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f3f4f6; padding: 20px 0;">
          <tr>
            <td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                
                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #7C3AED 0%, #5B21B6 100%); padding: 40px 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">🍰 New Acai Cake Order!</h1>
                    #{test_mode_badge}
                  </td>
                </tr>

                <!-- Pickup Alert -->
                <tr>
                  <td style="padding: 30px;">
                    <div style="background: linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%); border-radius: 8px; padding: 20px; text-align: center; color: #ffffff; margin-bottom: 20px;">
                      <p style="margin: 0 0 5px 0; font-size: 12px; opacity: 0.9;">⚡ PICKUP SCHEDULED</p>
                      <p style="margin: 0; font-size: 18px; font-weight: bold;">#{pickup_date} @ #{pickup_time}</p>
                    </div>
                    
                    <h2 style="color: #111827; margin: 0 0 20px 0; font-size: 20px;">Order ##{order.order_number}</h2>
                    
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 20px;">
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Customer:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{order.name}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Email:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{order.email}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Phone:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{order.phone || 'N/A'}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Crust/Base:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{order.acai_crust_type}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Quantity:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{order.order_items.first&.quantity || 1}</span>
                        </td>
                      </tr>
                      #{order.acai_include_placard && order.acai_placard_text.present? ? "
                      <tr>
                        <td style=\"padding: 10px 0; border-bottom: 1px solid #E5E7EB;\">
                          <strong style=\"color: #6B7280; font-size: 14px;\">Placard Message:</strong>
                          <p style=\"color: #111827; font-size: 14px; margin: 5px 0 0 0; font-style: italic;\">\"#{order.acai_placard_text}\"</p>
                        </td>
                      </tr>" : ""}
                      <tr>
                        <td style="padding: 10px 0;">
                          <strong style="color: #6B7280; font-size: 14px;">Total:</strong>
                          <span style="color: #C1191F; font-size: 18px; font-weight: bold; float: right;">$#{format_price(order.total_cents)}</span>
                        </td>
                      </tr>
                    </table>

                    #{order.notes.present? ? "
                    <div style=\"background-color: #FEF3C7; border-radius: 8px; padding: 15px; margin-top: 20px;\">
                      <strong style=\"color: #92400E; font-size: 14px;\">📝 Special Instructions:</strong>
                      <p style=\"color: #92400E; font-size: 14px; margin: 5px 0 0 0;\">#{order.notes}</p>
                    </div>" : ""}
                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background-color: #F9FAFB; padding: 20px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #6B7280; margin: 0; font-size: 12px;">This is an automated notification from Hafaloha Acai Cakes</p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    HTML
  end

  # Generate Acai order confirmation HTML
  def self.acai_order_confirmation_html(order)
    settings = SiteSetting.instance
    acai_settings = AcaiSetting.instance
    test_mode_badge = settings.test_mode? ? '<span style="background: #FEF3C7; color: #92400E; padding: 4px 12px; border-radius: 4px; font-size: 12px; font-weight: 600;">⚙️ TEST ORDER</span>' : ''
    
    pickup_date = order.acai_pickup_date&.strftime('%A, %B %d, %Y') || 'TBD'
    pickup_time = order.acai_pickup_time || 'TBD'

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Acai Cake Order Confirmation</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f3f4f6; padding: 20px 0;">
          <tr>
            <td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                
                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #C1191F 0%, #8B0000 100%); padding: 40px 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">🍰 Hafaloha</h1>
                    <p style="color: #FFD700; margin: 10px 0 0 0; font-size: 14px;">Acai Cake Order Confirmed!</p>
                  </td>
                </tr>

                <!-- Order Confirmation -->
                <tr>
                  <td style="padding: 40px 30px; text-align: center;">
                    <h2 style="color: #111827; margin: 0 0 10px 0; font-size: 24px;">Thank You For Your Order! 🎉</h2>
                    #{test_mode_badge}
                    <p style="color: #6B7280; margin: 20px 0 0 0; font-size: 16px;">Order ##{order.order_number}</p>
                    <p style="color: #9CA3AF; margin: 5px 0 0 0; font-size: 14px;">#{order.created_at.strftime('%B %d, %Y at %I:%M %p')}</p>
                  </td>
                </tr>

                <!-- Pickup Details -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <div style="background: linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%); border-radius: 8px; padding: 25px; text-align: center; color: #ffffff;">
                      <p style="margin: 0 0 15px 0; font-size: 14px; opacity: 0.9;">📍 PICKUP DETAILS</p>
                      <p style="margin: 0 0 8px 0; font-size: 20px; font-weight: bold;">#{pickup_date}</p>
                      <p style="margin: 0; font-size: 18px; font-weight: 600;">#{pickup_time}</p>
                    </div>
                  </td>
                </tr>

                <!-- Location -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <div style="background-color: #F9FAFB; border-radius: 8px; padding: 20px;">
                      <h3 style="color: #111827; margin: 0 0 10px 0; font-size: 16px; font-weight: 600;">📍 Pickup Location</h3>
                      <p style="color: #6B7280; margin: 0 0 10px 0; font-size: 14px; line-height: 1.6;">
                        #{acai_settings.pickup_location}
                      </p>
                      <p style="color: #6B7280; margin: 0; font-size: 14px;">
                        <strong>Phone:</strong> #{acai_settings.pickup_phone}
                      </p>
                    </div>
                  </td>
                </tr>

                <!-- Order Summary -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="border: 1px solid #E5E7EB; border-radius: 8px; overflow: hidden;">
                      <tr style="background-color: #F9FAFB;">
                        <td colspan="2" style="padding: 15px; font-size: 16px; font-weight: 600; color: #111827;">Order Summary</td>
                      </tr>
                      <tr>
                        <td style="padding: 15px; border-top: 1px solid #E5E7EB;">
                          <strong>#{acai_settings.name}</strong><br>
                          <span style="color: #6B7280; font-size: 14px;">#{order.acai_crust_type}</span>
                        </td>
                        <td style="padding: 15px; border-top: 1px solid #E5E7EB; text-align: right;">
                          #{order.order_items.first&.quantity || 1}x
                        </td>
                      </tr>
                      #{order.acai_include_placard && order.acai_placard_text.present? ? "
                      <tr>
                        <td colspan=\"2\" style=\"padding: 15px; border-top: 1px solid #E5E7EB;\">
                          <strong>Message Placard:</strong><br>
                          <span style=\"color: #6B7280; font-style: italic;\">\"#{order.acai_placard_text}\"</span>
                        </td>
                      </tr>" : ""}
                      <tr style="background-color: #F9FAFB;">
                        <td style="padding: 15px; border-top: 2px solid #E5E7EB; font-size: 16px; font-weight: bold; color: #111827;">Total</td>
                        <td style="padding: 15px; border-top: 2px solid #E5E7EB; text-align: right; font-size: 16px; font-weight: bold; color: #C1191F;">$#{format_price(order.total_cents)}</td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background-color: #F9FAFB; padding: 30px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #6B7280; margin: 0 0 10px 0; font-size: 14px;">Questions about your order?</p>
                    <p style="color: #C1191F; margin: 0; font-size: 14px;"><a href="mailto:info@hafaloha.com" style="color: #C1191F; text-decoration: none;">info@hafaloha.com</a> | #{acai_settings.pickup_phone}</p>
                    <p style="color: #9CA3AF; margin: 20px 0 0 0; font-size: 12px;">&copy; #{Time.current.year} Hafaloha. All rights reserved.</p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    HTML
  end

  # Generate order items table rows
  def self.order_items_html(order)
    order.order_items.map do |item|
      variant_info = item.variant_name.present? ? " (#{item.variant_name})" : ""
      <<~HTML
        <tr style="border-bottom: 1px solid #E5E7EB;">
          <td style="padding: 15px; font-size: 14px; color: #111827;">
            #{item.product_name}#{variant_info}
          </td>
          <td style="padding: 15px; text-align: center; font-size: 14px; color: #6B7280;">#{item.quantity}</td>
          <td style="padding: 15px; text-align: right; font-size: 14px; color: #111827; font-weight: 600;">$#{format_price(item.total_price_cents)}</td>
        </tr>
      HTML
    end.join
  end

  # Format price from cents to dollars
  def self.format_price(cents)
    '%.2f' % (cents / 100.0)
  end

  # Generate order shipped HTML
  def self.order_shipped_html(order)
    tracking_section = if order.tracking_number.present?
      <<~HTML
        <tr>
          <td style="padding: 0 30px 30px 30px;">
            <div style="background: linear-gradient(135deg, #10B981 0%, #059669 100%); border-radius: 8px; padding: 25px; text-align: center;">
              <p style="color: #ffffff; margin: 0 0 15px 0; font-size: 16px; font-weight: 600;">📦 Tracking Number</p>
              <p style="color: #ffffff; margin: 0; font-size: 24px; font-weight: bold; letter-spacing: 2px;">#{order.tracking_number}</p>
            </div>
          </td>
        </tr>
      HTML
    else
      ""
    end

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Order Shipped</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f3f4f6; padding: 20px 0;">
          <tr>
            <td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                
                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #C1191F 0%, #8B0000 100%); padding: 40px 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">Hafaloha</h1>
                    <p style="color: #FFD700; margin: 10px 0 0 0; font-size: 14px;">Chamorro Pride. Island Style.</p>
                  </td>
                </tr>

                <!-- Shipped Message -->
                <tr>
                  <td style="padding: 40px 30px; text-align: center;">
                    <div style="background-color: #ECFDF5; border: 2px solid #10B981; border-radius: 8px; padding: 20px; margin-bottom: 20px;">
                      <h2 style="color: #059669; margin: 0; font-size: 24px;">📦 Your Order Has Shipped!</h2>
                    </div>
                    <p style="color: #6B7280; margin: 10px 0 0 0; font-size: 16px;">Order ##{order.order_number}</p>
                    <p style="color: #9CA3AF; margin: 5px 0 0 0; font-size: 14px;">Placed on #{order.created_at.strftime('%B %d, %Y')}</p>
                  </td>
                </tr>

                <!-- Tracking Number -->
                #{tracking_section}

                <!-- Order Items Summary -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <h3 style="color: #111827; margin: 0 0 15px 0; font-size: 18px; font-weight: 600;">What's in your package:</h3>
                    <table width="100%" cellpadding="0" cellspacing="0" style="border: 1px solid #E5E7EB; border-radius: 8px; overflow: hidden;">
                      <tbody>
                        #{order_items_html(order)}
                      </tbody>
                    </table>
                  </td>
                </tr>

                <!-- Shipping Address -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <div style="background-color: #F9FAFB; border-radius: 8px; padding: 20px;">
                      <h3 style="color: #111827; margin: 0 0 10px 0; font-size: 16px; font-weight: 600;">Shipping To:</h3>
                      <p style="color: #6B7280; margin: 5px 0; font-size: 14px; line-height: 1.6;">
                        #{order.name}<br>
                        #{order.shipping_address_line1}<br>
                        #{order.shipping_address_line2.present? ? "#{order.shipping_address_line2}<br>" : ""}
                        #{order.shipping_city}, #{order.shipping_state} #{order.shipping_zip}<br>
                        #{order.shipping_country}
                      </p>
                      <p style="color: #6B7280; margin: 15px 0 0 0; font-size: 14px;">
                        <strong>Method:</strong> #{order.shipping_method}
                      </p>
                    </div>
                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background-color: #F9FAFB; padding: 30px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #6B7280; margin: 0 0 10px 0; font-size: 14px;">Questions about your order?</p>
                    <p style="color: #C1191F; margin: 0; font-size: 14px;"><a href="mailto:info@hafaloha.com" style="color: #C1191F; text-decoration: none;">info@hafaloha.com</a> | (671) 777-1234</p>
                    <p style="color: #9CA3AF; margin: 20px 0 0 0; font-size: 12px;">&copy; #{Time.current.year} Hafaloha. All rights reserved.</p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    HTML
  end

  # Generate order ready for pickup HTML
  def self.order_ready_html(order)
    settings = AcaiSetting.instance rescue nil
    pickup_location = settings&.pickup_location || 'Contact us for pickup location'
    pickup_phone = settings&.pickup_phone || '(671) 777-1234'
    
    pickup_time_section = if order.acai? && order.acai_pickup_date.present?
      pickup_date = order.acai_pickup_date.is_a?(String) ? Date.parse(order.acai_pickup_date) : order.acai_pickup_date
      <<~HTML
        <tr>
          <td style="padding: 0 30px 30px 30px;">
            <div style="background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%); border-radius: 8px; padding: 25px; text-align: center;">
              <p style="color: #ffffff; margin: 0 0 15px 0; font-size: 16px; font-weight: 600;">🗓️ Your Pickup Time</p>
              <p style="color: #ffffff; margin: 0; font-size: 20px; font-weight: bold;">#{pickup_date.strftime('%A, %B %d, %Y')}</p>
              <p style="color: #E9D5FF; margin: 10px 0 0 0; font-size: 18px;">#{order.acai_pickup_time || 'See confirmation for time'}</p>
            </div>
          </td>
        </tr>
      HTML
    else
      ""
    end

    emoji = order.acai? ? '🍰' : '📦'
    title = order.acai? ? 'Your Acai Cake is Ready!' : 'Your Order is Ready for Pickup!'

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Order Ready for Pickup</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f3f4f6; padding: 20px 0;">
          <tr>
            <td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                
                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #C1191F 0%, #8B0000 100%); padding: 40px 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">Hafaloha</h1>
                    <p style="color: #FFD700; margin: 10px 0 0 0; font-size: 14px;">Chamorro Pride. Island Style.</p>
                  </td>
                </tr>

                <!-- Ready Message -->
                <tr>
                  <td style="padding: 40px 30px; text-align: center;">
                    <div style="background-color: #F0FDF4; border: 2px solid #22C55E; border-radius: 8px; padding: 20px; margin-bottom: 20px;">
                      <h2 style="color: #16A34A; margin: 0; font-size: 24px;">#{emoji} #{title}</h2>
                    </div>
                    <p style="color: #6B7280; margin: 10px 0 0 0; font-size: 16px;">Order ##{order.order_number}</p>
                    <p style="color: #9CA3AF; margin: 5px 0 0 0; font-size: 14px;">Placed on #{order.created_at.strftime('%B %d, %Y')}</p>
                  </td>
                </tr>

                <!-- Pickup Time (for Acai orders) -->
                #{pickup_time_section}

                <!-- Pickup Location -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <div style="background-color: #FEF3C7; border: 1px solid #F59E0B; border-radius: 8px; padding: 20px;">
                      <h3 style="color: #92400E; margin: 0 0 15px 0; font-size: 18px; font-weight: 600;">📍 Pickup Location</h3>
                      <p style="color: #78350F; margin: 0; font-size: 16px; line-height: 1.6;">
                        #{pickup_location}
                      </p>
                      <p style="color: #92400E; margin: 15px 0 0 0; font-size: 14px;">
                        <strong>Questions?</strong> Call #{pickup_phone}
                      </p>
                    </div>
                  </td>
                </tr>

                <!-- Order Items Summary -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <h3 style="color: #111827; margin: 0 0 15px 0; font-size: 18px; font-weight: 600;">Your Order:</h3>
                    <table width="100%" cellpadding="0" cellspacing="0" style="border: 1px solid #E5E7EB; border-radius: 8px; overflow: hidden;">
                      <tbody>
                        #{order_items_html(order)}
                      </tbody>
                    </table>
                  </td>
                </tr>

                <!-- Customer Info -->
                <tr>
                  <td style="padding: 0 30px 30px 30px;">
                    <div style="background-color: #F9FAFB; border-radius: 8px; padding: 20px;">
                      <h3 style="color: #111827; margin: 0 0 10px 0; font-size: 16px; font-weight: 600;">Pickup Information:</h3>
                      <p style="color: #6B7280; margin: 5px 0; font-size: 14px; line-height: 1.6;">
                        <strong>Name:</strong> #{order.name}<br>
                        <strong>Email:</strong> #{order.email}<br>
                        <strong>Phone:</strong> #{order.phone}
                      </p>
                    </div>
                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background-color: #F9FAFB; padding: 30px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #6B7280; margin: 0 0 10px 0; font-size: 14px;">Thank you for your order!</p>
                    <p style="color: #C1191F; margin: 0; font-size: 14px;"><a href="mailto:info@hafaloha.com" style="color: #C1191F; text-decoration: none;">info@hafaloha.com</a> | #{pickup_phone}</p>
                    <p style="color: #9CA3AF; margin: 20px 0 0 0; font-size: 12px;">&copy; #{Time.current.year} Hafaloha. All rights reserved.</p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    HTML
  end

  # Generate contact form notification HTML
  def self.contact_notification_html(submission)
    subject_labels = {
      "general" => "General Inquiry",
      "order" => "Order Question",
      "shipping" => "Shipping & Delivery",
      "returns" => "Returns & Exchanges",
      "wholesale" => "Wholesale / Bulk Orders",
      "other" => "Other"
    }
    subject_display = subject_labels[submission.subject] || submission.subject

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>New Contact Form Submission</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f3f4f6; padding: 20px 0;">
          <tr>
            <td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">

                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #1F2937 0%, #111827 100%); padding: 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: bold;">📬 New Contact Form Message</h1>
                  </td>
                </tr>

                <!-- Content -->
                <tr>
                  <td style="padding: 30px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 24px;">
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">From:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{submission.name}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Email:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">
                            <a href="mailto:#{submission.email}" style="color: #C1191F; text-decoration: none;">#{submission.email}</a>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #E5E7EB;">
                          <strong style="color: #6B7280; font-size: 14px;">Subject:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{subject_display}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0;">
                          <strong style="color: #6B7280; font-size: 14px;">Date:</strong>
                          <span style="color: #111827; font-size: 14px; float: right;">#{submission.created_at.strftime('%B %d, %Y at %I:%M %p')}</span>
                        </td>
                      </tr>
                    </table>

                    <div style="background-color: #F9FAFB; border-left: 4px solid #C1191F; padding: 20px; border-radius: 0 4px 4px 0;">
                      <h3 style="color: #111827; margin: 0 0 10px 0; font-size: 16px; font-weight: 600;">Message</h3>
                      <p style="color: #374151; margin: 0; font-size: 14px; line-height: 1.8; white-space: pre-wrap;">#{submission.message}</p>
                    </div>

                    <div style="margin-top: 24px; text-align: center;">
                      <a href="mailto:#{submission.email}?subject=Re: #{subject_display}" style="display: inline-block; background-color: #C1191F; color: #ffffff; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: 600; font-size: 14px;">Reply to #{submission.name}</a>
                    </div>
                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background-color: #F9FAFB; padding: 20px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #6B7280; margin: 0; font-size: 12px;">This message was sent via the Hafaloha website contact form.</p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    HTML
  end

  # Generate refund notification HTML
  def self.refund_notification_html(order, amount_formatted, reason, refund_date)
    reason_row = if reason.present?
      <<~HTML
        <tr>
          <td style="padding: 8px 0; color: #6B7280; width: 140px; font-weight: 500;">Reason</td>
          <td style="padding: 8px 0; color: #111827; font-weight: 600;">#{reason}</td>
        </tr>
      HTML
    else
      ""
    end

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Refund Processed</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f3f4f6; padding: 20px 0;">
          <tr>
            <td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">

                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #C1191F 0%, #8B0000 100%); padding: 40px 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">Hafaloha</h1>
                    <p style="color: #FFD700; margin: 10px 0 0 0; font-size: 14px;">Chamorro Pride. Island Style.</p>
                  </td>
                </tr>

                <!-- Refund Info -->
                <tr>
                  <td style="padding: 40px 30px;">
                    <h2 style="color: #111827; margin: 0 0 20px 0; font-size: 24px;">Refund Processed</h2>

                    <p style="color: #6B7280; font-size: 16px;">Hi #{order.name || 'there'},</p>
                    <p style="color: #6B7280; font-size: 16px;">We've processed a refund for your order. Here are the details:</p>

                    <div style="background-color: #F9FAFB; border-left: 4px solid #C1191F; padding: 20px; margin: 24px 0; border-radius: 0 4px 4px 0;">
                      <table width="100%" cellpadding="0" cellspacing="0">
                        <tr>
                          <td style="padding: 8px 0; color: #6B7280; width: 140px; font-weight: 500;">Order Number</td>
                          <td style="padding: 8px 0; color: #111827; font-weight: 600;">##{order.order_number}</td>
                        </tr>
                        <tr>
                          <td style="padding: 8px 0; color: #6B7280; width: 140px; font-weight: 500;">Refund Amount</td>
                          <td style="padding: 8px 0; color: #C1191F; font-size: 24px; font-weight: 700;">#{amount_formatted}</td>
                        </tr>
                        #{reason_row}
                        <tr>
                          <td style="padding: 8px 0; color: #6B7280; width: 140px; font-weight: 500;">Refund Date</td>
                          <td style="padding: 8px 0; color: #111827; font-weight: 600;">#{refund_date}</td>
                        </tr>
                      </table>
                    </div>

                    <div style="background-color: #FEF3C7; border: 1px solid #F59E0B; padding: 16px 20px; border-radius: 4px; margin: 24px 0; font-size: 14px; color: #92400E;">
                      <strong style="display: block; margin-bottom: 4px;">📅 When will I see my refund?</strong>
                      Please allow 5&ndash;10 business days for the refund to appear on your original payment method.
                      Processing times may vary depending on your bank or card issuer.
                    </div>

                    <p style="color: #6B7280; font-size: 16px;">If you have any questions about this refund, please don't hesitate to reach out to us.</p>
                    <p style="color: #6B7280; font-size: 16px;">Thank you for shopping with Hafaloha!</p>
                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background-color: #F9FAFB; padding: 30px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #6B7280; margin: 0 0 10px 0; font-size: 14px;">Questions about your order?</p>
                    <p style="color: #C1191F; margin: 0; font-size: 14px;"><a href="mailto:info@hafaloha.com" style="color: #C1191F; text-decoration: none;">info@hafaloha.com</a> | (671) 777-1234</p>
                    <p style="color: #9CA3AF; margin: 20px 0 0 0; font-size: 12px;">&copy; #{Time.current.year} Hafaloha. All rights reserved.</p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    HTML
  end

end
