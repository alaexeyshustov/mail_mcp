require_relative '../../spec_helper'
require_relative '../../../lib/email_classifier'
require_relative '../../../lib/tools/classify_emails'

RSpec.describe Tools::ClassifyEmails do
  let(:classifier) { instance_double(EmailClassifier) }

  before { described_class.classifier = classifier }

  describe '#call' do
    let(:emails) do
      [
        { 'id' => 'msg_1', 'title' => 'Your Amazon order has shipped' },
        { 'id' => 'msg_2', 'title' => 'Team standup notes' }
      ]
    end

    let(:classification_result) do
      {
        'msg_1' => ['shipping', 'receipt'],
        'msg_2' => ['work', 'meeting']
      }
    end

    it 'delegates to the classifier with the emails argument' do
      expect(classifier).to receive(:classify).with(emails).and_return(classification_result)
      tool = described_class.new
      tool.call(emails: emails)
    end

    it 'returns the classifier result' do
      allow(classifier).to receive(:classify).with(emails).and_return(classification_result)
      tool = described_class.new
      result = tool.call(emails: emails)
      expect(result).to eq(classification_result)
    end

    context 'when the classifier returns an empty hash' do
      it 'returns an empty hash' do
        allow(classifier).to receive(:classify).and_return({})
        tool = described_class.new
        expect(tool.call(emails: [])).to eq({})
      end
    end
  end

  describe '.tool_name' do
    it 'is "classify_emails"' do
      expect(described_class.tool_name).to eq('classify_emails')
    end
  end
end
