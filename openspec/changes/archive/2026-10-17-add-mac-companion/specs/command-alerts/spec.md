# Spec Delta

## Purpose

Tells the user when a long-running terminal command finishes, and whether it succeeded, without them having to keep checking the terminal.

## ADDED Requirements

### Requirement: Report long commands
With the shell snippet installed, each interactive command SHALL be reported to the companion when it starts and when it ends, with its name and, on completion, its duration and exit status. Only commands that ran for at least the threshold (default 30 seconds, configurable) SHALL raise an alert. The command name SHALL be the first word of the command line only.

#### Scenario: Long build succeeds
- **WHEN** `cargo build --release` runs for 2 minutes 14 seconds and exits 0
- **THEN** the companion receives command "cargo", duration 134 s and success

#### Scenario: Short command
- **WHEN** `ls` runs for under a second
- **THEN** no alert is raised and the companion no longer counts it as running

### Requirement: Done and failed alerts
A reported command that exited 0 SHALL raise a done alert. A non-zero exit SHALL raise a failed alert. The alert SHALL show the command name, the duration and, for failures, the exit code.

#### Scenario: Tests fail
- **WHEN** `pytest` runs for 4 minutes and exits 1
- **THEN** a failed alert reads "pytest" with "4m · exit 1"

### Requirement: Skip interactive and agent commands
The snippet SHALL NOT report editors, pagers, remote shells and other interactive programs on a configurable ignore list. It SHALL NOT report commands run by Claude Code's own tool calls.

#### Scenario: Long editing session
- **WHEN** the user runs `vim notes.md` for 20 minutes
- **THEN** nothing is reported

#### Scenario: Command run by an agent
- **WHEN** Claude Code runs a 60-second test command in its shell
- **THEN** no command alert is raised

### Requirement: Running commands keep the Mac awake
The snippet SHALL tell the companion when a command starts, so the companion knows it is running. A command that has been running for at least the threshold SHALL count as active work for keep-awake.

#### Scenario: Overnight job
- **WHEN** a command has been running for an hour with no user input
- **THEN** the Mac has not idle-slept

### Requirement: Never slow the shell
Reporting MUST NOT delay the shell prompt by more than 50 ms. Reporting SHALL fail silently when the companion is not running.

#### Scenario: Companion not running
- **WHEN** the companion app is quit and a long command finishes
- **THEN** the prompt returns normally with no error output
