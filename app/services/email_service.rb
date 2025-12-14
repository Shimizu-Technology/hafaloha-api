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
        from: "Hafaloha <orders@hafaloha.com>",
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
        from: "Hafaloha <orders@hafaloha.com>",
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
        from: "Hafaloha <orders@hafaloha.com>",
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

  private

  # Generate customer confirmation HTML
  def self.order_confirmation_html(order)
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
end

