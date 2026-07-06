# Security Policy

## Reporting a Vulnerability

Please **do not** open a public issue or discussion for security
vulnerabilities.

Instead, use GitHub's private vulnerability reporting: go to the
[Security tab](https://github.com/cloudfra/template-go/security) →
**Advisories** → **Report a vulnerability**. This opens a private draft
security advisory visible only to maintainers, so the report and any
discussion stay confidential until a fix is ready.

This is especially relevant given the code-signing pipeline this template
ships (`make release-binaries`, `certtool`, `osslsigncode`/`openssl cms`) -
please report anything affecting binary signing or verification the same
way.

We'll acknowledge new reports as soon as possible and keep you updated as
the issue is investigated and resolved.
