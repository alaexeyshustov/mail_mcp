# GitHub Copilot MCP Configuration for Gmail Server

This guide explains how to integrate the Gmail MCP server with GitHub Copilot.

## For JetBrains IDEs (RubyMine, IntelliJ IDEA, etc.)

### Project Configuration (recommended)

The `.mcp.json` file in the project root is already configured and JetBrains
picks it up automatically when you open the project:

```json
{
  "mcpServers": {
    "gmail": {
      "command": "bundle",
      "args": [ "exec", "ruby", "path", "mcp_server.rb"],
      "env": {}
    }
  }
}
```

> **Note:** Update `cwd` if you move the project to a different path.

### Global Configuration

To make the server available in all projects, create or edit
`~/.config/github-copilot/mcp.json`:

```json
{
  "mcpServers": {
    "gmail": {
      "command": "bundle",
      "args": ["exec", "ruby", "mcp_server.rb"],
      "cwd": "path,
      "env": {}
    }
  }
}
```

## For VS Code

Add to `.vscode/mcp.json` or your user settings:

```json
      "servers": {
        "gmail": {
          "command": "./bin/cli",
          "args": ["server"],
          "env": {}
        }
      }
```

## Prerequisites

1. Ruby ≥ 3.1 and Bundler installed
2. `bundle install` run inside the project directory
3. `credentials.json` present (downloaded from Google Cloud Console)
4. `token.yaml` present — run the OAuth flow once:

```bash
cd /Users/aleksey.shustov/gmail_mcp
bundle exec ruby -e "require_relative 'lib/gmail_service'; GmailService.new(credentials_path: 'credentials.json', token_path: 'token.yaml')"
```

Follow the printed URL, authorise in the browser, paste the code back into
the terminal. `token.yaml` is created and saved automatically. The server
runs non-interactively from this point on — `googleauth` refreshes the
access token automatically.

## Testing the Integration

1. Restart your IDE or reload GitHub Copilot
2. Open GitHub Copilot Chat (agent mode)
3. Try these prompts:
   - "Show me my 5 most recent emails"
   - "How many unread emails do I have?"
   - "Search for emails from john@example.com"
   - "Find unread emails with subject containing invoice"
   - "List my Gmail labels"

## Manual server test (terminal)

```bash
cd /Users/aleksey.shustov/gmail_mcp

# 1. Verify tools are registered
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' \
  | ./bin/cli server

# 2. Call get_unread_count
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_unread_count","arguments":{}}}\n' \
  | ./bin/cli server
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Copilot doesn't detect the server | Restart IDE; check `cwd` path in `.mcp.json` |
| `token.yaml` missing | Run the OAuth flow (see Prerequisites above) |
| Token expired / auth error | Delete `token.yaml` and re-run the OAuth flow |
| `bundle: command not found` | Use full path: `/usr/local/bin/bundle` in `command` field |
| Gmail API permission denied | Verify Gmail API is enabled in Google Cloud Console |
