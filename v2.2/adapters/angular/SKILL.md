---
name: adapter-angular
description: "Angular/Nx tech stack adapter. Provides lint/test/build commands, quality patterns, module lookup, and component conventions. Loaded by pipeline skills when tech-stack is angular."
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

## 7. Cherry-Pick Build Fix Patterns

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
