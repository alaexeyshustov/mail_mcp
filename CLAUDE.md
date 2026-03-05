# CLAUDE.md — Agent Instructions for Gmail MCP Server

## Project Overview

This is a **Ruby** MCP (Model Context Protocol) server that exposes Gmail as tools for AI agents. It uses the `fast-mcp` gem for the MCP server, `google-apis-gmail_v1` for Gmail API access, and `ruby_llm` with Gemini for email classification.

**Language: Ruby (3.1+). Do NOT use Python anywhere in this project.**

---

## Critical Rules

1. **Always create a plan first** — before writing any code, outline the steps you will take (files to create/modify, classes involved, dependencies).
2. **Always create specs first** — write RSpec tests before implementing any new feature or tool. Tests drive the design.
3. **Never use Python** — this is a pure Ruby project. All code, scripts, and tooling must be Ruby.
4. **Never commit secrets** — `credentials.json`, `token.yaml`, and `.env` are git-ignored. Do not create or modify them.

---

## Project Structure

```
gmail_mcp/
├── bin/cli                      # Dry::CLI entry point (setup, test, reset, status, server)
├── lib/
│   ├── mcp_server.rb            # MCP server entry point — registers all tools, starts FastMcp::Server
│   ├── gmail_service.rb         # Gmail API wrapper (OAuth, list, get, search, modify labels)
│   ├── gmail_auth.rb            # Google OAuth2 loopback flow (browser → localhost callback)
│   ├── email_classifier.rb      # Gemini-based email classification via ruby_llm
│   └── tools/                   # One file per MCP tool (FastMcp::Tool subclasses)
│       ├── list_emails.rb
│       ├── get_email.rb
│       ├── search_emails.rb
│       ├── get_labels.rb
│       ├── get_unread_count.rb
│       ├── add_labels.rb
│       └── classify_emails.rb
├── spec/
│   ├── spec_helper.rb           # RSpec config + WebMock (no real HTTP in tests)
│   ├── support/
│   │   └── gmail_fixtures.rb    # Shared test doubles & helpers
│   └── lib/
│       ├── gmail_service_spec.rb
│       ├── gmail_auth_spec.rb
│       ├── email_classifier_spec.rb
│       └── tools/               # One spec per tool — mirrors lib/tools/
│           ├── list_emails_spec.rb
│           ├── get_email_spec.rb
│           ├── search_emails_spec.rb
│           ├── get_labels_spec.rb
│           ├── get_unread_count_spec.rb
│           ├── add_labels_spec.rb
│           └── classify_emails_spec.rb
├── Gemfile
├── .env.example                 # Environment variable template
├── .rspec                       # RSpec config (--format documentation --color)
└── credentials.json.example     # OAuth credentials template
```

---

## Commands

| Task                   | Command                                                                        |
| ---------------------- | ------------------------------------------------------------------------------ |
| Install dependencies   | `bundle install`                                                               |
| Run all tests          | `bundle exec rspec`                                                            |
| Run a single spec file | `bundle exec rspec spec/lib/tools/list_emails_spec.rb`                         |
| Run a specific test    | `bundle exec rspec spec/lib/tools/list_emails_spec.rb -e "passes max_results"` |
| Start MCP server       | `bundle exec ruby lib/mcp_server.rb`                                           |
| CLI setup              | `bin/cli setup`                                                                |
| CLI test (live Gmail)  | `bin/cli test`                                                                 |
| CLI status             | `bin/cli status`                                                               |
| CLI reset auth         | `bin/cli reset`                                                                |

---

## How to Add a New MCP Tool

### Step 1: Plan

Before writing code, outline:

- Tool name and description
- Required and optional arguments with types
- Which `GmailService` method(s) the tool will call
- Whether `GmailService` needs a new method
- Edge cases and error scenarios

### Step 2: Write the spec first

Create `spec/lib/tools/<tool_name>_spec.rb` following the existing pattern:

