# 🗄️ Database Schema Reference

**Purpose:** Quick reference for all database models, fields, and relationships.

---

## 📊 Core Models

### **users**
Clerk-managed users (customers + admins)

| Field | Type | Notes |
|-------|------|-------|
| clerk_id | string | Clerk user ID (unique) |
| email | string | User email |
| name | string | Full name |
| phone | string | Phone number |
| role | string | 'customer' or 'admin' |
| metadata | jsonb | For future extensions |

**Admin Access:**
- **Whitelist (ADMIN_EMAILS constant):** `shimizutechnology@gmail.com`, `jerry.shimizutechnology@gmail.com` — auto-promoted on first login
- Any existing admin can promote other users via the Admin UI (User Management page)
- Role field: `'customer'` or `'admin'`

---

### **products**
All products (retail, wholesale, acai)

| Field | Type | Notes |
|-------|------|-------|
| name | string | Product name |
| slug | string | URL-friendly (unique) |
| description | text | HTML content |
| base_price_cents | integer | Base price before variant adjustments |
| sku_prefix | string | e.g., "HAF-TSHIRT" |
| weight_oz | decimal | For shipping calculation |
| product_type | string | 'retail', 'wholesale', 'acai' |
| published | boolean | Visible to customers |
| featured | boolean | Show on homepage |
| archived | boolean | Soft-deleted |
| inventory_level | string | 'none', 'product', 'variant' |
| product_stock_quantity | integer | For product-level tracking |
| vendor | string | Brand/vendor (from Shopify) |
| tags | text[] | Shopify tags |

**Relationships:**
- `has_many :product_variants`
- `has_many :product_images`
- `has_many :collections, through: :product_collections`

---

### **product_variants**
Size/color combinations with pricing and inventory

| Field | Type | Notes |
|-------|------|-------|
| product_id | references | Parent product |
| size | string | e.g., "M", "L", "XL" |
| color | string | e.g., "Red", "Blue" |
| material | string | e.g., "Cotton" |
| variant_key | string | "size:M,color:Red" |
| variant_name | string | "Medium / Red" |
| sku | string | "HAF-TSHIRT-M-RED" (unique) |
| price_cents | integer | Overrides base price if set |
| cost_cents | integer | Cost per unit |
| compare_at_price_cents | integer | "Was $50, now $40" |
| stock_quantity | integer | Current inventory |
| low_stock_threshold | integer | Default 5 |
| available | boolean | Can be disabled even if in stock |
| is_default | boolean | Auto-created for product-level inventory |

**Computed Availability:**
- `available` flag + stock level = `actually_available?`
- Returns true only if manually available AND in stock (when tracking enabled)

---

### **product_images**
Product photos (S3)

| Field | Type | Notes |
|-------|------|-------|
| product_id | references | Parent product |
| s3_key | string | Permanent S3 object key |
| url | string | Legacy field (use `signed_url` method) |
| alt_text | string | For accessibility |
| position | integer | Sort order |
| primary | boolean | Main product image |

**Image Handling:**
- Stored in S3: `hafaloha-images` bucket
- Generate signed URLs on-demand via `signed_url` method
- Never store signed URLs (they expire)

---

### **collections**
Product categories (Apparel, Hats, Bags, etc.)

| Field | Type | Notes |
|-------|------|-------|
| name | string | Collection name |
| slug | string | URL-friendly (unique) |
| description | text | Collection description |
| image_url | string | Banner image |
| published | boolean | Visible to customers |
| featured | boolean | Show on homepage |
| sort_order | integer | Display order |

**Relationships:**
- `has_many :products, through: :product_collections`

---

### **orders**
All orders (retail, wholesale, acai)

