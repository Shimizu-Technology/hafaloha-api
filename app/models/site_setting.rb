class SiteSetting < ApplicationRecord
  # Singleton pattern - only one record should ever exist
  validates :payment_processor, presence: true, inclusion: { in: %w[stripe paypal] }
  validates :payment_test_mode, inclusion: { in: [true, false] }

  # Singleton accessor
  def self.instance
    first_or_create!(
      payment_test_mode: true,
      payment_processor: 'stripe',
      send_customer_emails: false, # Off by default for development
      store_name: 'Hafaloha',
      store_email: 'info@hafaloha.com',
      store_phone: '671-777-1234',
      order_notification_emails: ['shimizutechnology@gmail.com'],
      shipping_origin_address: {
        company: "Hafaloha",
        street1: "221 LIRIO AVE",
        city: "BARRIGADA",
        state: "GU",
        zip: "96913",
        country: "US",
        phone: "671-777-1234"
      }
    )
  end

  # Prevent deletion of the singleton record
  before_destroy :prevent_destroy

  # Helper methods
  def test_mode?
    payment_test_mode
  end

  def production_mode?
    !payment_test_mode
  end

  def using_stripe?
    payment_processor == 'stripe'
  end

  def using_paypal?
    payment_processor == 'paypal'
  end

  private

  def prevent_destroy
    raise ActiveRecord::RecordNotDestroyed, "Cannot delete the site settings record"
  end
end

