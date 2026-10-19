# agent-status Specification

## Purpose
Shows what each Claude Code session on the Mac is doing, so the user can see from across the desk which agents are working, finished, or waiting for them.

## Requirements

### Requirement: Session tracking from hook events
The companion SHALL track each Claude Code session by its session ID. A new prompt or tool activity SHALL set it to working. A permission request, a question or plan put to the user, or an input request SHALL set it to needs you; the idle reminder Claude Code sends after a finished turn SHALL NOT. Finishing a turn SHALL set it to done, and a stop failure SHALL set it to error.

#### Scenario: Agent finishes
- **WHEN** a session that was working fires its stop event
- **THEN** that session's state becomes done

#### Scenario: Permission prompt
- **WHEN** a session asks for permission to run a tool
- **THEN** that session's state becomes needs you within 2 seconds

#### Scenario: Claude asks a question
- **WHEN** a session asks the user a multiple-choice question or presents a plan for approval
- **THEN** that session's state becomes needs you

#### Scenario: Idle reminder after finishing
- **WHEN** a session finished its turn and Claude Code later sends its idle "waiting for input" notification
- **THEN** the session stays done and no needs-you alert is raised

### Requirement: Session lifetime
A session SHALL be removed when it ends. A session with no events for 12 hours SHALL also be removed, so that sessions whose end event was missed do not linger.

#### Scenario: Session closed
- **WHEN** the user exits a Claude Code session
- **THEN** it disappears from the Agents card

#### Scenario: Missed end event
- **WHEN** a session has sent no events for 12 hours
- **THEN** it is removed from the Agents card

### Requirement: Session labels
Each session SHALL be labelled with the last path component of its working directory, truncated to 16 characters. Sessions with the same label SHALL get a numeric suffix.

#### Scenario: Two sessions in one repo
- **WHEN** two sessions run in folders both named "garminy"
- **THEN** they are labelled "garminy" and "garminy 2"

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

### Requirement: Header status dot
While the companion is connected, the card header SHALL show a small dot in the colour of the most urgent session state, or no dot when no sessions exist.

#### Scenario: Agent waiting
- **WHEN** any session needs you
- **THEN** the header dot on every card shows the needs-you colour

### Requirement: Agent content stays private
The companion MUST NOT send prompt text, assistant messages, tool inputs or file contents to the watch. Only labels, states, timings and tool names SHALL cross the link.

#### Scenario: Link audit
- **WHEN** every frame sent during a session that edits files and runs commands is captured
- **THEN** no frame contains prompt text, message text, tool input or file content
