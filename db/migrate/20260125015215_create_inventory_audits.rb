class CreateInventoryAudits < ActiveRecord::Migration[8.0]
  def change
    create_table :inventory_audits do |t|
      # Can track either product-level OR variant-level (at least one must be present)
      t.references :product_variant, null: true, foreign_key: true
      t.references :product, null: true, foreign_key: true

      # Type of audit event
      t.string :audit_type, null: false
      # Values: order_placed, order_cancelled, order_refunded,
      #         restock, manual_adjustment, damaged,
      #         import, variant_created, inventory_sync

      # Quantity changes
      t.integer :quantity_change, null: false, default: 0
      t.integer :previous_quantity, null: false, default: 0
      t.integer :new_quantity, null: false, default: 0

      # Reason for the change (human-readable)
      t.text :reason

      # Who made the change (optional for system/order changes)
      t.references :user, null: true, foreign_key: true

      # Associated order (for order-related changes)
      t.references :order, null: true, foreign_key: true

      # Rich metadata for querying/display
      t.jsonb :metadata, default: {}
      # Stores: { variant_name, product_name, sku, order_number, customer_name, ... }

      t.timestamps
    end

    # Indexes for efficient querying
    add_index :inventory_audits, :audit_type
    add_index :inventory_audits, :created_at
    add_index :inventory_audits, [ :product_variant_id, :created_at ], name: 'idx_audits_on_variant_and_date'
    add_index :inventory_audits, [ :product_id, :created_at ], name: 'idx_audits_on_product_and_date'
    add_index :inventory_audits, [ :user_id, :created_at ], name: 'idx_audits_on_user_and_date'
    add_index :inventory_audits, [ :order_id ], name: 'idx_audits_on_order'
  end
end