```ruby
require_relative '../../spec_helper'
require_relative '../../../lib/gmail_service'
require_relative '../../../lib/tools/<tool_name>'

RSpec.describe Tools::<ToolClass> do
  let(:gmail) { instance_double(GmailService) }

  before { described_class.gmail_service = gmail }

  describe '#call' do
    it 'calls the expected GmailService method with correct arguments' do
      expect(gmail).to receive(:<service_method>).with(<args>).and_return(<result>)
      tool = described_class.new
      result = tool.call(<tool_args>)
      expect(result).to eq(<result>)
    end

    context 'when Gmail API raises an error' do
      it 'propagates the error' do
        allow(gmail).to receive(:<service_method>).and_raise(Google::Apis::Error.new('API error'))
        tool = described_class.new
        expect { tool.call(<tool_args>) }.to raise_error(Google::Apis::Error)
      end
    end
  end

  describe '.tool_name' do
    it 'is "<tool_name>"' do
      expect(described_class.tool_name).to eq('<tool_name>')
    end
  end
end
```

### Step 3: Implement the tool

Create `lib/tools/<tool_name>.rb` following the existing pattern:

```ruby
require 'fast_mcp'
require_relative '../gmail_service'

module Tools
  class <ToolClass> < FastMcp::Tool
    tool_name '<tool_name>'
    description '<Human-readable description for LLM agents>'

    arguments do
      required(:<arg>).filled(:string).description('<description>')
      optional(:<arg>).filled(:integer).description('<description>')
    end

    def call(<keyword_args>)
      self.class.gmail_service.<service_method>(<args>)
    end

    class << self
      attr_accessor :gmail_service
    end
  end
end
```

### Step 4: Register the tool

In `lib/mcp_server.rb`:

1. Add `require_relative 'tools/<tool_name>'` at the top
2. Add `Tools::<ToolClass>` to the `gmail_service` injection array (if it uses Gmail)
3. Add `Tools::<ToolClass>` to `server.register_tools(...)`

### Step 5: Run specs

```bash
bundle exec rspec spec/lib/tools/<tool_name>_spec.rb
bundle exec rspec  # full suite — must stay green
```

---

## How to Add a New GmailService Method

### Step 1: Plan

Outline the Gmail API call, parameters, and return shape.

### Step 2: Write the spec first

Add tests to `spec/lib/gmail_service_spec.rb` using `VCR.use_cassette`. Create the cassette YAML file in `spec/cassettes/gmail_service/` before writing the test.

### Step 3: Implement

Add the method to `lib/gmail_service.rb`. The service wraps `@service` (a `Google::Apis::GmailV1::GmailService` instance). Always return plain Ruby hashes/arrays, not Google API objects.

### Step 4: Run specs

```bash
bundle exec rspec spec/lib/gmail_service_spec.rb
```

---

## Testing Conventions

- **Framework**: RSpec with `--format documentation`
- **HTTP mocking**: WebMock is enabled globally — all real HTTP is blocked in tests
- **Test doubles**: Use `instance_double(GmailService)` for tools, VCR cassettes for the `GmailService` and `EmailClassifier` layers
- **Fixtures**: Shared helpers in `spec/support/gmail_fixtures.rb` — use `sample_email_message`, `sample_email_headers`, `sample_email_payload`, `sample_label`
- **No monkey patching**: `config.disable_monkey_patching!` is on — use `RSpec.describe`, not `describe`
- **File naming**: Spec files mirror `lib/` structure under `spec/lib/`
- **Tool specs always test**: `#call` with valid args, `#call` error propagation, `.tool_name`

---

## VCR Cassette Conventions

VCR intercepts outgoing HTTP calls and replays pre-recorded responses from YAML cassette files, replacing Ruby-object-level mocks for the `GmailService` and `EmailClassifier` layers.

### When to use VCR vs mocks

| Layer                                  | Strategy                                                        |
| -------------------------------------- | --------------------------------------------------------------- |
| `lib/tools/*.rb`                       | `instance_double(GmailService)` — pure unit tests, no HTTP      |
| `lib/gmail_service.rb`                 | VCR cassettes — tests the real Google API client parsing        |
| `lib/email_classifier.rb` (happy path) | VCR cassettes — tests the real ruby_llm parsing                 |
| `lib/email_classifier.rb` (edge cases) | RSpec mocks — behavioural / reshaping logic                     |
| `lib/gmail_auth.rb`                    | RSpec mocks — OAuth loop-back flow uses TCPServer, not raw HTTP |

### Cassette location

