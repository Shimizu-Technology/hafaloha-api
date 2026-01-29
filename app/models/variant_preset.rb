class VariantPreset < ApplicationRecord
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :option_type, presence: true
  validates :values, presence: true
  validate :values_must_be_array_of_hashes

  # Scopes
  scope :by_position, -> { order(:position, :name) }
  scope :for_option_type, ->(type) { where(option_type: type) }

  # Callbacks
  before_validation :set_default_position, on: :create

  # Instance methods
  
  # Returns values with indifferent access for easier hash key access
  def values_with_defaults
    return [] if values.blank?
    values.map { |v| v.with_indifferent_access }
  end

  # Returns just the value names as an array
  def value_names
    values_with_defaults.map { |v| v[:name] }
  end

  # Duplicate this preset with a new name
  def duplicate!(new_name = nil)
    new_preset = dup
    new_preset.name = new_name || "#{name} (Copy)"
    new_preset.position = self.class.maximum(:position).to_i + 1
    new_preset.save!
    new_preset
  end

  private

  def set_default_position
    return if position.present? && position > 0
    self.position = self.class.maximum(:position).to_i + 1
  end

  def values_must_be_array_of_hashes
    return if values.blank?
    
    unless values.is_a?(Array)
      errors.add(:values, "must be an array")
      return
    end

    values.each_with_index do |value, index|
      unless value.is_a?(Hash) || value.respond_to?(:permit)
        errors.add(:values, "item at index #{index} must be a hash")
        next
      end
      
      unless value["name"].present? || value[:name].present?
        errors.add(:values, "item at index #{index} must have a name")
      end
    end
  end
end
