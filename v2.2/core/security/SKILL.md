---
name: core-security
description: "OWASP-adapted security checklist with grep patterns for Angular/TypeScript. Loaded by pipeline/code-reviewer — never invoked directly."
disable-model-invocation: true
---

# Core Security

OWASP-adapted checklist for web frontend review. Framework-primary: Angular/TypeScript.

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

## 2. Framework-Agnostic Checks

```yaml
universal_checks:
  secrets_in_code:
    patterns: ['password\s*=\s*[''"]', 'secret\s*=', 'apiKey\s*=', 'token\s*=\s*[''"]', 'private_key', 'AWS_SECRET']
    exclude: [".env.example", "*.test.*", "*.spec.*", "*.mock.*"]
    severity: BLOCKER

  eval_injection:
    patterns: ['eval\(', 'Function\(', 'setTimeout\([''"]', 'setInterval\([''"]']
    severity: BLOCKER

  console_sensitive:
    patterns: ['console\.log.*password', 'console\.log.*token', 'console\.log.*secret']
    severity: MAJOR

  error_info_leak:
    patterns: ['stack.*trace', 'err\.message.*response', 'catch.*res\.json.*err']
    severity: MAJOR

  hardcoded_urls:
    patterns: ['http://localhost', 'https://staging', 'https://dev\.']
    exclude: [".env*", "*.config.*", "proxy.conf.*"]
    severity: MINOR
```

---

## 3. Angular-Specific Checks

> These checks apply when tech-stack adapter is Angular.

### 3a. XSS Checks (BLOCKER)

```yaml
xss_checks:
  severity: BLOCKER
  patterns:
    - pattern: "innerHTML"
      risk: "Direct HTML injection into DOM"
      fix: "Use Angular template binding or DomSanitizer"
    - pattern: "bypassSecurityTrust"
      risk: "Explicit Angular security bypass"
      fix: "Remove bypass; sanitize input upstream"
    - pattern: "\\[href\\]"
      risk: "URL injection via user-controlled input"
      fix: "Validate URL scheme (allow only https:)"
    - pattern: "document\\.write"
      risk: "DOM manipulation with unsanitized content"
      fix: "Use framework rendering; never document.write"
    - pattern: "eval\\("
      risk: "Arbitrary code execution"
      fix: "Remove eval; use safe alternatives"
```

### 3b. Injection Checks (BLOCKER)

```yaml
injection_checks:
  severity: BLOCKER
  patterns:
    - pattern: "eval\\(|Function\\(|setTimeout\\(['\"]"
      risk: "Code injection via string evaluation"
      fix: "Use function references, never string-to-code"
    - pattern: "\\$\\{.*\\}.*(?:url|endpoint|api|query)"
      risk: "Template literal injection in URLs/queries"
      fix: "Use parameterized queries or URL builder utilities"
    - pattern: "\\+\\s*['\"].*(?:SELECT|INSERT|UPDATE|DELETE)"
      risk: "String concatenation in SQL-like queries"
      fix: "Use parameterized queries exclusively"
```

### 3c. Auth/AuthZ Checks (BLOCKER)

```yaml
auth_checks:
  severity: BLOCKER
  patterns:
    - pattern: "path:\\s*['\"].*['\"](?!.*canActivate)"
      risk: "Route without canActivate guard"
      fix: "Add appropriate route guard"
      scope: "routing module files"
    - pattern: "localStorage\\.setItem\\(.*token"
      risk: "Token stored in localStorage (XSS-accessible)"
      fix: "Use httpOnly cookies for token storage"
    - pattern: "Authorization.*hardcoded|Bearer\\s+[a-zA-Z0-9]"
      risk: "Hardcoded auth token"
      fix: "Use environment config or secure token service"
  structural:
    - check: "HTTP interceptor exists for auth headers"
      risk: "Missing centralized auth — requests may leak or omit tokens"
```

### 3d. Secrets Detection (BLOCKER)

```yaml
secrets_detection:
  severity: BLOCKER
  patterns:
    - pattern: "password\\s*=\\s*['\"]"
    - pattern: "secret\\s*="
    - pattern: "apiKey\\s*="
    - pattern: "token\\s*=\\s*['\"]"
    - pattern: "private_key\\s*="
    - pattern: "-----BEGIN (RSA |EC )?PRIVATE KEY-----"
  exclude_paths:
    - ".env.example"
    - "*.test.*"
    - "*.spec.*"
    - "*.mock.*"
    - "**/fixtures/**"
```

### 3e. CSRF Checks (MAJOR)

```yaml
csrf_checks:
  severity: MAJOR
  patterns:
    - pattern: "HttpClient.*(?:post|put|patch|delete)(?!.*Xsrf)"
      risk: "State-changing request without CSRF protection"
      fix: "Enable HttpXsrfInterceptor or equivalent"
  structural:
    - check: "XSRF interceptor registered in app module"
      risk: "Missing global CSRF protection"
```

### 3f. Error Info Leak (MAJOR)

```yaml
error_leak_checks:
  severity: MAJOR
  patterns:
    - pattern: "console\\.(log|debug|info)\\(.*(?:token|password|secret|key)"
      risk: "Sensitive data logged to console"
      fix: "Remove sensitive data from log statements"
    - pattern: "stack.*trace|stackTrace"
      risk: "Stack trace exposure in HTTP response or UI"
      fix: "Return generic error messages to user"
    - pattern: "error\\.message.*(?:response|render|display|show)"
      risk: "Verbose error details shown to user"
      fix: "Map to user-friendly error messages"
```

---

## 4. Modern Threat Patterns

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

## 5. Review Procedure

How `code-reviewer` applies this checklist:

```yaml
review_steps:
  - step: 1
    action: "Run grep patterns for each category against changed files"
    command: "grep -rn '{pattern}' {changed_files}"
  - step: 2
    action: "Filter false positives"
    exclude:
      - test files (*.spec.*, *.test.*)
      - mock files
      - comments and disabled code
  - step: 3
    action: "Classify each finding by severity"
    reference: "severity_levels defined above"
  - step: 4
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
