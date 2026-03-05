require 'fast_mcp'
require_relative '../gmail_service'

module Tools
  class ListEmails < FastMcp::Tool
    tool_name 'list_emails'
    description 'List recent emails from Gmail inbox'

    arguments do
      optional(:max_results).filled(:integer).description('Number of emails to return (1-100). Defaults to 10.')
      optional(:query).filled(:string).description("Gmail search query (e.g. 'is:unread', 'from:john@example.com')")
      optional(:after_date).filled(:string).description('Return emails after this date (YYYY-MM-DD format).')
      optional(:before_date).filled(:string).description('Return emails before this date (YYYY-MM-DD format).')
      optional(:offset).filled(:integer).description('Number of emails to skip (for pagination). Defaults to 0.')
      optional(:label).filled(:string).description('Filter by label ID or name (e.g. "INBOX", "UNREAD", "Label_123").')
    end

    def call(max_results: 10, query: nil, after_date: nil, before_date: nil, offset: 0, label: nil)
      parsed_after  = after_date  ? Date.parse(after_date)  : nil
      parsed_before = before_date ? Date.parse(before_date) : nil
      self.class.gmail_service.list_messages(
        max_results: max_results,
        query: query,
        after_date: parsed_after,
        before_date: parsed_before,
        offset: offset,
        label_ids: label ? [label] : nil
      )
    end

    class << self
      attr_accessor :gmail_service
    end
  end
end