| Field | Type | Notes |
|-------|------|-------|
| order_number | string | "HAF-12345" (unique) |
| user_id | references | Nullable for guest checkout |
| order_type | string | 'retail', 'wholesale', 'acai' |
| customer_name | string | Customer full name |
| customer_email | string | Customer email |
| customer_phone | string | Customer phone |
| subtotal_cents | integer | Sum of all items |
| shipping_cost_cents | integer | Calculated by EasyPost |
| tax_cents | integer | Tax amount |
| total_cents | integer | subtotal + shipping + tax |
| status | string | 'pending', 'paid', 'processing', 'shipped', 'delivered', 'fulfilled', 'cancelled' |
| payment_status | string | 'pending', 'paid', 'failed', 'refunded' |
| payment_intent_id | string | Stripe Payment Intent ID |
| payment_test_mode | boolean | If true, no real Stripe charge |
| shipping_* | various | Shipping address fields |
| tracking_number | string | Shipment tracking |

**Relationships:**
- `belongs_to :user` (optional)
- `has_many :order_items`

---

### **order_items**
Line items in an order

| Field | Type | Notes |
|-------|------|-------|
| order_id | references | Parent order |
| product_id | references | Product purchased |
| product_variant_id | references | Variant purchased |
| quantity | integer | Number of items |
| unit_price_cents | integer | Price per item (snapshot) |
| total_price_cents | integer | quantity × unit_price |
| product_name | string | Snapshot of product name |
| product_sku | string | Snapshot of SKU |
| variant_name | string | Snapshot of variant |

---

### **site_settings** (Singleton)
Global application settings

| Field | Type | Notes |
|-------|------|-------|
| payment_test_mode | boolean | If true, bypass Stripe |
| send_customer_emails | boolean | Enable/disable customer emails |

**Usage:**
```ruby
settings = SiteSetting.instance
settings.payment_test_mode = true
settings.save!
```

---

### **imports**
CSV import history

| Field | Type | Notes |
|-------|------|-------|
| user_id | references | Admin who started import |
| file_name | string | Original CSV filename |
| status | string | 'pending', 'processing', 'completed', 'failed' |
| products_created | integer | Count of new products |
| products_updated | integer | Count of updated products |
| products_skipped | integer | Count of skipped products |
| variants_created | integer | Count of new variants |
| images_created | integer | Count of new images |
| collections_created | integer | Count of new collections |
| error_message | text | Error details if failed |
| warnings | text | Warnings during import |
| completed_at | datetime | When import finished |

---

## 🛒 Wholesale/Fundraiser Models

### **fundraisers**
Wholesale fundraiser campaigns

| Field | Type | Notes |
|-------|------|-------|
| name | string | Fundraiser name |
| slug | string | URL-friendly (unique) |
| description | text | Campaign description |
| start_date | date | Campaign start |
| end_date | date | Campaign end |
| contact_email | string | Contact email |
| contact_phone | string | Contact phone |
| banner_url | string | Banner image |
| card_image_url | string | Card image |
| active | boolean | Currently active |

**Relationships:**
- `has_many :fundraiser_products`
- `has_many :participants`
- `has_many :orders`

---

### **fundraiser_products**
Products specific to a fundraiser campaign

| Field | Type | Notes |
|-------|------|-------|
| fundraiser_id | references | Parent fundraiser |
| product_id | references | Associated product |

**Relationships:**
- `belongs_to :fundraiser`
- `belongs_to :product`

---

### **participants**
Fundraiser participants (teams, individuals)

| Field | Type | Notes |
|-------|------|-------|
| fundraiser_id | references | Parent fundraiser |
| name | string | Participant name |
| email | string | Participant email |
| phone | string | Participant phone |
| active | boolean | Currently active |

**Relationships:**
- `belongs_to :fundraiser`

---

## 🍰 Acai Cakes Models

### **acai_pickup_windows**
Available pickup time slots per day of week

| Field | Type | Notes |
|-------|------|-------|
| day_of_week | integer | 0-6 (0=Sunday) |
| start_time | string | e.g., "13:30" |
| end_time | string | e.g., "15:30" |
| slot_duration_minutes | integer | e.g., 30 |
| active | boolean | Whether this window is active |

---

### **acai_blocked_slots**
Blocked dates/times (holidays, fully booked)

