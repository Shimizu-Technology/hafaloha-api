# 📥 Shopify Product Import Guide

**Purpose:** Import products from Shopify CSV export into Hafaloha.

---

## Quick Start

### **Option 1: Admin UI (Recommended)**

1. Log in as admin
2. Go to `/admin/import`
3. Upload `products_export.csv` from Shopify
4. Click "Import"
5. Wait for completion (background job)

### **Option 2: Command Line**

```bash
cd hafaloha-api

# Import from Shopify CSV
bin/rails import:shopify[scripts/products_export.csv]
```

**That's it!** The script will:
- ✅ Create products & variants
- ✅ Download images from Shopify → Upload to S3
- ✅ Create collections from tags
- ✅ Handle duplicates gracefully
- ✅ Skip logo/placeholder images

---

## What Gets Imported

| Shopify Field | Hafaloha Field | Notes |
|---------------|----------------|-------|
| Handle | `products.slug` | URL-friendly |
| Title | `products.name` | Product name |
| Body (HTML) | `products.description` | Full description |
| Vendor | `products.vendor` | Brand name |
| Type | `products.product_type` | Category |
| Tags | `collections` | Creates collections |
| Variant SKU | `product_variants.sku` | Unique ID |
| Variant Price | `product_variants.price_cents` | × 100 |
| Variant Grams | `product_variants.weight_oz` | ÷ 28.35 |
| Option1 Value | `product_variants.size` | e.g., "M" |
| Option2 Value | `product_variants.color` | e.g., "Red" |
| Image Src | S3 via Active Storage | Downloaded |

---

## Expected CSV Format

Shopify's standard export format:

```csv
Handle,Title,Body (HTML),Vendor,Type,Tags,Published,Option1 Name,Option1 Value,Option2 Name,Option2 Value,Variant SKU,Variant Grams,Variant Price,Image Src,Image Position
```

**Example Row:**
```csv
tshirt-guam,"Guam T-Shirt","<p>Classic tee</p>",Håfaloha,Apparel,"Adult,Bestsellers",TRUE,Size,M,Color,Blue,TSHIRT-M-BLUE,180,29.99,https://cdn.shopify.com/image.jpg,1
```

**Multi-Variant Products:**
- First row = product + first variant
- Subsequent rows = additional variants

```csv
tshirt-guam,"Guam T-Shirt",...,Size,M,Color,Blue,TSHIRT-M-BLUE,...
tshirt-guam,,,,,,,Size,L,Color,Blue,TSHIRT-L-BLUE,...
tshirt-guam,,,,,,,Size,M,Color,Red,TSHIRT-M-RED,...
```

---

## Import Logic

### **1. Product Creation**

```ruby
Product.create!(
  name: "Guam T-Shirt",
  slug: "tshirt-guam",
  description: "<p>Classic tee</p>",
  base_price_cents: 2999,  # $29.99 × 100
  weight_oz: 6.35,         # 180g ÷ 28.35
  product_type: "Apparel",
  vendor: "Håfaloha",
  published: true,
  inventory_level: 'none'  # Default: no tracking
)
```

### **2. Variant Creation**

```ruby
product.product_variants.create!(
  size: "M",
  color: "Blue",
  sku: "TSHIRT-M-BLUE",
  price_cents: 2999,
  stock_quantity: 0,  # Default: 0 (inventory_level = 'none')
  available: true
)
```

### **3. Image Download & Upload**

```ruby
# Download from Shopify CDN
image_data = URI.open("https://cdn.shopify.com/image.jpg").read

# Upload to S3
blob = ActiveStorage::Blob.create_and_upload!(
  io: StringIO.new(image_data),
  filename: "tshirt-guam/#{SecureRandom.uuid}.jpg"
)

# Save reference
product.product_images.create!(
  s3_key: blob.key,
  position: 1,
  primary: true
)
```

### **4. Collection Creation**

```ruby
tags = "Adult,Bestsellers".split(',')

tags.each do |tag_name|
  collection = Collection.find_or_create_by!(
    name: tag_name,
    slug: tag_name.parameterize
  )
  product.collections << collection
end
```

