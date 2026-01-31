# frozen_string_literal: true

module Webhooks
  class StripeController < ApplicationController
    # Stripe sends raw JSON — we need the raw body for signature verification.
    # No authentication needed — webhooks come from Stripe, not users.
    # CSRF is already disabled (Rails API-only app).
    before_action :set_raw_body

    # POST /webhooks/stripe
    def create
      event = verify_and_construct_event
      return head :bad_request unless event

      handle_event(event)

      head :ok
    end

    private

    # ── Signature Verification ──────────────────────────────────────

    def set_raw_body
      @raw_body = request.body.read
    end

    def verify_and_construct_event
      webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]

      if webhook_secret.blank?
        Rails.logger.warn "⚠️  Stripe webhook signature verification SKIPPED (no webhook secret configured)"
        return parse_unverified_event
      end

      verify_stripe_signature(webhook_secret)
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "❌ Stripe webhook signature verification failed: #{e.message}"
      nil
    rescue JSON::ParserError => e
      Rails.logger.error "❌ Stripe webhook JSON parse error: #{e.message}"
      nil
    end

    def parse_unverified_event
      data = JSON.parse(@raw_body)
      Stripe::Event.construct_from(data)
    rescue JSON::ParserError => e
      Rails.logger.error "❌ Stripe webhook JSON parse error: #{e.message}"
      nil
    end

    def verify_stripe_signature(webhook_secret)
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      Stripe::Webhook.construct_event(@raw_body, sig_header, webhook_secret)
    end

    # ── Event Routing ───────────────────────────────────────────────

    def handle_event(event)
      case event.type
      when "payment_intent.succeeded"
        handle_payment_intent_succeeded(event.data.object)
      when "payment_intent.payment_failed"
        handle_payment_intent_failed(event.data.object)
      when "charge.refunded"
        handle_charge_refunded(event.data.object)
      when "charge.dispute.created"
        handle_charge_dispute_created(event.data.object)
      else
        Rails.logger.info "ℹ️  Stripe webhook received unhandled event: #{event.type}"
      end
    end

    # ── Event Handlers ──────────────────────────────────────────────

    def handle_payment_intent_succeeded(payment_intent)
      order = find_order_from_payment_intent(payment_intent)
      return unless order

      if order.payment_status == "paid"
        Rails.logger.info "ℹ️  Order ##{order.id} already marked as paid — skipping duplicate webhook"
        return
      end

      order.update!(payment_status: "paid")
      Rails.logger.info "✅ Order ##{order.id} payment_status updated to 'paid' via Stripe webhook"

      # Trigger confirmation email
      SendOrderConfirmationEmailJob.perform_later(order.id)
      Rails.logger.info "📧 Order confirmation email enqueued for Order ##{order.id}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Failed to update Order ##{order&.id}: #{e.message}"
    end

    def handle_payment_intent_failed(payment_intent)
      order = find_order_from_payment_intent(payment_intent)
      return unless order

      order.update!(payment_status: "failed")
      Rails.logger.error "❌ Payment failed for Order ##{order.id} (payment_intent: #{payment_intent.id})"

      # Log the failure reason if available
      if payment_intent.respond_to?(:last_payment_error) && payment_intent.last_payment_error
        Rails.logger.error "   Failure reason: #{payment_intent.last_payment_error.message}"
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Failed to update Order ##{order&.id}: #{e.message}"
    end

    def handle_charge_refunded(charge)
      # Find order by payment_intent_id from the charge
      payment_intent_id = charge.respond_to?(:payment_intent) ? charge.payment_intent : nil
      order = Order.find_by(payment_intent_id: payment_intent_id) if payment_intent_id.present?

      unless order
        Rails.logger.warn "⚠️  Received charge.refunded but could not find order (charge: #{charge.id}, payment_intent: #{payment_intent_id})"
        return
      end

      order.update!(payment_status: "refunded")
      Rails.logger.info "💸 Order ##{order.id} payment_status updated to 'refunded' via Stripe webhook"
      # Full refund logic (inventory restoration, email, etc.) comes in HAF-17
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Failed to update Order ##{order&.id} for refund: #{e.message}"
    end

    def handle_charge_dispute_created(dispute)
      Rails.logger.warn "⚠️  Charge dispute created: #{dispute.id} — manual review required"
      # Future: notify admin via SendAdminNotificationEmailJob or Slack
    end

    # ── Helpers ──────────────────────────────────────────────────────

    def find_order_from_payment_intent(payment_intent)
      # First try: find by metadata.order_id (set when creating the payment intent)
      order_id = payment_intent.respond_to?(:metadata) && payment_intent.metadata.respond_to?(:order_id) ?
                 payment_intent.metadata.order_id : nil

      order = Order.find_by(id: order_id) if order_id.present?
      return order if order

      # Fallback: find by payment_intent_id stored on the order
      order = Order.find_by(payment_intent_id: payment_intent.id) if payment_intent.id.present?
      return order if order

      Rails.logger.warn "⚠️  Could not find order for payment_intent #{payment_intent.id} (metadata.order_id: #{order_id})"
      nil
    end
  end
end
