# Contributing to garminy

Thanks for helping. garminy is small on purpose, so please keep changes focused.

## Ground rules

- **fēnix 7 only.** Other devices are out of scope unless a maintainer agrees first.
- **No accounts, API keys or servers.** Data comes from the watch itself, or from Garmin's built-in weather.
- **Never rely on the START button.** Every feature has to work with touch, UP, DOWN and BACK.

## Workflow (OpenSpec)

Feature work follows [OpenSpec](https://openspec.dev/):

1. Open an issue describing the change.
2. Add a proposal under `openspec/changes/<change-name>/` (`proposal.md`, delta specs, `design.md`, `tasks.md`). `openspec validate <change-name> --strict` must pass.
3. Implement the tasks and tick them off in `tasks.md`.
4. Open a PR. Once it's merged and verified, the change is archived into `openspec/specs/`.

Bug fixes that don't change specified behaviour can go straight to a PR.

## Development

See the [README](README.md#build) for toolchain setup.

```sh
scripts/build.sh   # build bin/garminy-fenix7.prg
scripts/test.sh    # unit tests in the Connect IQ simulator
```

- Put pure logic (maths, rules) in modules with `(:test)` coverage in `tests/Tests.mc`.
- Put test helpers inside `(:test) module T`, because top-level `(:test)` functions run as tests.
- Match the existing code style: 4-space indent, typed signatures, comments only where the intent isn't obvious.

## Content (fortunes, quotes, on this day)

Edit `content/*.json`, never `resources/jsonData/` (it is generated). Every entry must:

- Be **90 characters or fewer** (the build checks this).
- Be **original writing** (fortunes, on-this-day) or **public domain** with a correct attribution (quotes). Avoid commonly misattributed quotes.
- For on-this-day facts, be well documented. Include a source link in your PR.

Run `python3 scripts/build_content.py` to validate.

## Never commit

- Developer keys (`*.der`, `*.pem`) or built apps (`*.prg`, `*.iq`). `.gitignore` covers these.
- Personal data such as locations or accounts.
