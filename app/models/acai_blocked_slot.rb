class AcaiBlockedSlot < ApplicationRecord
  # Validations
  validates :blocked_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  # Scopes
  scope :for_date, ->(date) { where(blocked_date: date) }
  scope :upcoming, -> { where('blocked_date >= ?', Date.current) }
  scope :past, -> { where('blocked_date < ?', Date.current) }
  scope :recent, -> { order(blocked_date: :desc, start_time: :desc) }

  # Class methods
  def self.is_blocked?(date, time)
    # time is now a string like "13:30"
    time_str = time.to_s.split(':')[0..1].join(':')
    where(blocked_date: date)
      .where('start_time <= ? AND end_time >= ?', time_str, time_str)
      .exists?
  end

  # Check if a slot string (e.g., "01:30 PM - 02:00 PM") is blocked
  def self.blocks_slot?(date, slot_string)
    return false if slot_string.blank?
    
    # Parse the slot string to get start time in 24h format
    start_str = slot_string.split('-').first.strip
    begin
      # Parse 12h time format to 24h
      time = Time.parse(start_str)
      slot_time = time.strftime('%H:%M')
      is_blocked?(date, slot_time)
    rescue ArgumentError
      false
    end
  end

  # Block an entire day
  def self.block_day!(date, reason: nil)
    create!(
      blocked_date: date,
      start_time: '00:00',
      end_time: '23:59',
      reason: reason || 'Full day blocked'
    )
  end

  # Instance methods
  def time_range
    "#{format_time_12h(start_time)} - #{format_time_12h(end_time)}"
  end

  def display_name
    "#{blocked_date.strftime('%B %d, %Y')}: #{time_range}#{reason.present? ? " (#{reason})" : ''}"
  end
  
  # Get start time as "HH:MM" string
  def start_time_hhmm
    start_time.to_s.split(':')[0..1].join(':')
  end

  # Get end time as "HH:MM" string
  def end_time_hhmm
    end_time.to_s.split(':')[0..1].join(':')
  end

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    
    start_minutes = parse_time_to_minutes(start_time)
    end_minutes = parse_time_to_minutes(end_time)
    
    if end_minutes <= start_minutes
      errors.add(:end_time, 'must be after start time')
    end
  end
  
  def parse_time_to_minutes(time_str)
    parts = time_str.to_s.split(':')
    parts[0].to_i * 60 + parts[1].to_i
  end
  
  def format_time_12h(time_str)
    parts = time_str.to_s.split(':')
    hour = parts[0].to_i
    min = parts[1].to_i
    period = hour >= 12 ? 'PM' : 'AM'
    hour_12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
    format('%d:%02d %s', hour_12, min, period)
  end
end
