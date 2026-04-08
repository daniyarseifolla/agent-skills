---
name: literal-core-security
description: "OWASP-adapted security checklist with grep patterns — framework-agnostic universal checks. Tech-stack-specific checks live in the respective adapter. Loaded by pipeline/code-reviewer — never invoked directly."
disable-model-invocation: true
---

# Core Security

OWASP-adapted checklist for web frontend/backend review. Framework-agnostic only.

> Tech-stack-specific security checks (Angular XSS, React dangerouslySetInnerHTML, etc.) live in the `tech-stack` adapter under `security_checks`.

---

## 1. Severity Classification

```yaml
severity_levels:
  BLOCKER:
    description: "Security vulnerability — blocks approval"
    action: CHANGES_REQUESTED
  MAJOR:
    description: "Potential security risk — blocks approval"
    action: CHANGES_REQUESTED
  MINOR:
    description: "Best practice deviation — does not block"
    action: APPROVED_WITH_COMMENTS
  NIT:
    description: "Stylistic preference — does not block"
    action: APPROVED_WITH_COMMENTS
```

---

## 2. Universal Checks

```yaml
universal_checks:
  secrets_in_code:
    patterns: ['password\s*=\s*[''"]', 'secret\s*=', 'apiKey\s*=', 'token\s*=\s*[''"]', 'private_key', 'AWS_SECRET', '-----BEGIN (RSA |EC )?PRIVATE KEY-----']
    exclude: [".env.example", "*.test.*", "*.spec.*", "*.mock.*", "**/fixtures/**"]
    severity: BLOCKER

  eval_injection:
    patterns: ['eval\(', 'Function\(', 'setTimeout\([''"]', 'setInterval\([''"]']
    severity: BLOCKER

  console_sensitive:
    patterns: ['console\.(log|debug|info)\(.*(?:token|password|secret|key)']
    severity: MAJOR

  error_info_leak:
    patterns: ['stack.*trace|stackTrace', 'err\.message.*response', 'catch.*res\.json.*err', 'error\.message.*(?:response|render|display|show)']
    severity: MAJOR

  hardcoded_urls:
    patterns: ['http://localhost', 'https://staging', 'https://dev\.']
    exclude: [".env*", "*.config.*", "proxy.conf.*"]
    severity: MINOR

  template_injection:
    patterns: ['\$\{.*\}.*(?:url|endpoint|api|query)', '\+\s*[''"].*(?:SELECT|INSERT|UPDATE|DELETE)']
    severity: BLOCKER
```

---

## 3. Modern Threat Patterns

```yaml
modern_threats:
  prototype_pollution:
    patterns: ['Object\.assign\(.*req\.', '__proto__', 'constructor\[', 'prototype\[']
    severity: BLOCKER
    fix: "Use Object.create(null) for dictionaries, validate object keys"

  open_redirect:
    patterns: ['window\.location\s*=.*req', 'redirect.*req\.query', 'router\.navigate.*param']
    severity: MAJOR
    fix: "Whitelist allowed redirect URLs, never use user input directly"

  clickjacking:
    check: "Verify X-Frame-Options or CSP frame-ancestors header exists"
    grep_pattern: "X-Frame-Options|frame-ancestors"
    severity: MAJOR

  cors_misconfiguration:
    patterns: ['Access-Control-Allow-Origin.*\*', 'cors\(\).*origin.*true']
    severity: MAJOR
    fix: "Whitelist specific origins, never use wildcard in production"

  ssrf:
    patterns: ['fetch\(.*req\.', 'http\.get\(.*param', 'axios\(.*user']
    severity: BLOCKER
    fix: "Validate and whitelist URLs, block internal network ranges"
```

---

## 4. Auth Token Checks (Universal)

```yaml
auth_token_checks:
  hardcoded_auth:
    patterns: ['Authorization.*hardcoded|Bearer\s+[a-zA-Z0-9]{20,}']
    severity: BLOCKER
    fix: "Use environment config or secure token service"

  token_in_localstorage:
    patterns: ['localStorage\.setItem\(.*token', 'localStorage\.setItem\(.*auth']
    severity: MAJOR
    fix: "Use httpOnly cookies for token storage"
```

---

## 5. Review Procedure

How `code-reviewer` applies this checklist:

```yaml
review_steps:
  - step: 1
    action: "Run grep patterns for each category against changed files"
    command: "grep -Prn '{pattern}' {changed_files}"
    note: "Use grep -P (Perl regex) for patterns with lookaheads. Fallback: grep -rn for simple patterns."
  - step: 2
    action: "Filter false positives"
    exclude:
      - test files (*.spec.*, *.test.*)
      - mock files
      - comments and disabled code
  - step: 3
    action: "Load tech_stack_adapter.security_checks and run those patterns too"
    condition: "If tech-stack adapter is loaded"
  - step: 4
    action: "Classify each finding by severity"
    reference: "severity_levels defined above"
  - step: 5
    action: "Add findings to review handoff"
    format:
      finding: string
      file: string
      line: number
      severity: "BLOCKER|MAJOR|MINOR|NIT"
      fix_suggestion: string

blocking_rule: >
  If any BLOCKER or MAJOR finding exists, verdict must be
  CHANGES_REQUESTED. MINOR and NIT findings allow APPROVED_WITH_COMMENTS.
```
