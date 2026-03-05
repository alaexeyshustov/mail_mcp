require_relative  '../spec_helper'
require_relative '../../lib/gmail_service'

RSpec.describe GmailService do
  let(:credentials_path) { '/fake/credentials.json' }
  let(:token_path)        { '/fake/token.yaml' }
  let(:mock_credentials)  { double('credentials') }

  # Credentials double used by VCR-based tests.
  # Stubs only #authorize so the real Google client runs and VCR intercepts HTTP.
  # A concrete class (not an RSpec double) is required because google-apis-core
  # calls apply!(headers) during Faraday request building, and RSpec null-object
  # doubles trigger Faraday's to_ary path which crashes on nil.join.
  let(:fake_credentials) do
    Class.new do
      def universe_domain; 'googleapis.com'; end
      def apply!(headers); end  # no-op — VCR stubs all HTTP
      def apply(headers); end
      def principal; nil; end
    end.new
  end

  subject(:client) do
    allow_any_instance_of(described_class).to receive(:authorize).and_return(fake_credentials)
    described_class.new(credentials_path: credentials_path, token_path: token_path)
  end

  describe '#initialize' do
    it 'exposes a GmailService instance via #service' do
      expect(client.service).to be_a(Google::Apis::GmailV1::GmailService)
    end

    it 'sets the authorization returned by #authorize on the service' do
      allow_any_instance_of(described_class).to receive(:authorize).and_return(fake_credentials)
      svc = described_class.new(credentials_path: credentials_path, token_path: token_path)
      expect(svc.service.authorization).to eq(fake_credentials)
    end
  end

  describe '#authorize' do
    it 'delegates to GmailAuth with the correct arguments' do
      mock_auth = instance_double(GmailAuth, credentials: mock_credentials)
      expect(GmailAuth).to receive(:new)
        .with(credentials_path: credentials_path, token_path: token_path, scope: GmailService::SCOPE)
        .and_return(mock_auth)

      raw_client = described_class.allocate
      raw_client.instance_variable_set(:@credentials_path, credentials_path)
      raw_client.instance_variable_set(:@token_path, token_path)

      expect(raw_client.authorize).to eq(mock_credentials)
    end
  end

  describe '#list_messages' do
    it 'returns an array of message hashes' do
      VCR.use_cassette('gmail_service/list_messages_default') do
        results = client.list_messages
        expect(results.size).to eq(2)
      end
    end

    it 'maps messages to the expected hash structure' do
      VCR.use_cassette('gmail_service/list_messages_default') do
        results = client.list_messages
        expect(results.first).to include(:id, :thread_id, :subject, :from, :to, :date, :snippet, :body, :labels)
      end
    end

    it 'uses default max_results of 100 and returns all messages' do
      VCR.use_cassette('gmail_service/list_messages_default') do
        results = client.list_messages
        expect(results.size).to eq(2)
      end
    end

    it 'accepts custom max_results and a query filter' do
      VCR.use_cassette('gmail_service/list_messages_empty') do
        results = client.list_messages(max_results: 5, query: 'is:unread')
        expect(results).to eq([])
      end
    end

    context 'when the API returns no messages' do
      it 'returns an empty array' do
        VCR.use_cassette('gmail_service/list_messages_empty') do
          expect(client.list_messages).to eq([])
        end
      end
    end
  end

  describe '#get_message' do
    it 'returns a hash with the expected keys' do
      VCR.use_cassette('gmail_service/get_message') do
        result = client.get_message('msg_123')
        expect(result.keys).to contain_exactly(:id, :thread_id, :subject, :from, :to, :date, :snippet, :body, :labels)
      end
    end

    it 'extracts the subject correctly' do
      VCR.use_cassette('gmail_service/get_message') do
        result = client.get_message('msg_123')
        expect(result[:subject]).to eq('Test Subject')
      end
    end

    it 'extracts from, to, and date from headers' do
      VCR.use_cassette('gmail_service/get_message') do
        result = client.get_message('msg_123')
        expect(result[:from]).to eq('sender@example.com')
        expect(result[:to]).to eq('recipient@example.com')
        expect(result[:date]).to eq('Mon, 20 Feb 2026 10:00:00 +0000')
      end
    end

    it 'includes the snippet' do
      VCR.use_cassette('gmail_service/get_message') do
        result = client.get_message('msg_123')
        expect(result[:snippet]).to eq('Test Subject - snippet')
      end
    end

    it 'decodes the body' do
      VCR.use_cassette('gmail_service/get_message') do
        result = client.get_message('msg_123')
        expect(result[:body]).to eq('Hello world')
      end
    end

    it 'includes the label ids' do
      VCR.use_cassette('gmail_service/get_message') do
        result = client.get_message('msg_123')
        expect(result[:labels]).to eq(['INBOX'])
      end
    end

    context 'when headers are missing' do
      it 'falls back to default values for missing headers' do
        VCR.use_cassette('gmail_service/get_message_no_headers') do
          result = client.get_message('msg_empty')
          expect(result[:subject]).to eq('(No Subject)')
          expect(result[:from]).to eq('Unknown')
          expect(result[:to]).to eq('Unknown')
          expect(result[:date]).to eq('Unknown')
        end
      end
    end

    context 'with a multipart message' do
      it 'joins parts with double newlines' do
        VCR.use_cassette('gmail_service/get_message_multipart') do
          result = client.get_message('msg_multi')
          expect(result[:body]).to eq("Part 1\n\nPart 2")
        end
      end
    end
  end

  describe '#search_messages' do
    it 'delegates to list_messages with the given query' do
      expect(client).to receive(:list_messages).with(max_results: 10, query: 'subject:invoice')
      client.search_messages('subject:invoice')
    end

    it 'accepts a custom max_results' do
      expect(client).to receive(:list_messages).with(max_results: 20, query: 'from:boss@example.com')
      client.search_messages('from:boss@example.com', max_results: 20)
    end
  end

  describe '#get_labels' do
    it 'returns an array of label hashes' do
      VCR.use_cassette('gmail_service/get_labels') do
        result = client.get_labels
        expect(result.size).to eq(2)
      end
    end

    it 'maps labels to hashes with id, name, and type' do
      VCR.use_cassette('gmail_service/get_labels') do
        result = client.get_labels
        expect(result.first).to eq({ id: 'INBOX', name: 'INBOX', type: 'system' })
        expect(result.last).to eq({ id: 'Label_1', name: 'Work', type: 'user' })
      end
    end
  end

  describe '#get_unread_count' do
    it 'returns the total number of unread messages' do
      VCR.use_cassette('gmail_service/get_unread_count') do
        expect(client.get_unread_count).to eq(42)
      end
    end

    context 'when messagesTotal is absent from the API response' do
      it 'returns 0' do
        VCR.use_cassette('gmail_service/get_unread_count_nil') do
          expect(client.get_unread_count).to eq(0)
        end
      end
    end
  end

  describe '#modify_labels' do
    it 'returns a hash with id and updated labels after adding' do
      VCR.use_cassette('gmail_service/modify_labels_add') do
        result = client.modify_labels('msg_123', add_label_ids: ['STARRED'])
        expect(result).to eq({ id: 'msg_123', labels: ['INBOX', 'STARRED'] })
      end
    end

    it 'returns a hash with id and updated labels after removing' do
      VCR.use_cassette('gmail_service/modify_labels_remove') do
        result = client.modify_labels('msg_123', remove_label_ids: ['STARRED'])
        expect(result).to eq({ id: 'msg_123', labels: ['INBOX'] })
      end
    end

    it 'calls the modify endpoint for the correct message id' do
      VCR.use_cassette('gmail_service/modify_labels_add') do
        result = client.modify_labels('msg_123', add_label_ids: ['STARRED'])
        expect(result[:id]).to eq('msg_123')
      end
    end

    it 'returns an empty labels array when the API omits labelIds' do
      VCR.use_cassette('gmail_service/modify_labels_nil_labels') do
        result = client.modify_labels('msg_123', add_label_ids: ['STARRED'])
        expect(result[:labels]).to eq([])
      end
    end

    it 'propagates API errors (4xx) as Google::Apis::Error' do
      VCR.use_cassette('gmail_service/modify_labels_error') do
        expect { client.modify_labels('msg_123', add_label_ids: ['STARRED']) }
          .to raise_error(Google::Apis::Error)
      end
    end
  end
end

