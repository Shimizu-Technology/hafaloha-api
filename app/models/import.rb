class Import < ApplicationRecord
  belongs_to :user
  
  # Status: pending, processing, completed, failed
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :in_progress, -> { where(status: %w[pending processing]) }
  
  def processing!
    update!(status: 'processing', started_at: Time.current)
  end
  
  def complete!(stats)
    # Prepend created products to warnings for visibility
    warnings_array = stats[:warnings] || []
    if stats[:created_products]&.any?
      created_list = stats[:created_products].map { |name| "✅ Created: #{name}" }
      warnings_array = created_list + [''] + warnings_array # Add blank line separator
    end
    
    update!(
      status: 'completed',
      completed_at: Time.current,
      products_count: stats[:products_created],
      variants_count: stats[:variants_created],
      images_count: stats[:images_created],
      collections_count: stats[:collections_created],
      skipped_count: stats[:products_skipped],
      warnings: warnings_array.join("\n")
    )
  end
  
  def fail!(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_messages: error_message
    )
  end
  
  def duration
    return nil unless started_at && completed_at
    (completed_at - started_at).round(2)
  end
  
  def in_progress?
    %w[pending processing].include?(status)
  end
  
  def success?
    status == 'completed'
  end
end
