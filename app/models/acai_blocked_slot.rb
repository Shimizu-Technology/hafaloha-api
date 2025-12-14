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
    where(blocked_date: date)
      .where('start_time <= ? AND end_time >= ?', time, time)
      .exists?
  end

  # Instance methods
  def time_range
    "#{start_time.strftime('%I:%M %p')} - #{end_time.strftime('%I:%M %p')}"
  end

  def display_name
    "#{blocked_date.strftime('%B %d, %Y')}: #{time_range}#{reason.present? ? " (#{reason})" : ''}"
  end

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    
    if end_time <= start_time
      errors.add(:end_time, 'must be after start time')
    end
  end
end
