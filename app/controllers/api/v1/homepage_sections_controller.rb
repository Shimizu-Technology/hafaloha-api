# frozen_string_literal: true

module Api
  module V1
    class HomepageSectionsController < ApplicationController
      # Public endpoint - no auth required
      def index
        sections = HomepageSection.active.ordered

        render json: {
          sections: sections.map { |s| section_json(s) },
          grouped: sections.group_by(&:section_type).transform_values { |v| v.map { |s| section_json(s) } }
        }
      end

      private

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
          active: section.active
        }
      end
    end
  end
end
