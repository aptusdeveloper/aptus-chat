# frozen_string_literal: true

# rubocop:disable Style/ClassAndModuleChildren -- compact form breaks Zeitwerk autoloading for this single-file namespace
module CustomExceptions::Agenda
  class SlotUnavailable < CustomExceptions::Base
    def message
      'The requested time slot is no longer available.'
    end

    def http_status
      422
    end
  end
end
# rubocop:enable Style/ClassAndModuleChildren
