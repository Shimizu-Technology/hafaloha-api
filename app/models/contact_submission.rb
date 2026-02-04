# frozen_string_literal: true

class ContactSubmission < ApplicationRecord
  # Validations
  validates :name, presence: true, length: { maximum: 200 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true, length: { maximum: 200 }
  validates :message, presence: true, length: { maximum: 5000 }
  validates :status, presence: true, inclusion: { in: %w[new read replied archived] }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :unread, -> { where(status: "new") }
end
