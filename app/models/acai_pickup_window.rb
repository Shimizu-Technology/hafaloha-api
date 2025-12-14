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
    "#{start_time.strftime('%I:%M %p')} - #{end_time.strftime('%I:%M %p')}"
  end

  def display_name
    "#{day_name}: #{time_range}"
  end

  # Check if a specific datetime falls within this window
  def includes_time?(datetime)
    return false unless datetime.wday == day_of_week
    
    time = datetime.strftime('%H:%M:%S')
    time >= start_time.strftime('%H:%M:%S') && time <= end_time.strftime('%H:%M:%S')
  end

  # Get available slots for a specific date
  def available_slots_for_date(date, interval_minutes: 30)
    return [] unless active? && date.wday == day_of_week
    
    slots = []
    current_time = start_time
    
    while current_time < end_time
      slot_datetime = Time.zone.local(date.year, date.month, date.day, current_time.hour, current_time.min)
      
      # Check if slot is blocked
      is_blocked = AcaiBlockedSlot.where(
        blocked_date: date,
        start_time: current_time
      ).exists?
      
      # Check capacity if set
      orders_count = Order.acai.where(
        acai_pickup_date: date,
        acai_pickup_time: current_time
      ).count
      
      is_available = !is_blocked && (capacity.nil? || orders_count < capacity)
      
      slots << {
        time: current_time,
        datetime: slot_datetime,
        available: is_available,
        orders_count: orders_count
      }
      
      current_time += interval_minutes.minutes
    end
    
    slots
  end

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    
    if end_time <= start_time
      errors.add(:end_time, 'must be after start time')
    end
  end
end
