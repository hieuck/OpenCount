# Security Policy

## Reporting a Vulnerability

OpenCount takes security seriously. If you discover a security vulnerability, please report it privately.

**Do not report security vulnerabilities through public GitHub issues.**

Instead, please send an email to: [security@opencount.dev](mailto:security@opencount.dev)

You should receive a response within 48 hours. If you don't, please follow up to ensure your message was received.

## What to Include

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact
- Any suggested fixes (if known)

## Scope

- The KMP shared module (`packages/shared/`)
- Platform-specific apps (`apps/`)
- Build and CI infrastructure (`.github/workflows/`)
- Dependencies (see `gradle/libs.versions.toml`)

## Out of Scope

- Third-party services (GitHub Actions, CloudKit, etc.)
- Unrelated infrastructure

## Policy

- We will acknowledge receipt within 48 hours
- We will provide an estimated timeline for a fix
- We will notify you when the fix is released
- We will credit you in the release notes (unless you prefer to remain anonymous)
