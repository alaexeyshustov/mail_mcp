require_relative '../../spec_helper'
require_relative '../../../lib/gmail_service'
require_relative '../../../lib/tools/add_labels'

RSpec.describe Tools::AddLabels do
  let(:gmail) { instance_double(GmailService) }

  before { described_class.gmail_service = gmail }

  describe '#call' do
    context 'when adding a single label' do
      it 'calls modify_labels with the label and returns the result' do
        expected = { id: 'msg_123', labels: ['INBOX', 'STARRED'] }
        expect(gmail).to receive(:modify_labels)
          .with('msg_123', add_label_ids: ['STARRED'])
          .and_return(expected)

        tool = described_class.new
        result = tool.call(message_id: 'msg_123', label_ids: ['STARRED'])
        expect(result).to eq(expected)
      end
    end

    context 'when adding multiple labels' do
      it 'passes the full array to modify_labels' do
        expected = { id: 'msg_123', labels: ['INBOX', 'STARRED', 'Label_42'] }
        expect(gmail).to receive(:modify_labels)
          .with('msg_123', add_label_ids: ['STARRED', 'Label_42'])
          .and_return(expected)

        tool = described_class.new
        result = tool.call(message_id: 'msg_123', label_ids: ['STARRED', 'Label_42'])
        expect(result).to eq(expected)
      end
    end

    context 'when the Gmail API raises an error' do
      it 'propagates the error' do
        allow(gmail).to receive(:modify_labels).and_raise(Google::Apis::Error.new('Not found'))

        tool = described_class.new
        expect { tool.call(message_id: 'bad_id', label_ids: ['STARRED']) }
          .to raise_error(Google::Apis::Error)
      end
    end
  end

  describe '.tool_name' do
    it 'is "add_labels"' do
      expect(described_class.tool_name).to eq('add_labels')
    end
  end
end
