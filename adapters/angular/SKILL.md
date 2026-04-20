---
name: adapter-angular
description: "Use when working with Angular/Nx projects. Provides lint/test/build commands, patterns, and module lookup."
human_description: "Адаптер для Angular/Nx: команды lint/test/build, паттерны, module lookup, security checks."
disable-model-invocation: true
---

# Adapter: Angular (tech-stack)

Implements the `tech-stack` adapter contract. Loaded when `project.yaml` has `tech-stack: angular`.

---

## Version Targeting

```yaml
angular_version:
  minimum: ">=19"
  signal_inputs: ">=17.1 (input(), input.required())"
  signal_outputs: ">=17.3 (output())"
  new_control_flow: ">=17 (@if, @for, @switch)"
  signal_forms: ">=21 (experimental)"
  httpResource: ">=19"

  check: "Read package.json → @angular/core version. Skip checks for features above project version."

  override: "project.yaml → angular_version field (if specified, use that instead of package.json)"
```

---

## 1. Commands

Default commands. Override via `project.yaml -> project.commands`.

```yaml
commands:
  lint: "npx nx lint {app}"
  test: "npx nx test {app}"
  build: "npx nx build {app}"
  format: "npx nx format:write"
  serve: "npx nx serve {app}"

app_resolution: "project.yaml → project.name"
```

---

## 2. Quality Checks

Angular-specific patterns verified during code review (Phase 4).

```yaml
quality_checks:
  - name: "Standalone components"
    rule: "All new components MUST be standalone (standalone: true)"
    grep_bad: "standalone:\\s*false"
    severity: MAJOR

  - name: "Signal-based state"
    rule: "Prefer signal() over BehaviorSubject for new code"
    grep_good: "signal\\("
    grep_bad: "new BehaviorSubject"
    severity: MINOR

  - name: "OnPush change detection"
    rule: "All components MUST use OnPush"
    grep_bad: "changeDetection:\\s*ChangeDetectionStrategy\\.Default"
    severity: MAJOR

  - name: "inject() over constructor DI"
    rule: "Prefer inject() function over constructor injection"
    grep_bad: "constructor\\(.*private.*:"
    severity: MINOR

  - name: "Typed reactive forms"
    rule: "Use typed FormGroup/FormControl"
    grep_bad: "new FormGroup\\(\\{"
    grep_good: "new FormGroup<"
    severity: MINOR

  - name: "TrackBy for @for"
    rule: "Use track expression in @for blocks"
    grep_bad: "@for.*;"
    grep_good: "@for.*track"
    severity: MINOR

  - name: "Signal-based inputs"
    rule: "New components MUST use input() and input.required() instead of @Input()"
    grep_bad: "@Input\\("
    grep_good: "input\\(|input\\.required\\("
    severity: MAJOR

  - name: "Signal-based outputs"
    rule: "New components MUST use output() instead of @Output()"
    grep_bad: "@Output\\("
    grep_good: "output\\("
    severity: MAJOR

  - name: "Host bindings"
    rule: "Use host: {} in @Component metadata instead of @HostBinding/@HostListener"
    grep_bad: "@HostBinding|@HostListener"
    grep_good: "host:\\s*\\{"
    severity: MINOR

  - name: "takeUntilDestroyed for subscriptions"
    rule: "Manual subscriptions MUST use takeUntilDestroyed() or DestroyRef to prevent memory leaks"
    grep_bad: "\\.subscribe\\("
    grep_good: "takeUntilDestroyed|destroyRef"
    severity: MAJOR

  - name: "httpResource for data fetching"
    rule: "Prefer httpResource() or resource() over raw HttpClient.get() for signal-based data loading"
    grep_bad: "this\\.http\\.get|this\\.http\\.post"
    grep_good: "httpResource|resource\\("
    severity: MINOR

  - name: "Lazy loading routes"
    rule: "Feature routes MUST use loadComponent/loadChildren for lazy loading"
    grep_bad: "component:\\s*[A-Z]\\w+Component"
    grep_good: "loadComponent|loadChildren"
    severity: MINOR

  - name: "providedIn root for services"
    rule: "Singleton services should use providedIn: 'root'"
    grep_bad: "@Injectable\\(\\)"
    grep_good: "providedIn:\\s*'root'"
    severity: MINOR
```

```yaml
memory_leak_checks:
  - pattern: ".subscribe() without takeUntilDestroyed()"
    risk: "Observable subscription leaks on component destroy"
    fix: "Add pipe(takeUntilDestroyed(this.destroyRef)) or use async pipe"

  - pattern: "setInterval/setTimeout without cleanup"
    risk: "Timer continues after component destroy"
    fix: "Clear in ngOnDestroy or use RxJS timer with takeUntilDestroyed"

  - pattern: "addEventListener without removeEventListener"
    risk: "Event handler leaks"
    fix: "Use Renderer2.listen() or host listeners"
```

```yaml
path_aliases:
  note: "Common path aliases in Angular/Nx projects. Verify in tsconfig.json."
  common:
    - "@app/*": "src/app/*"
    - "@core/*": "src/app/core/*"
    - "@shared/*": "src/app/shared/* or libs/shared/*"
    - "@env/*": "src/environments/*"
  rule: "ALWAYS use path aliases, never relative imports crossing module boundaries"
```

---

## 3. Component Patterns

