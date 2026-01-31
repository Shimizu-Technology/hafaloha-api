# frozen_string_literal: true

class OrderMailer < ApplicationMailer
  default from: 'orders@hafaloha.com'

  def refund_notification(order, refund)
    @order = order
    @refund = refund
    @amount = "$#{'%.2f' % (refund.amount_cents / 100.0)}"
    mail(to: order.email, subject: "Hafaloha \u2014 Refund Processed for Order ##{order.order_number}")
  end
end
