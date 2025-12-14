# frozen_string_literal: true

module Api
  module V1
    module Admin
      class HomepageSectionsController < ApplicationController
        before_action :authenticate_user!
        before_action :require_admin!
        before_action :set_section, only: %i[show update destroy]

        def index
          sections = HomepageSection.ordered

          render json: {
            sections: sections.map { |s| section_json(s) },
            section_types: HomepageSection::SECTION_TYPES
          }
        end

        def show
          render json: { section: section_json(@section) }
        end

        def create
          section = HomepageSection.new(section_params)

          if section.save
            render json: { section: section_json(section) }, status: :created
          else
            render json: { errors: section.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @section.update(section_params)
            render json: { section: section_json(@section) }
          else
            render json: { errors: @section.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @section.destroy
          head :no_content
        end

        # Bulk update positions
        def reorder
          params[:sections].each do |section_data|
            section = HomepageSection.find(section_data[:id])
            section.update(position: section_data[:position])
          end

          render json: { success: true }
        end

        private

        def set_section
          @section = HomepageSection.find(params[:id])
        end

        def section_params
          params.require(:section).permit(
            :section_type,
            :position,
            :active,
            :title,
            :subtitle,
            :button_text,
            :button_link,
            :image_url,
            :background_image_url,
            settings: {}
          )
        end

        def section_json(section)
          {
            id: section.id,
            section_type: section.section_type,
            position: section.position,
            title: section.title,
            subtitle: section.subtitle,
            button_text: section.button_text,
            button_link: section.button_link,
            image_url: section.image_url,
            background_image_url: section.background_image_url,
            settings: section.settings,
            active: section.active,
            created_at: section.created_at,
            updated_at: section.updated_at
          }
        end
      end
    end
  end
end

