# frozen_string_literal: true

class AcaiSetting < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :base_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :advance_hours, numericality: { greater_than_or_equal_to: 0 }
  validates :max_per_slot, numericality: { greater_than: 0 }

  # Singleton pattern - only one row in the table
  def self.instance
    first_or_create!(
      name: 'Heart-Shaped Açaí Cake',
      description: "This limited-time fruit-astic beauty comes loaded with four delicious toppings:\n🍌 Banana • 🍓 Strawberry • 🫐 Blueberry • 🥭 Mango",
      base_price_cents: 4500,
      pickup_location: '955 Pale San Vitores Rd, Tumon, Blue Lagoon Plaza',
      pickup_phone: '671-989-3444',
      advance_hours: 24,
      max_per_slot: 5,
      active: true,
      placard_enabled: true,
      placard_price_cents: 0,
      toppings_info: 'Banana, Strawberry, Blueberry, Mango'
    )
  end

  # Price helpers
  def base_price
    Money.new(base_price_cents, 'USD')
  end

  def base_price=(amount)
    self.base_price_cents = (amount.to_f * 100).to_i
  end

  def formatted_price
    "$#{'%.2f' % (base_price_cents / 100.0)}"
  end

  def placard_price
    Money.new(placard_price_cents, 'USD')
  end

  # Check if ordering is currently enabled
  def ordering_enabled?
    active && AcaiPickupWindow.active.exists?
  end

  # Get minimum order date (based on advance_hours)
  def minimum_order_date
    (Time.current + advance_hours.hours).to_date
  end

  # Check if a specific slot is available
  def slot_available?(date, time_slot)
    return false unless active

    # Check if date is far enough in advance
    return false if date < minimum_order_date

    # Check if there's a pickup window for this day
    day_of_week = date.wday
    window = AcaiPickupWindow.active.find_by(day_of_week: day_of_week)
    return false unless window

    # Check if time slot falls within window
    slot_start = Time.parse(time_slot.split('-').first.strip)
    return false unless slot_in_window?(slot_start, window)

    # Check if slot is blocked
    return false if AcaiBlockedSlot.blocks_slot?(date, time_slot)

    # Check capacity
    current_orders = Order.acai
                          .where(acai_pickup_date: date)
                          .where(acai_pickup_time: time_slot)
                          .where.not(status: 'cancelled')
                          .count
    
    current_orders < max_per_slot
  end

  private

  def slot_in_window?(slot_time, window)
    window_start = Time.parse(window.start_time_hhmm)
    window_end = Time.parse(window.end_time_hhmm)
    slot_time >= window_start && slot_time < window_end
  end
end