```yaml
component_pattern:
  structure: "standalone, OnPush, signals, inject()"
  template: |
    @Component({
      selector: 'app-{name}',
      standalone: true,
      changeDetection: ChangeDetectionStrategy.OnPush,
      imports: [...],
      templateUrl: './{name}.component.html',
      styleUrl: './{name}.component.scss'
    })
    export class {Name}Component {
      private readonly service = inject(SomeService);
      readonly data = signal<Type | null>(null);
    }

service_pattern:
  structure: "injectable, inject(), signals or observables"

routing_pattern:
  structure: "lazy loading, functional guards, resolvers"
```

---

## 4. Module Lookup

Base modules for Angular/Nx projects. Extend via `project.yaml`.

```yaml
modules:
  - name: shared/ui
    path: "libs/shared/ui"
    contains: "Reusable UI components"
  - name: shared/data-access
    path: "libs/shared/data-access"
    contains: "API services, state management"
  - name: shared/util
    path: "libs/shared/util"
    contains: "Utility functions, pipes, directives"

lookup_strategy:
  - check: "project.yaml → modules (if defined, merge with base)"
  - fallback: "scan libs/ directory for project.json files"
  - extract: "name, path, tags from each project.json"
```

---

## 5. File Conventions

```yaml
naming:
  component: "{name}.component.ts"
  template: "{name}.component.html"
  style: "{name}.component.scss"
  service: "{name}.service.ts"
  guard: "{name}.guard.ts"
  pipe: "{name}.pipe.ts"
  directive: "{name}.directive.ts"
  model: "{name}.model.ts"
  spec: "{name}.component.spec.ts"

folder_structure:
  feature: |
    feature-name/
      feature-name.component.ts
      feature-name.component.html
      feature-name.component.scss
      feature-name.component.spec.ts
      feature-name.routes.ts
```

---

## 6. Angular Skills Reference

For deep framework guidance, pipeline skills should load these Claude Code skills:

```yaml
skills:
  - angular-component: "component patterns"
  - angular-signals: "signal-based reactivity"
  - angular-di: "dependency injection"
  - angular-http: "httpResource, HttpClient"
  - angular-routing: "lazy loading, guards"
  - angular-forms: "signal-based forms"
```

---

## 7. Security Checks (Angular-specific)

Loaded by code-reviewer alongside core-security universal checks.

```yaml
security_checks:
  xss:
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

  csrf:
    severity: MAJOR
    patterns:
      - pattern: "HttpClient.*(post|put|patch|delete)"
        check_also: "Verify HttpXsrfInterceptor is registered in app module"
        fix: "Enable HttpXsrfInterceptor or equivalent"
    structural:
      - check: "XSRF interceptor registered in app module"
        risk: "Missing global CSRF protection"

  route_guards:
    severity: BLOCKER
    check: "Every route with sensitive data has canActivate guard"
    how_to_check: |
      1. grep -rn 'path:' in routing files
      2. For each route WITHOUT canActivate → flag as BLOCKER
      3. Skip routes: '', '**', login, register, public pages
    note: "Two-pass check avoids negative lookahead issues with basic grep"

  auth_interceptor:
    severity: MAJOR
    check: "HTTP interceptor exists for auth headers"
    grep_pattern: "HttpInterceptor|HttpInterceptorFn|intercept.*HttpRequest"
    risk: "Missing centralized auth — requests may leak or omit tokens"
```

---

## 8. Cherry-Pick Build Fix Patterns

```yaml
cherry_pick_fixes:
  description: "Common Angular build errors after cherry-pick/merge"
  TS2559:
    error: "Type has no properties in common — type mismatch after cherry-pick"
    fix: "Update call sites to match new interface"
  NG8002:
    error: "Can't bind to 'X' — unknown property after component removal/rename"
    fix: "Remove binding or replace with new component API"
  NG5002:
    error: "Parser error — template syntax broken after merge"
    fix: "Fix HTML nesting, check for unclosed tags"
```

---

## 9. API Discovery

Implements the `tech-stack.api_discovery` contract. Called by worker Phase 3.

```yaml
api_discovery:
  purpose: "Find API base URL and Swagger/OpenAPI spec URL for Angular projects"
  returns: "{ base_url: string, swagger_url: string, auth_hint: string }"

  chain:
    1_proxy_conf:
      action: "Read proxy.conf.json or proxy.conf.js"
      glob: "proxy.conf.{json,js}"
      extract: "/api target URL → base_url"
      example: '{ "/api": { "target": "https://api.dev.project.com" } } → base_url = https://api.dev.project.com'

    2_environment:
      action: "Read environment.ts or environment.development.ts"
      glob: "src/environments/environment*.ts"
      extract: "apiUrl or API_URL field → base_url"
      skip_if: "proxy.conf already found base_url"

    3_derive_swagger:
      action: "Derive swagger_url from base_url"
      try_patterns:
        - "{base_url}/swagger/v1/swagger.json"
        - "{base_url}/swagger/swagger.json"
        - "{base_url}/api-docs"
      verify: "WebFetch each pattern → first 200 with JSON content-type wins"
      timeout: "5 sec per attempt"

    4_project_yaml:
      action: "If chain 1-3 failed → read .claude/project.yaml → api.swagger_url"
      condition: "fallback only"

    5_ask_user:
      action: "If all failed → ask user for swagger URL"
      save: "Store in .claude/project.yaml api.swagger_url ONLY if field is absent"

  auth_hint:
    action: "If proxy.conf has headers or secure:false → extract auth pattern"
    example: '"secure": false → auth_hint: "No SSL verification needed"'
```
