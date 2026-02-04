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

  def update_progress(processed:, total:, step: nil)
    percent = total.to_i.positive? ? ((processed.to_f / total) * 100).round : 0
    update!(
      processed_products: processed,
      total_products: total,
      progress_percent: percent,
      current_step: step,
      last_progress_at: Time.current
    )
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
      variants_skipped_count: stats[:variants_skipped] || 0,
      images_count: stats[:images_created],
      collections_count: stats[:collections_created],
      skipped_count: stats[:products_skipped],
      warnings: warnings_array.join("\n"),
      processed_products: total_products.to_i.positive? ? total_products : (stats[:products_created].to_i + stats[:products_skipped].to_i),
      progress_percent: 100,
      current_step: 'Completed'
    )
  end
  
  def fail!(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_messages: error_message,
      current_step: 'Failed'
    )
  end

  def stale_processing?(timeout_minutes = 30)
    return false unless status == 'processing'
    return false unless started_at

    last_progress = last_progress_at || started_at
    last_progress < timeout_minutes.minutes.ago
  end

  def mark_stale_processing!(timeout_minutes = 30)
    return false unless stale_processing?(timeout_minutes)

    fail!('Import stopped before completion. Please re-run the import.')
    true
  end
  
  def duration
    return nil unless started_at && completed_at
    (completed_at - started_at).round(2)
  end

  def eta_seconds
    return nil unless started_at && processed_products.to_i.positive? && total_products.to_i.positive?
    elapsed = Time.current - started_at
    rate = processed_products.to_f / elapsed
    return nil if rate <= 0
    remaining = total_products - processed_products
    return 0 if remaining <= 0
    (remaining / rate).round
  end
  
  def in_progress?
    %w[pending processing].include?(status)
  end
  
  def success?
    status == 'completed'
  end
end
