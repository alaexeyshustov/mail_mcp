require 'fast_mcp'
require_relative '../gmail_service'

module Tools
  class AddLabels < FastMcp::Tool
    tool_name 'add_labels'
    description 'Add one or more labels (tags) to a specific email by message ID. ' \
                'Use get_labels to find valid label IDs first.'

    arguments do
      required(:message_id).filled(:string).description('The Gmail message ID (e.g. "18d3f1a2b3c4d5e6")')
      required(:label_ids).array(:string).description('Array of label IDs to add (e.g. ["STARRED", "Label_42"])')
    end

    def call(message_id:, label_ids:)
      self.class.gmail_service.modify_labels(message_id, add_label_ids: label_ids)
    end

    class << self
      attr_accessor :gmail_service
    end
  end
end
