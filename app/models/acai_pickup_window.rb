class AcaiPickupWindow < ApplicationRecord
  # Validations
  validates :day_of_week, presence: true, inclusion: { in: 0..6 } # 0 = Sunday, 6 = Saturday
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :capacity, numericality: { greater_than: 0 }, allow_nil: true
  validate :end_time_after_start_time

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_day, ->(day) { where(day_of_week: day) }
  scope :by_day, -> { order(:day_of_week, :start_time) }

  # Constants
  DAYS = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze

  # Instance methods
  def day_name
    DAYS[day_of_week]
  end

  def time_range
    "#{format_time_12h(start_time)} - #{format_time_12h(end_time)}"
  end

  def display_name
    "#{day_name}: #{time_range}"
  end

  # Check if a specific datetime falls within this window
  def includes_time?(datetime)
    return false unless datetime.wday == day_of_week

    time = datetime.strftime("%H:%M")
    time >= start_time_hhmm && time <= end_time_hhmm
  end

  # Get start time as "HH:MM" string
  def start_time_hhmm
    start_time.to_s.split(":")[0..1].join(":")
  end

  # Get end time as "HH:MM" string
  def end_time_hhmm
    end_time.to_s.split(":")[0..1].join(":")
  end

  # Get available slots for a specific date
  def available_slots_for_date(date, interval_minutes: 30)
    return [] unless active? && date.wday == day_of_week

    slots = []

    # Parse times from string format
    start_parts = start_time.to_s.split(":")
    end_parts = end_time.to_s.split(":")

    current_minutes = start_parts[0].to_i * 60 + start_parts[1].to_i
    end_minutes = end_parts[0].to_i * 60 + end_parts[1].to_i

    while current_minutes < end_minutes
      slot_hour = current_minutes / 60
      slot_min = current_minutes % 60
      slot_time_str = format("%02d:%02d", slot_hour, slot_min)

      slot_datetime = Time.zone.local(date.year, date.month, date.day, slot_hour, slot_min)

      # Check if slot is blocked
      is_blocked = AcaiBlockedSlot.where(
        blocked_date: date
      ).where("start_time LIKE ?", "#{slot_time_str}%").exists?

      # Check capacity if set
      orders_count = Order.acai.where(
        acai_pickup_date: date
      ).where("acai_pickup_time LIKE ?", "#{slot_time_str}%").count

      is_available = !is_blocked && (capacity.nil? || orders_count < capacity)

      slots << {
        time: slot_time_str,
        datetime: slot_datetime,
        available: is_available,
        orders_count: orders_count
      }

      current_minutes += interval_minutes
    end

    slots
  end

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    start_minutes = parse_time_to_minutes(start_time)
    end_minutes = parse_time_to_minutes(end_time)

    if end_minutes <= start_minutes
      errors.add(:end_time, "must be after start time")
    end
  end

  def parse_time_to_minutes(time_str)
    parts = time_str.to_s.split(":")
    parts[0].to_i * 60 + parts[1].to_i
  end

  def format_time_12h(time_str)
    parts = time_str.to_s.split(":")
    hour = parts[0].to_i
    min = parts[1].to_i
    period = hour >= 12 ? "PM" : "AM"
    hour_12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
    format("%d:%02d %s", hour_12, min, period)
  end
end