---

## Duplicate Handling

### **Products**
- Checks by `slug`
- **If exists (active):** Skips
- **If exists (archived):** Unarchives + updates
- **If new:** Creates

### **Variants**
- Checks by `sku`
- **If exists:** Skips
- **If new:** Creates

### **Images**
- Always downloads (no duplicate check)
- Uses `position` for sorting

---

## Image Filtering

**Automatically skipped:**
- Filename contains "logo" or "placeholder"
- Alt text contains "logo" or "placeholder"
- Known logos (e.g., "ChristmasPua.png")

**Example:**
```ruby
# SKIPPED:
"https://cdn.shopify.com/logo.png"
"https://cdn.shopify.com/placeholder.jpg"

# IMPORTED:
"https://cdn.shopify.com/product-front.jpg"
```

---

## Post-Import

### **1. Verify Data**

```bash
bin/rails runner "
  puts 'Products: ' + Product.count.to_s
  puts 'Variants: ' + ProductVariant.count.to_s
  puts 'Images: ' + ProductImage.count.to_s
  puts 'Collections: ' + Collection.count.to_s
"
```

### **2. Check Admin Dashboard**

1. Go to `/admin/import`
2. View import history
3. Check for warnings/errors
4. Review `/admin/products` to see imported products

### **3. Enable Inventory Tracking (Optional)**

By default, all products have `inventory_level: 'none'` (unlimited stock).

To enable:
1. Go to `/admin/products`
2. Edit product
3. Scroll to "Inventory Tracking"
4. Select "Variant-Level Tracking" or "Product-Level Tracking"
5. Save

---

## Troubleshooting

### **Images not downloading**

**Error:** `404 Not Found`

**Fix:** Shopify CDN URLs may have expired. Get a fresh export.

---

### **SSL certificate error**

**Error:** `certificate verify failed`

**Fix:** macOS + Ruby issue. Already handled in codebase.

---

### **Duplicate SKU errors**

**Error:** `Sku has already been taken`

**Fix:** Clean up duplicate SKUs in Shopify before exporting.

---

### **Out of memory**

**Error:** `NoMemoryError`

**Fix:** Import in batches:
```bash
# Split CSV
split -l 50 products_export.csv batch_

# Import each
bin/rails import:shopify[batch_aa]
bin/rails import:shopify[batch_ab]
```

---

## Command Line Options

### **Basic Import**
```bash
bin/rails import:shopify[scripts/products_export.csv]
```

### **Custom Output File**
```bash
bin/rails import:shopify[path/to/export.csv,custom_output.json]
```

### **Force Overwrite**
```bash
FORCE=true bin/rails import:shopify[products_export.csv]
```

### **Skip Images (Faster Testing)**
```bash
SKIP_IMAGES=true bin/rails import:shopify[products_export.csv]
```

---

## Best Practices

1. **Test with small CSV first** (10 products)
2. **Backup database before importing**
   ```bash
   pg_dump hafaloha_api_development > backup.sql
   ```
3. **Verify image URLs are not expired**
4. **Review collections after import** (may need merging)
5. **Set inventory levels post-import** (default is 'none')

---

## Example Output

```
Processing: Guam T-Shirt (tshirt-guam)
  ✓ Product created: Guam T-Shirt
  ✓ Variant created: M / Blue (SKU: TSHIRT-M-BLUE) - $29.99
  ✓ Variant created: L / Blue (SKU: TSHIRT-L-BLUE) - $29.99
  ✓ Image downloaded: https://cdn.shopify.com/...
  ✓ Collection added: Adult
  ✓ Collection added: Bestsellers

========================================
✅ IMPORT COMPLETE
========================================

Summary:
  • Products: 45 created, 5 skipped
  • Variants: 382 created
  • Images: 127 downloaded
  • Collections: 59 created
```

---

**Need help?** Ask Leon (shimizutechnology@gmail.com)

