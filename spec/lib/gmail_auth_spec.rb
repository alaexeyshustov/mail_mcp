require_relative '../spec_helper'
require_relative '../../lib/gmail_auth'

RSpec.describe GmailAuth do
  let(:credentials_path) { '/fake/credentials.json' }
  let(:token_path)       { '/fake/token.yaml' }
  let(:scope)            { ['https://www.googleapis.com/auth/gmail.modify'] }
  let(:output)           { StringIO.new }

  let(:mock_client_id)  { double('client_id') }
  let(:mock_token_store){ double('token_store') }
  let(:mock_authorizer) { double('authorizer') }
  let(:mock_tcp_server) { double('tcp_server') }
  let(:mock_credentials){ double('credentials') }

  let(:fake_port)     { 12345 }
  let(:redirect_uri)  { "http://localhost:#{fake_port}" }

  subject(:auth) do
    described_class.new(
      credentials_path: credentials_path,
      token_path: token_path,
      scope: scope,
      output: output
    )
  end

  before do
    allow(Google::Auth::ClientId).to receive(:from_file)
      .with(credentials_path).and_return(mock_client_id)
    allow(Google::Auth::Stores::FileTokenStore).to receive(:new)
      .with(file: token_path).and_return(mock_token_store)
    allow(TCPServer).to receive(:new).with('localhost', 0).and_return(mock_tcp_server)
    allow(mock_tcp_server).to receive(:addr).and_return([nil, fake_port])
    allow(Google::Auth::UserAuthorizer).to receive(:new)
      .with(mock_client_id, scope, mock_token_store, redirect_uri)
      .and_return(mock_authorizer)
  end

  describe '#credentials' do
    context 'when a stored token already exists' do
      it 'returns the existing credentials without opening a browser' do
        allow(mock_authorizer).to receive(:get_credentials)
          .with(GmailAuth::USER_ID).and_return(mock_credentials)
        allow(mock_tcp_server).to receive(:close)

        expect(auth.credentials).to eq(mock_credentials)
        expect(output.string).to be_empty
      end
    end

    context 'when no stored token exists' do
      let(:mock_socket) { double('socket') }

      before do
        allow(mock_authorizer).to receive(:get_credentials)
          .with(GmailAuth::USER_ID).and_return(nil)
        allow(mock_authorizer).to receive(:get_authorization_url)
          .with(base_url: redirect_uri).and_return('https://auth.example.com/auth')
        allow(auth).to receive(:system)
        allow(mock_tcp_server).to receive(:accept).and_return(mock_socket)
        allow(mock_socket).to receive(:gets)
          .and_return("GET /?code=auth_code&scope=x HTTP/1.1\r\n")
        allow(mock_socket).to receive(:print)
        allow(mock_socket).to receive(:close)
        allow(mock_tcp_server).to receive(:close)
        allow(mock_authorizer).to receive(:get_and_store_credentials_from_code)
          .with(user_id: GmailAuth::USER_ID, code: 'auth_code', base_url: redirect_uri)
          .and_return(mock_credentials)
      end

      it 'opens the browser and returns new credentials after the callback' do
        expect(auth.credentials).to eq(mock_credentials)
      end

      it 'prints progress messages to the configured output' do
        auth.credentials
        expect(output.string).to include('Opening browser')
        expect(output.string).to include('Waiting for authorization callback')
      end

      it 'raises when the callback contains no code' do
        allow(mock_socket).to receive(:gets).and_return("GET /?error=access_denied HTTP/1.1\r\n")
        expect { auth.credentials }.to raise_error('Authorization failed: no code received in callback')
      end
    end
  end
end
