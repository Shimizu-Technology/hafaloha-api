# frozen_string_literal: true

class SendContactNotificationJob < ApplicationJob
  queue_as :default

  def perform(contact_submission_id)
    submission = ContactSubmission.find(contact_submission_id)
    result = EmailService.send_contact_notification(submission)

    if result[:success]
      Rails.logger.info "✅ Contact notification email sent for submission ##{submission.id}"
    else
      Rails.logger.error "❌ Failed to send contact notification for submission ##{submission.id}: #{result[:error]}"
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "❌ ContactSubmission ##{contact_submission_id} not found - cannot send notification"
  rescue StandardError => e
    Rails.logger.error "❌ Error sending contact notification: #{e.class} - #{e.message}"
    raise # Re-raise to allow job retry
  end
end
