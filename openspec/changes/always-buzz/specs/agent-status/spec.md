## MODIFIED Requirements

### Requirement: Agent alerts
A session entering needs you SHALL raise a needs-you alert. A session entering done at the end of a turn SHALL raise a done alert, however short the turn was. A session entering error SHALL raise a failed alert. Each alert SHALL be labelled with the session label. Each alert's detail SHALL fit the 20-byte detail limit as whole words or with a trailing "…", never cut silently mid-word.

#### Scenario: Quick turn
- **WHEN** a session works for 10 seconds and then finishes
- **THEN** a done alert labelled with the session is raised

#### Scenario: Long turn
- **WHEN** a session works for 4 minutes and then finishes
- **THEN** a done alert labelled with the session is raised

#### Scenario: Turn ends after a question
- **WHEN** a session asked the user something and its turn then ends
- **THEN** the needs-you alert is withdrawn and a done alert is raised

#### Scenario: Stop failure
- **WHEN** a session's turn ends with a stop failure
- **THEN** the failed alert's detail reads "Error"

#### Scenario: Permission for a short tool name
- **WHEN** a session asks permission to run Bash
- **THEN** the needs-you alert's detail reads "Allow Bash"

#### Scenario: Permission for a long tool name
- **WHEN** a session asks permission to run the MCP tool "mcp__claude_ai_Gmail__search_threads"
- **THEN** the detail drops the MCP server prefix, is at most 20 bytes, and ends with "…" if the tool name was shortened
