# Supabase MCP Server Setup

## Goal

Add Supabase MCP server for project: `zhgxxhdulvlhgdyxjrab`

**MCP URL:** `https://mcp.supabase.com/mcp?project_ref=zhgxxhdulvlhgdyxjrab`

---

## Steps Completed

- [x] Created MCP config directory: `~/.config/mcp/`
- [x] Created settings file: `~/.config/mcp/settings.json`
- [x] Added MCP server configuration to the file

### Configuration Added

```json
{
  "mcpServers": {
    "supabase-project": {
      "url": "https://mcp.supabase.com/mcp?project_ref=zhgxxhdulvlhgdyxjrab"
    }
  }
}
```

---

## Steps Remaining

- [ ] **Verify config location** — Confirm `~/.config/mcp/settings.json` is the correct path for Antigravity
- [ ] **Restart Antigravity** — Close and reopen the application/extension
- [ ] **Verify MCP connection** — Check that the new Supabase MCP server appears in available tools
- [ ] **Test the connection** — Run a simple command to confirm the MCP server is working

---

## Troubleshooting

If the MCP server doesn't appear after restart:

1. **Check Antigravity settings** — Look for MCP configuration in the app's preferences
2. **Alternative config locations:**
   - `~/.cursor/mcp.json` (for Cursor)
   - VS Code extension settings
   - Application-specific config directory
3. **Verify JSON syntax** — Ensure the settings file is valid JSON

---

## Notes

- Project Reference: `zhgxxhdulvlhgdyxjrab`
- MCP servers are loaded at application startup
- Changes require a restart to take effect
