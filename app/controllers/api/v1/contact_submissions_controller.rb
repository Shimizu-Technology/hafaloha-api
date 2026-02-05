# frozen_string_literal: true

module Api
  module V1
    class ContactSubmissionsController < ApplicationController
      # No authentication required — this is a public contact form.

      # POST /api/v1/contact
      def create
        # Honeypot: bots fill hidden fields, humans leave them blank
        if params.dig(:contact, :company_name).present?
          render json: {
            success: true,
            message: "Thank you for reaching out! We'll get back to you soon."
          }, status: :created
          return
        end

        submission = ContactSubmission.new(contact_params)

        if submission.save
          # Send notification email to admin via background job
          SendContactNotificationJob.perform_later(submission.id)

          render json: {
            success: true,
            message: "Thank you for reaching out! We'll get back to you soon."
          }, status: :created
        else
          render json: {
            success: false,
            errors: submission.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def contact_params
        params.require(:contact).permit(:name, :email, :subject, :message)
      end
    end
  end
end
