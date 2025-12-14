class CreateSiteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :site_settings do |t|
      t.boolean :payment_test_mode, default: true, null: false
      t.string :payment_processor, default: 'stripe', null: false
      t.string :store_name, default: 'Hafaloha'
      t.string :store_email
      t.string :store_phone
      t.text :order_notification_emails, array: true, default: []
      t.jsonb :shipping_origin_address, default: {}

      t.timestamps
    end

    # Ensure only one record exists (singleton pattern)
    # This will be enforced in the model as well
    reversible do |dir|
      dir.up do
        # Create the initial settings record
        execute <<-SQL
          INSERT INTO site_settings (
            payment_test_mode,
            payment_processor,
            store_name,
            store_email,
            store_phone,
            order_notification_emails,
            shipping_origin_address,
            created_at,
            updated_at
          ) VALUES (
            true,
            'stripe',
            'Hafaloha',
            'info@hafaloha.com',
            '671-777-1234',
            ARRAY['shimizutechnology@gmail.com']::text[],
            '{"company": "Hafaloha", "street1": "221 LIRIO AVE", "city": "BARRIGADA", "state": "GU", "zip": "96913", "country": "US", "phone": "671-777-1234"}'::jsonb,
            NOW(),
            NOW()
          );
        SQL
      end
    end
  end
end

