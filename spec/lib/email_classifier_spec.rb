require_relative '../spec_helper'
require_relative '../../lib/email_classifier'

RSpec.describe EmailClassifier do
  let(:api_key) { 'test-api-key' }

  subject(:classifier) { described_class.new(api_key: api_key) }

  before { allow(RubyLLM).to receive(:configure) }

  describe '#initialize' do
    it 'configures RubyLLM with the provided API key' do
      expect(RubyLLM).to receive(:configure)
      described_class.new(api_key: api_key)
    end
  end

  describe '#classify' do
    let(:emails) do
      [
        { id: 'msg_1', title: 'Your Amazon order has shipped' },
        { id: 'msg_2', title: 'Team standup notes - Feb 27' }
      ]
    end

    # -------------------------------------------------------------------------
    # VCR cassette — exercises the full Gemini HTTP round-trip
    # -------------------------------------------------------------------------
    context 'making live API requests (VCR cassette)' do
      # Allow the real RubyLLM.configure to run so the api_key is wired up;
      # VCR intercepts the outgoing HTTP before it ever leaves the process.
      before { allow(RubyLLM).to receive(:configure).and_call_original }
      it 'reshapes the Gemini response into an id → tags Hash' do
        VCR.use_cassette('email_classifier/classify') do
          result = classifier.classify(emails)
          expect(result).to eq(
            'msg_1' => ['shipping', 'receipt'],
            'msg_2' => ['work', 'meeting']
          )
        end
      end
    end

    # -------------------------------------------------------------------------
    # Mock-based tests — verify behavioral contracts and edge-case reshaping
    # without making real HTTP calls
    # -------------------------------------------------------------------------
    context 'behavioral and edge-case tests' do
      let(:mock_chat)     { double('chat') }
      let(:mock_response) { double('response') }
      let(:structured_content) do
        {
          'results' => [
            { 'id' => 'msg_1', 'tags' => ['shipping', 'receipt'] },
            { 'id' => 'msg_2', 'tags' => ['work', 'meeting'] }
          ]
        }
      end

      before do
        allow(RubyLLM).to receive(:chat).and_return(mock_chat)
        allow(mock_chat).to receive(:with_schema).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).and_return(mock_response)
        allow(mock_response).to receive(:content).and_return(structured_content)
      end

      it 'applies ClassificationSchema to enforce structured output' do
        expect(mock_chat).to receive(:with_schema).with(ClassificationSchema).and_return(mock_chat)
        classifier.classify(emails)
      end

      it 'sends the email list to the model' do
        expect(mock_chat).to receive(:ask).with(a_string_including('msg_1', 'msg_2')).and_return(mock_response)
        classifier.classify(emails)
      end

      context 'when emails have string keys (from MCP JSON parsing)' do
        let(:string_keyed_emails) do
          [{ 'id' => 'msg_1', 'title' => 'Your Amazon order has shipped' }]
        end
        let(:structured_content) do
          { 'results' => [{ 'id' => 'msg_1', 'tags' => ['shipping'] }] }
        end

        it 'handles string-keyed email hashes correctly' do
          result = classifier.classify(string_keyed_emails)
          expect(result).to eq('msg_1' => ['shipping'])
        end
      end

      context 'when the schema response has symbol keys' do
        let(:structured_content) do
          { results: [{ id: 'msg_1', tags: ['work'] }] }
        end

        it 'handles symbol-keyed results correctly' do
          result = classifier.classify(emails)
          expect(result).to eq('msg_1' => ['work'])
        end
      end
    end

    context 'when emails is empty' do
      it 'returns an empty Hash without calling the LLM' do
        expect(RubyLLM).not_to receive(:chat)
        expect(classifier.classify([])).to eq({})
      end
    end
  end
end
