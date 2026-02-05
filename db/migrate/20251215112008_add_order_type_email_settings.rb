# frozen_string_literal: true

class AddOrderTypeEmailSettings < ActiveRecord::Migration[8.0]
  def change
    # Add separate email toggles for each order type
    add_column :site_settings, :send_retail_emails, :boolean, default: false, null: false
    add_column :site_settings, :send_acai_emails, :boolean, default: false, null: false
    add_column :site_settings, :send_wholesale_emails, :boolean, default: false, null: false

    # Keep send_customer_emails as a legacy field for backwards compatibility
    # but we'll migrate to using the per-order-type fields
  end
end
