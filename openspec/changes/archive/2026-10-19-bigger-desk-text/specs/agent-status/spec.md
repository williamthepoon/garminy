# Spec Delta

## MODIFIED Requirements

### Requirement: Agents card
The watch SHALL show an Agents card listing up to 2 sessions, most urgent first. Each row SHALL show the label, a state colour, a one-word state (busy, waiting, done or error) and the time spent in that state. When more sessions exist, the card SHALL show how many are hidden as "+n".

#### Scenario: Three sessions
- **WHEN** one session needs you for 3 minutes, one is working for 12 minutes and one is done
- **THEN** the card lists the needs-you session first as "waiting · 3m", then the working session as "busy · 12m", and shows "+1"

#### Scenario: More sessions than fit
- **WHEN** six sessions exist
- **THEN** the card lists the two most urgent and shows "+4"

#### Scenario: No sessions
- **WHEN** the companion is connected and no Claude Code session is running
- **THEN** the card reads "No agents running"

### Requirement: Agent alerts
A session entering needs you SHALL raise a needs-you alert. A session entering done after working for at least 30 seconds SHALL raise a done alert. A session entering error SHALL raise a failed alert. Each alert SHALL be labelled with the session label. Each alert's detail SHALL fit the 20-byte detail limit as whole words or with a trailing "…", never cut silently mid-word.

#### Scenario: Quick turn
- **WHEN** a session works for 10 seconds and then finishes
- **THEN** its state becomes done but no alert is raised

#### Scenario: Long turn
- **WHEN** a session works for 4 minutes and then finishes
- **THEN** a done alert labelled with the session is raised

#### Scenario: Stop failure
- **WHEN** a session's turn ends with a stop failure
- **THEN** the failed alert's detail reads "Error"

#### Scenario: Permission for a short tool name
- **WHEN** a session asks permission to run Bash
- **THEN** the needs-you alert's detail reads "Allow Bash"

#### Scenario: Permission for a long tool name
- **WHEN** a session asks permission to run the MCP tool "mcp__claude_ai_Gmail__search_threads"
- **THEN** the detail drops the MCP server prefix, is at most 20 bytes, and ends with "…" if the tool name was shortened