| Field | Type | Notes |
|-------|------|-------|
| date | date | Specific date to block |
| start_time | string | e.g., "14:00" |
| end_time | string | e.g., "14:30" |
| reason | string | e.g., "Holiday", "Fully booked" |

---

### **acai_crust_options**
Crust choices for Acai Cakes

| Field | Type | Notes |
|-------|------|-------|
| name | string | e.g., "Graham Cracker", "Oreo" |
| additional_price_cents | integer | Price modifier |
| available | boolean | Currently available |
| position | integer | Sort order |

---

### **acai_placard_options**
Placard/topper choices for Acai Cakes

| Field | Type | Notes |
|-------|------|-------|
| name | string | e.g., "Birthday", "Anniversary" |
| additional_price_cents | integer | Price modifier |
| available | boolean | Currently available |
| position | integer | Sort order |

---

### **acai_settings**
System settings for Acai Cake ordering

| Field | Type | Notes |
|-------|------|-------|
| advance_notice_hours | integer | e.g., 24 (hours in advance required) |
| max_orders_per_slot | integer | Capacity per time slot |
| ordering_enabled | boolean | Global on/off for Acai ordering |

---

## 📦 Inventory & Variant Models

### **inventory_audits**
Audit trail for stock changes

| Field | Type | Notes |
|-------|------|-------|
| product_id | references | Product audited |
| product_variant_id | references | Variant audited (nullable) |
| user_id | references | Admin who made the change |
| previous_quantity | integer | Stock before change |
| new_quantity | integer | Stock after change |
| reason | string | Reason for change |
| audit_type | string | e.g., 'manual_adjustment', 'order_deduction' |

---

### **variant_presets**
Reusable variant templates (for flexible variant types)

| Field | Type | Notes |
|-------|------|-------|
| name | string | Preset name (e.g., "Standard Apparel Sizes") |
| variant_type | string | e.g., "size", "color", "material" |
| values | jsonb | Array of option values |
| active | boolean | Currently available |

---

## 🔗 Key Relationships

```
User → Orders
Product → Variants, Images, Collections
Order → OrderItems → Product + Variant
Collection → Products (many-to-many via ProductCollection)
Fundraiser → FundraiserProducts → Product
Fundraiser → Participants
Fundraiser → Orders
InventoryAudit → Product, ProductVariant, User
```

---

## 🛡️ Critical Inventory Logic

### **3-Level Inventory Tracking:**

1. **No Tracking (`inventory_level: 'none'`):**
   - Product is always available
   - No stock checks
   - Use for digital products, pre-orders

2. **Product-Level (`inventory_level: 'product'`):**
   - Track total quantity across all variants
   - Uses `product_stock_quantity`
   - Good for hats, keychains without size/color

3. **Variant-Level (`inventory_level: 'variant'`):**
   - Track stock per variant (size/color)
   - Uses `product_variants.stock_quantity`
   - Most common for apparel

### **Race Condition Prevention:**

```ruby
# Cart validation (orders_controller.rb)
variant.with_lock do
  if variant.stock_quantity < quantity
    raise "Out of stock"
  end
  # Deduct stock atomically
  variant.update!(stock_quantity: variant.stock_quantity - quantity)
end
```

---

## 📥 Shopify Import Mapping

| Shopify CSV | Hafaloha DB |
|-------------|-------------|
| Handle | products.slug |
| Title | products.name |
| Body (HTML) | products.description |
| Vendor | products.vendor |
| Type | products.product_type |
| Tags | products.tags |
| Variant SKU | product_variants.sku |
| Variant Price | product_variants.price_cents (× 100) |
| Variant Grams | product_variants.weight_oz (÷ 28.35) |
| Image Src | Download → S3 → product_images.s3_key |

**Import Command:**
```bash
rails runner lib/tasks/import.rake products_export.csv
```

---

## 🚀 Quick Setup

```bash
# Create database
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Seed sample data
bin/rails db:seed

# Check schema
bin/rails db:schema:dump
```

---

**Need more details?** Check the full schema: `db/schema.rb`

