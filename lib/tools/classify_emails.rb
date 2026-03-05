require 'fast_mcp'
require_relative '../email_classifier'

module Tools
  class ClassifyEmails < FastMcp::Tool
    tool_name 'classify_emails'
    description 'Classify a list of emails by their subject lines and return suggested tags. ' \
                'Accepts an array of {id, title} objects and returns a mapping of id to tags array. ' \
                'Uses Gemini AI for classification.'

    arguments do
      required(:emails).array(:hash).description(
        'Array of email objects, each with "id" (Gmail message ID) and "title" (subject line). ' \
        'Example: [{"id": "abc123", "title": "Your order has shipped"}]'
      )
    end

    def call(emails:)
      self.class.classifier.classify(emails)
    end

    class << self
      attr_accessor :classifier
    end
  end
end
