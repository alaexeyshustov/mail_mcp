require_relative '../../spec_helper'
require_relative '../../../lib/gmail_service'
require_relative '../../../lib/tools/list_emails'

RSpec.describe Tools::ListEmails do
  let(:gmail) { instance_double(GmailService) }
  let(:sample_email) do
    {
      id: 'msg_1',
      thread_id: 'thread_1',
      subject: 'Hello',
      from: 'sender@example.com',
      to: 'me@example.com',
      date: 'Mon, 20 Feb 2026 10:00:00 +0000',
      snippet: 'Hello snippet',
      body: 'Hello body',
      labels: ['INBOX']
    }
  end

  before { described_class.gmail_service = gmail }

  describe '#call' do
    context 'with default arguments' do
      it 'calls list_messages with max_results: 10 and query: nil' do
        expect(gmail).to receive(:list_messages)
          .with(max_results: 10, query: nil, after_date: nil, before_date: nil, offset: 0, label_ids: nil)
          .and_return([sample_email])
        tool = described_class.new
        result = tool.call
        expect(result).to eq([sample_email])
      end
    end

    context 'with custom max_results' do
      it 'passes max_results to list_messages' do
        expect(gmail).to receive(:list_messages)
          .with(max_results: 5, query: nil, after_date: nil, before_date: nil, offset: 0, label_ids: nil)
          .and_return([])
        tool = described_class.new
        result = tool.call(max_results: 5)
        expect(result).to eq([])
      end
    end

    context 'with a query' do
      it 'passes the query to list_messages' do
        expect(gmail).to receive(:list_messages)
          .with(max_results: 10, query: 'is:unread', after_date: nil, before_date: nil, offset: 0, label_ids: nil)
          .and_return([sample_email])
        tool = described_class.new
        result = tool.call(query: 'is:unread')
        expect(result).to eq([sample_email])
      end
    end

    context 'with both max_results and query' do
      it 'passes both arguments to list_messages' do
        expect(gmail).to receive(:list_messages)
          .with(max_results: 20, query: 'from:boss@example.com', after_date: nil, before_date: nil, offset: 0, label_ids: nil)
          .and_return([])
        tool = described_class.new
        result = tool.call(max_results: 20, query: 'from:boss@example.com')
        expect(result).to eq([])
      end
    end

    context 'with a label' do
      it 'passes label_ids to list_messages' do
        expect(gmail).to receive(:list_messages)
          .with(max_results: 10, query: nil, after_date: nil, before_date: nil, offset: 0, label_ids: ['INBOX'])
          .and_return([sample_email])
        tool = described_class.new
        result = tool.call(label: 'INBOX')
        expect(result).to eq([sample_email])
      end
    end

    context 'when Gmail API raises an error' do
      it 'propagates the error' do
        allow(gmail).to receive(:list_messages).and_raise(Google::Apis::Error.new('API error'))
        tool = described_class.new
        expect { tool.call }.to raise_error(Google::Apis::Error)
      end
    end
  end

  describe '.tool_name' do
    it 'is "list_emails"' do
      expect(described_class.tool_name).to eq('list_emails')
    end
  end

  describe '.description' do
    it 'is set' do
      expect(described_class.description).not_to be_nil
      expect(described_class.description).not_to be_empty
    end
  end
end

