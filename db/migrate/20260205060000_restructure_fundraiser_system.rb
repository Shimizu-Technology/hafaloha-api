class RestructureFundraiserSystem < ActiveRecord::Migration[8.1]
  def change
    # ============================================
    # 1. Update Fundraisers table
    # ============================================
    add_column :fundraisers, :organization_name, :string unless column_exists?(:fundraisers, :organization_name)
    add_column :fundraisers, :payout_percentage, :decimal, precision: 5, scale: 2, default: 0.0 unless column_exists?(:fundraisers, :payout_percentage)
    add_column :fundraisers, :published, :boolean, default: false, null: false unless column_exists?(:fundraisers, :published)

    # ============================================
    # 2. Drop and recreate fundraiser_products as standalone
    # ============================================
    drop_table :fundraiser_products, if_exists: true

    create_table :fundraiser_products do |t|
      t.references :fundraiser, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :base_price_cents
      t.string :inventory_level, default: "none", null: false
      t.integer :product_stock_quantity, default: 0
      t.boolean :featured, default: false, null: false
      t.boolean :published, default: true, null: false
      t.string :sku_prefix
      t.decimal :weight_oz, precision: 8, scale: 2
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :fundraiser_products, :slug, unique: true
    add_index :fundraiser_products, [ :fundraiser_id, :position ]
    add_index :fundraiser_products, [ :fundraiser_id, :published ]

    # ============================================
    # 3. Create fundraiser_product_variants
    # ============================================
    create_table :fundraiser_product_variants do |t|
      t.references :fundraiser_product, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :variant_name
      t.string :variant_key
      t.string :size
      t.string :color
      t.string :material
      t.jsonb :options, default: {}
      t.integer :price_cents, null: false
      t.integer :compare_at_price_cents
      t.integer :stock_quantity, default: 0
      t.boolean :available, default: true, null: false
      t.boolean :is_default, default: false, null: false
      t.decimal :weight_oz, precision: 8, scale: 2
      t.integer :low_stock_threshold, default: 5

      t.timestamps
    end

    add_index :fundraiser_product_variants, :sku, unique: true
    add_index :fundraiser_product_variants, [ :fundraiser_product_id, :available ]

    # ============================================
    # 4. Create fundraiser_product_images
    # ============================================
    create_table :fundraiser_product_images do |t|
      t.references :fundraiser_product, null: false, foreign_key: true
      t.string :s3_key, null: false
      t.string :alt_text
      t.integer :position, default: 0, null: false
      t.boolean :primary, default: false, null: false

      t.timestamps
    end

    add_index :fundraiser_product_images, [ :fundraiser_product_id, :position ]
    add_index :fundraiser_product_images, [ :fundraiser_product_id, :primary ]

    # ============================================
    # 5. Update Participants table - add unique_code
    # ============================================
    add_column :participants, :unique_code, :string unless column_exists?(:participants, :unique_code)
    add_column :participants, :goal_amount_cents, :integer unless column_exists?(:participants, :goal_amount_cents)

    add_index :participants, :unique_code, unique: true unless index_exists?(:participants, :unique_code)

    # ============================================
    # 6. Create fundraiser_orders
    # ============================================
    create_table :fundraiser_orders do |t|
      t.references :fundraiser, null: false, foreign_key: true
      t.references :participant, null: true, foreign_key: true
      t.string :order_number, null: false
      t.string :status, default: "pending", null: false
      t.string :payment_status, default: "pending", null: false

      # Customer info
      t.string :customer_email
      t.string :customer_name
      t.string :customer_phone

      # Shipping address
      t.string :shipping_address_line1
      t.string :shipping_address_line2
      t.string :shipping_city
      t.string :shipping_state
      t.string :shipping_zip
      t.string :shipping_country, default: "US"

      # Totals
      t.integer :subtotal_cents, default: 0, null: false
      t.integer :shipping_cents, default: 0, null: false
      t.integer :tax_cents, default: 0, null: false
      t.integer :total_cents, default: 0, null: false

      # Payment
      t.string :stripe_payment_intent_id

      # Notes
      t.text :notes
      t.text :admin_notes

      t.timestamps
    end

    add_index :fundraiser_orders, :order_number, unique: true
    add_index :fundraiser_orders, [ :fundraiser_id, :status ]
    add_index :fundraiser_orders, [ :fundraiser_id, :payment_status ]
    add_index :fundraiser_orders, [ :participant_id, :payment_status ]
    add_index :fundraiser_orders, :stripe_payment_intent_id

    # ============================================
    # 7. Create fundraiser_order_items
    # ============================================
    create_table :fundraiser_order_items do |t|
      t.references :fundraiser_order, null: false, foreign_key: true
      t.references :fundraiser_product_variant, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.integer :price_cents, null: false
      t.string :product_name
      t.string :variant_name

      t.timestamps
    end

    add_index :fundraiser_order_items, [ :fundraiser_order_id, :fundraiser_product_variant_id ],
              name: "idx_fundraiser_order_items_order_variant"
  end
end
