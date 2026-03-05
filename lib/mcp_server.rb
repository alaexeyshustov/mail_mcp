#!/usr/bin/env ruby

require 'dotenv/load'
require 'fast_mcp'

require_relative 'gmail_service'
require_relative 'tools/list_emails'
require_relative 'tools/get_email'
require_relative 'tools/search_emails'
require_relative 'tools/get_labels'
require_relative 'tools/get_unread_count'
require_relative 'tools/add_labels'
require_relative 'tools/classify_emails'
require_relative 'email_classifier'

# Initialize a single shared GmailService instance.
# This avoids repeated OAuth initialization and keeps token refresh simple.
root = File.expand_path('../../', __FILE__)
gmail = GmailService.new(
  credentials_path: File.join(root, ENV.fetch('CREDENTIALS_PATH', 'credentials.json')),
  token_path: File.join(root, ENV.fetch('TOKEN_PATH', 'token.yaml'))
)

# Inject the shared service into each tool class
[
  Tools::ListEmails,
  Tools::GetEmail,
  Tools::SearchEmails,
  Tools::GetLabels,
  Tools::GetUnreadCount,
  Tools::AddLabels
].each { |tool_class| tool_class.gmail_service = gmail }

# Initialize the email classifier (uses Mistral via ruby_llm)
Tools::ClassifyEmails.classifier = EmailClassifier.new(
  api_key: ENV.fetch('MISTRAL_API_KEY', '')
)

# Create and configure the MCP server
# FastMcp::Server creates a FastMcp::Logger by default which suppresses stdout
# output when using the stdio transport — do not pass a plain Logger here.
server = FastMcp::Server.new(
  name: 'gmail',
  version: '1.0.0'
)

# Register all tools
server.register_tools(
  Tools::ListEmails,
  Tools::GetEmail,
  Tools::SearchEmails,
  Tools::GetLabels,
  Tools::GetUnreadCount,
  Tools::AddLabels,
  Tools::ClassifyEmails
)

# Start the server using stdio transport (default for local MCP servers)
server.start
