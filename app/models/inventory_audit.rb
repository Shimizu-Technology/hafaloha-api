# Tracks all inventory changes for audit trail and accountability
# Supports both variant-level and product-level inventory tracking
class InventoryAudit < ApplicationRecord
  # Associations
  belongs_to :product_variant, optional: true
  belongs_to :product, optional: true
  belongs_to :user, optional: true
  belongs_to :order, optional: true

  # Validations
  validates :audit_type, presence: true
  validates :audit_type, inclusion: { 
    in: %w[order_placed order_cancelled order_refunded restock manual_adjustment 
           damaged import variant_created inventory_sync] 
  }
  validates :quantity_change, :previous_quantity, :new_quantity, presence: true
  validate :must_have_product_or_variant

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_variant, ->(variant_id) { where(product_variant_id: variant_id) }
  scope :for_product, ->(product_id) { where(product_id: product_id) }
  scope :for_order, ->(order_id) { where(order_id: order_id) }
  scope :by_type, ->(type) { where(audit_type: type) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :stock_increases, -> { where('quantity_change > 0') }
  scope :stock_decreases, -> { where('quantity_change < 0') }
  scope :in_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # ==========================================
  # Class Methods for Creating Audit Records
  # ==========================================

  # Create audit for order placement (stock decrement)
  def self.record_order_placed(variant:, quantity:, order:, previous_qty: nil)
    previous_qty ||= variant.stock_quantity + quantity # Calculate if not provided
    new_qty = variant.stock_quantity

    create!(
      product_variant: variant,
      product: variant.product,
      audit_type: 'order_placed',
      quantity_change: -quantity,
      previous_quantity: previous_qty,
      new_quantity: new_qty,
      order: order,
      reason: "Order ##{order.order_number} placed",
      metadata: build_metadata(variant, order)
    )
  end

  # Create audit for order cancellation (stock increment)
  def self.record_order_cancelled(variant:, quantity:, order:, user: nil)
    previous_qty = variant.stock_quantity - quantity
    new_qty = variant.stock_quantity

    create!(
      product_variant: variant,
      product: variant.product,
      audit_type: 'order_cancelled',
      quantity_change: quantity,
      previous_quantity: previous_qty,
      new_quantity: new_qty,
      order: order,
      user: user,
      reason: "Order ##{order.order_number} cancelled - stock restored",
      metadata: build_metadata(variant, order)
    )
  end

  # Create audit for order refund (stock increment)
  def self.record_order_refunded(variant:, quantity:, order:, user: nil)
    previous_qty = variant.stock_quantity - quantity
    new_qty = variant.stock_quantity

    create!(
      product_variant: variant,
      product: variant.product,
      audit_type: 'order_refunded',
      quantity_change: quantity,
      previous_quantity: previous_qty,
      new_quantity: new_qty,
      order: order,
      user: user,
      reason: "Order ##{order.order_number} refunded - stock restored",
      metadata: build_metadata(variant, order)
    )
  end

  # Create audit for manual stock adjustment by admin
  def self.record_manual_adjustment(variant:, previous_qty:, new_qty:, reason:, user:)
    quantity_change = new_qty - previous_qty

    create!(
      product_variant: variant,
      product: variant.product,
      audit_type: 'manual_adjustment',
      quantity_change: quantity_change,
      previous_quantity: previous_qty,
      new_quantity: new_qty,
      user: user,
      reason: reason.presence || "Manual adjustment by #{user&.name || 'admin'}",
      metadata: build_metadata(variant).merge(adjusted_by: user&.email)
    )
  end

  # Create audit for restock
  def self.record_restock(variant:, quantity_added:, reason: nil, user: nil)
    previous_qty = variant.stock_quantity - quantity_added
    new_qty = variant.stock_quantity

    create!(
      product_variant: variant,
      product: variant.product,
      audit_type: 'restock',
      quantity_change: quantity_added,
      previous_quantity: previous_qty,
      new_quantity: new_qty,
      user: user,
      reason: reason.presence || "Restocked #{quantity_added} units",
      metadata: build_metadata(variant).merge(restocked_by: user&.email)
    )
  end

  # Create audit for damaged items
  def self.record_damaged(variant:, quantity_damaged:, reason:, user: nil)
    previous_qty = variant.stock_quantity + quantity_damaged
    new_qty = variant.stock_quantity

    create!(
      product_variant: variant,
      product: variant.product,
      audit_type: 'damaged',
      quantity_change: -quantity_damaged,
      previous_quantity: previous_qty,
      new_quantity: new_qty,
      user: user,
      reason: "Marked as damaged: #{reason}",
      metadata: build_metadata(variant).merge(
        damaged_quantity: quantity_damaged,
        damage_reason: reason,
        reported_by: user&.email
      )
    )
  end

  # Create audit for CSV import
  def self.record_import(variant:, initial_quantity:, user: nil)
    create!(
      product_variant: variant,
      product: variant.product,
      audit_type: 'import',
      quantity_change: initial_quantity,
      previous_quantity: 0,
      new_quantity: initial_quantity,
      user: user,
      reason: "Imported via CSV",
      metadata: build_metadata(variant).merge(imported_by: user&.email)
    )
  end

  # Create audit for variant creation with initial stock
  def self.record_variant_created(variant:, initial_quantity:, user: nil)
    create!(
      product_variant: variant,
      product: variant.product,
      audit_type: 'variant_created',
      quantity_change: initial_quantity,
      previous_quantity: 0,
      new_quantity: initial_quantity,
      user: user,
      reason: "Variant created with initial stock of #{initial_quantity}",
      metadata: build_metadata(variant).merge(created_by: user&.email)
    )
  end

  # Create audit for product-level stock change
  def self.record_product_stock_change(product:, previous_qty:, new_qty:, reason:, audit_type:, order: nil, user: nil)
    quantity_change = new_qty - previous_qty

    create!(
      product: product,
      product_variant: nil,
      audit_type: audit_type,
      quantity_change: quantity_change,
      previous_quantity: previous_qty,
      new_quantity: new_qty,
      order: order,
      user: user,
      reason: reason,
      metadata: {
        product_id: product.id,
        product_name: product.name,
        product_sku: product.sku_prefix,
        inventory_level: 'product'
      }
    )
  end

  # ==========================================
  # Instance Methods
  # ==========================================

  def stock_increase?
    quantity_change > 0
  end

  def stock_decrease?
    quantity_change < 0
  end

  def stock_neutral?
    quantity_change == 0
  end

  def formatted_change
    return "No change" if quantity_change == 0
    return "+#{quantity_change}" if quantity_change > 0
    quantity_change.to_s
  end

  def order_related?
    %w[order_placed order_cancelled order_refunded].include?(audit_type)
  end

  def admin_action?
    %w[manual_adjustment restock damaged inventory_sync].include?(audit_type)
  end

  def system_action?
    %w[variant_created import].include?(audit_type)
  end

  def display_name
    if product_variant.present?
      "#{product_variant.product.name} - #{product_variant.display_name}"
    elsif product.present?
      product.name
    else
      "Unknown"
    end
  end

  def user_display
    user&.name || user&.email || 'System'
  end

  private

  def must_have_product_or_variant
    if product_variant_id.blank? && product_id.blank?
      errors.add(:base, "Must have either a product or product_variant")
    end
  end

  def self.build_metadata(variant, order = nil)
    metadata = {
      variant_id: variant.id,
      variant_name: variant.display_name,
      variant_sku: variant.sku,
      product_id: variant.product.id,
      product_name: variant.product.name,
      inventory_level: 'variant'
    }

    if order.present?
      metadata.merge!(
        order_id: order.id,
        order_number: order.order_number,
        customer_name: order.customer_name,
        customer_email: order.customer_email
      )
    end

    metadata
  end
end
