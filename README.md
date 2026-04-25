# lsec — Laravel Security Audit (GitHub Action)

A GitHub Action that runs [`lsec`](https://lsec.afaan.dev) — the Laravel
security audit CLI — against your repository, uploads results to GitHub Code
Scanning as SARIF, and posts a summary comment on pull requests.

`lsec` ships 61 rules across 8 categories: `env`, `auth`, `injection`, `http`,
`storage`, `deps`, `secrets`, `logging`. See the
[`lsec` README](https://github.com/AfaanBilal/lsec) for the full rule list.

---

## Quick start

```yaml
# .github/workflows/lsec.yml
name: lsec

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  security-events: write   # required for SARIF upload
  pull-requests: write     # required for the PR summary comment

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: AfaanBilal/lsec-action@v1
```

That defaults to scanning the repository root, failing on `high` or above,
uploading SARIF, and commenting on pull requests.

---

## Inputs

| Name             | Default            | Description |
|------------------|--------------------|-------------|
| `path`           | `.`                | Path to the Laravel project root. |
| `version`        | `latest`           | `lsec` release version (e.g. `0.1.4`) or `latest`. |
| `fail-on`        | `high`             | Minimum severity that fails the job: `critical` \| `high` \| `medium` \| `low` \| `info`. |
| `min-confidence` | `0.7`              | Minimum confidence score for reported findings (0.0 – 1.0). |
| `baseline`       | `""`               | Path to a baseline file used to suppress known findings. |
| `only`           | `""`               | Comma-separated rule categories to include (e.g. `env,secrets,injection`). |
| `skip`           | `""`               | Comma-separated rule categories to skip. |
| `upload-sarif`   | `true`             | Upload SARIF to GitHub Code Scanning. |
| `post-comment`   | `true`             | Post (or update) a summary comment on pull requests. |
| `sarif-output`   | `lsec.sarif`       | Path to write the SARIF report. |
| `json-output`    | `lsec-report.json` | Path to write the JSON report. |

## Outputs

| Name             | Description |
|------------------|-------------|
| `result`         | `pass` or `fail` (against the `fail-on` threshold). |
| `exit-code`      | Raw `lsec` exit code (`0` clean, `1` threshold breached, `2` runtime error). |
| `findings-count` | Total findings reported. |
| `critical-count` | Number of CRITICAL findings. |
| `high-count`     | Number of HIGH findings. |
| `medium-count`   | Number of MEDIUM findings. |
| `low-count`      | Number of LOW findings. |
| `info-count`     | Number of INFO findings. |
| `sarif-path`     | Path to the generated SARIF file. |
| `json-path`      | Path to the generated JSON report. |

## Permissions

| Permission                 | Why |
|----------------------------|-----|
| `contents: read`           | Checkout the repository. |
| `security-events: write`   | Upload SARIF to Code Scanning. Omit if `upload-sarif: false`. |
| `pull-requests: write`     | Post the PR summary comment. Omit if `post-comment: false`. |

> Code Scanning is free on public repositories. Private repositories require
> GitHub Advanced Security.

---

## Examples

### Scan a sub-directory

```yaml
- uses: AfaanBilal/lsec-action@v1
  with:
    path: ./api
```

### Fail only on critical findings

```yaml
- uses: AfaanBilal/lsec-action@v1
  with:
    fail-on: critical
```

### Pin a specific `lsec` version

```yaml
- uses: AfaanBilal/lsec-action@v1
  with:
    version: 0.1.4
```

### Use a baseline to suppress known findings

```yaml
- uses: AfaanBilal/lsec-action@v1
  with:
    baseline: ci/lsec-baseline.json
```

Generate the baseline locally with `lsec baseline write .` and commit it.

### Limit to a few rule categories

```yaml
- uses: AfaanBilal/lsec-action@v1
  with:
    only: env,secrets,deps
```

### Skip categories you don't care about

```yaml
- uses: AfaanBilal/lsec-action@v1
  with:
    skip: logging
```

### Disable SARIF upload (e.g. private repo without Advanced Security)

```yaml
- uses: AfaanBilal/lsec-action@v1
  with:
    upload-sarif: false
```

### Run as a non-blocking advisory check

```yaml
- uses: AfaanBilal/lsec-action@v1
  id: lsec
  continue-on-error: true
  with:
    fail-on: info

- run: echo "lsec found ${{ steps.lsec.outputs.findings-count }} issue(s)"
```

### Use outputs in subsequent steps

```yaml
- uses: AfaanBilal/lsec-action@v1
  id: lsec

- name: Notify on critical findings
  if: steps.lsec.outputs.critical-count != '0'
  run: ./notify-security.sh "${{ steps.lsec.outputs.critical-count }} critical findings"
```

---

## How it works

1. **Install** — downloads the matching `lsec` release binary into
   `$RUNNER_TEMP/lsec-bin/` and adds it to `PATH`.
2. **Scan (JSON)** — runs `lsec scan ... --ci --format json`. The `lsec` exit
   code is the source of truth for `pass` / `fail`.
3. **Scan (SARIF)** — runs `lsec scan ... --format sarif` (only when
   `upload-sarif: true`).
4. **Upload SARIF** — hands the report to `github/codeql-action/upload-sarif@v3`
   so findings appear inline on PRs and in the **Security** tab.
5. **PR comment** — posts (or updates) a single sticky comment with the
   severity table and top findings.
6. **Enforce** — exits non-zero when `result == fail`, failing the job.

## Platform support

| OS / arch              | Supported |
|------------------------|-----------|
| `ubuntu-latest` (x86_64) | ✅       |
| Linux ARM64            | ✅        |
| `macos-latest` (Apple Silicon) | ✅ |
| `macos-13` (Intel)     | ✅        |
| `windows-latest`       | ✅ (x86_64 only) |

## Versioning

This action follows semantic versioning. Pin to:

- `@v1` — latest 1.x release (recommended).
- `@v1.2.3` — exact release.
- `@main` — bleeding edge (not recommended for production).

The `version` input controls which `lsec` CLI release is downloaded; it is
independent of the action version.

## License

MIT — see [`lsec`](https://github.com/AfaanBilal/lsec) for the upstream tool.

Action authored by [Afaan Bilal](https://afaan.dev).
