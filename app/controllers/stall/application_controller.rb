module Stall
  class ApplicationController < Stall.config.application_controller_ancestor.constantize
    before_action :set_request_variant
    layout :set_stall_layout

    private

    def set_request_variant
      request.variant = :xhr if request.xhr?
    end

    # Enforce app-level layout by defaulting to the "application" layout if
    # no parent layout was set before, thus avoiding the "stall/application"
    # layout to be rendered
    def set_stall_layout
      return false if request.xhr?
      return Stall.config.default_layout if Stall.config.default_layout

      parent_controller = self.class.ancestors.find do |ancestor|
        !ancestor.name.to_s.match(/^Stall::/) && Class === ancestor
      end

      parent_controller._layout ||= 'application'
    end
  end
end