```
spec/cassettes/
├── gmail_service/
│   ├── list_messages_default.yml   # GET /messages → 2 messages + full GET each
│   ├── list_messages_empty.yml     # GET /messages → empty result
│   ├── get_message.yml             # GET /messages/msg_123
│   ├── get_message_no_headers.yml  # GET /messages/msg_empty (no headers)
│   ├── get_message_multipart.yml   # GET /messages/msg_multi (multipart body)
│   ├── get_labels.yml              # GET /labels
│   ├── get_unread_count.yml        # GET /labels/UNREAD → messagesTotal: 42
│   ├── get_unread_count_nil.yml    # GET /labels/UNREAD → messagesTotal absent
│   ├── modify_labels_add.yml       # POST /messages/msg_123/modify → add STARRED
│   ├── modify_labels_remove.yml    # POST /messages/msg_123/modify → remove STARRED
│   ├── modify_labels_nil_labels.yml# POST → response omits labelIds
│   └── modify_labels_error.yml     # POST → 403 Forbidden
└── email_classifier/
    └── classify.yml                # POST to Gemini generateContent
```

### Cassette format rules

1. **RFC 2616 date** — `recorded_at` must be httpdate format, e.g. `"Fri, 20 Feb 2026 10:00:00 GMT"`. ISO 8601 (`2026-02-...`) will cause `ArgumentError`.
2. **Response headers as arrays** — each header value must be a YAML sequence, e.g. `Content-Type:\n  - application/json`.
3. **Matching strategy** — `[:method, :host, :path]` (query params and auth headers are ignored).
4. **Base64 body data** — Gmail API body.data is base64url-encoded in cassettes; the gem auto-decodes it so Ruby code sees plain text.

### Using VCR in a test

```ruby
it 'returns labels' do
  VCR.use_cassette('gmail_service/get_labels') do
    result = client.get_labels
    expect(result.first).to include(:id, :name, :type)
  end
end
```

### Fake credentials for GmailService VCR tests

```ruby
let(:fake_credentials) do
  Class.new do
    def universe_domain; 'googleapis.com'; end  # required by google-apis-core
    def apply!(headers); end                     # no-op; VCR stubs HTTP
    def apply(headers);  end
    def principal; nil; end
  end.new
end

subject(:client) do
  allow_any_instance_of(GmailService).to receive(:authorize).and_return(fake_credentials)
  GmailService.new(credentials_path: '/fake/credentials.json', token_path: '/fake/token.yaml')
end
```

> **Why a concrete class, not a double?** RSpec's `as_null_object` makes doubles respond `true` to `respond_to?(:to_ary)`, which causes Faraday's `Headers#[]=` to call `nil.join` and crash. A plain Ruby class avoids this.

### Adding a new cassette

1. Add the cassette YAML to `spec/cassettes/<service>/<name>.yml`
2. Record the interactions (or craft them manually using the existing cassettes as templates)
3. Ensure `recorded_at` is RFC 2616 (use `Time.now.httpdate` in Ruby to generate one)
4. Reference it in your spec: `VCR.use_cassette('<service>/<name>') do ... end`

---

## Architecture Notes

- **Dependency Injection**: Tools receive their dependencies through class-level accessors (`gmail_service=`, `classifier=`), set in `mcp_server.rb`. This allows easy mocking in tests.
- **Single GmailService instance**: Created once in `mcp_server.rb` and shared across all tool classes.
- **OAuth scope**: `gmail.modify` (allows reading and label modification, but not sending/deleting).
- **MCP transport**: stdio only (stdin/stdout JSON-RPC). No HTTP server.
- **fast-mcp DSL**: Tools inherit from `FastMcp::Tool` and use `tool_name`, `description`, and `arguments` DSL.
- **Environment variables**: Loaded via `dotenv`. See `.env.example` for `CREDENTIALS_PATH`, `TOKEN_PATH`, `GEMINI_API_KEY`.

---

## Workflow Checklist (for every change)

1. [ ] Create a plan — list files to change and why
2. [ ] Write or update specs first
3. [ ] Run the new specs — confirm they fail for the right reason
4. [ ] Implement the change
5. [ ] Run `bundle exec rspec` — all specs must pass
6. [ ] Update `mcp_server.rb` registration if adding a tool
7. [ ] Do not modify `credentials.json`, `token.yaml`, or `.env`
