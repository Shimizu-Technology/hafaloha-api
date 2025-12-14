class AddSendCustomerEmailsToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :send_customer_emails, :boolean, default: false, null: false
  end
end
