---
name: adapter-figma
description: "Use when extracting design context from Figma files. Provides screenshots, comparison, and token extraction."
human_description: "Адаптер для Figma: извлечение дизайна, скриншоты, визуальное сравнение, design tokens."
allowed-tools: mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot, mcp__plugin_figma_figma__get_metadata, mcp__plugin_figma_figma__get_variable_defs
---

# Adapter: Figma (design)

Implements the `design` adapter contract. Loaded when `project.yaml` has `design: figma`.

---

## 0. Preflight Check

```yaml
preflight:
  check: "Verify Figma MCP is available before any API calls"
  method: "Attempt get_metadata with a known fileKey, or check tool availability"
  on_unavailable: |
    WARN: Figma MCP is not connected.
    Figma-dependent features will be skipped:
    - Visual comparison (ui-reviewer)
    - CSS extraction (figma-coding-rules)
    - Figma verification (/verify-figma)
    Action: Check Figma MCP connection in Claude Code settings.
  skip_signal: "figma_mcp_available: false — pass to consuming skills"
```

---

## 1. parse_urls(text)

```yaml
regex: 'https://(?:www\.)?figma\.com/(design|file|board)/([a-zA-Z0-9]+)(?:/[^?\s]*)?(?:\?node-id=([^&\s]+))?'

extract:
  fileKey: "group 2"
  nodeId: "group 3 — convert '-' to ':' in nodeId"

branch_urls:
  pattern: "figma.com/design/:fileKey/branch/:branchKey"
  action: "use branchKey as fileKey"
```

---

## 2. get_design(url)

```yaml
steps:
  - parse: "parse_urls(url) → fileKey, nodeId"
  - call: get_design_context
    params:
      fileKey: "{fileKey}"
      nodeId: "{nodeId}"
  - returns:
      screenshot: "visual reference image"
      code_hint: "Code Connect mapping or raw structure"
      component_docs: "component usage documentation"
      tokens: "design token values"
  - routing:
      code_connect_present: "use mapped component directly"
      code_connect_absent: "use screenshot as visual reference"

  - icon_detection:
      description: "Detect if node is an icon and handle SVG limitation"
      condition: "node size ≤ 32x32px OR node name contains 'icon'/'ic_'/'svg'"
      warning: |
        Figma MCP cannot export SVG code. Asset URL returns raster (PNG).
        For icons:
        1. Try WebFetch on asset URL — sometimes SVG is returned
        2. If raster → warn coder: "Icon {name} is raster-only from Figma MCP"
        3. Suggest: ask user to export SVG from Figma desktop (Select → Export → SVG)
        4. For CSS mask usage: SVG must have fill paths, not stroke-only
      fallback: "Use raster asset as <img> if SVG unavailable"
```

---

## 3. get_screenshot(url)

```yaml
steps:
  - parse: "parse_urls(url) → fileKey, nodeId"
  - call: get_screenshot
    params:
      fileKey: "{fileKey}"
      nodeId: "{nodeId}"
  - return: "image for visual comparison"
```

---

## 4. compare_visual(actual_screenshot_path, figma_url)

```yaml
steps:
  - get_figma: "get_screenshot(figma_url)"
  - get_actual: "read image at {actual_screenshot_path}"
  - compare:
      dimensions:
        - layout: "element positioning and alignment"
        - spacing: "margins, padding, gaps"
        - sizing: "width, height of key elements"
      visual:
        - colors: "background, text, border colors"
        - typography: "font size, weight, family"
        - icons: "presence and placement"
      functional:
        - missing_elements: "elements in design but absent in implementation"
        - extra_elements: "elements not in design but present in implementation"
  - severity_note: "pixel-perfect NOT required — focus on functional/visual parity"
  - return: "diff report with categorized findings"
```

---

## 5. extract_tokens(figma_url)

```yaml
steps:
  - parse: "parse_urls(figma_url) → fileKey"
  - call: get_variable_defs
    params:
      fileKey: "{fileKey}"
  - map_to_project:
      css_variables: "var(--token-name)"
      scss_variables: "$token-name"
  - return:
      colors: "{ name: value }"
      spacing: "{ name: value }"
      typography: "{ name: { size, weight, lineHeight } }"
```

---

## 6. figma_first_mode

When Jira description is empty but Figma URLs are present.

```yaml
trigger: "task.description is empty AND task.figma_urls is non-empty"

steps:
  - extract_all: "parse_urls from task"
  - for_each_url:
      - call: get_design_context
      - analyze:
          components: "identify visible UI components"
          interactions: "buttons, inputs, links, toggles"
          states: "loading, error, empty, populated"
          responsive: "breakpoints if visible in variants"
  - generate_ac:
      format: "string[] — one AC item per identified requirement"
      categories:
        - "Component rendering — {component} displays correctly"
        - "Interaction — {element} responds to user action"
        - "State handling — {state} state renders appropriately"
        - "Responsive — layout adapts at {breakpoint}"
  - return: "generated_ac[] for planner Phase 1 input"
```

---

## 7. get_metadata(url)

```yaml
steps:
  - parse: "parse_urls(url) → fileKey"
  - call: get_metadata
    params:
      fileKey: "{fileKey}"
  - return: "file name, last modified, version, editors"
```

---

## 8. Rate Limiting

```yaml
rate_limits:
  description: "Figma API has rate limits. Multiple get_design_context calls can hit them."
  guidance:
    - "Max 5 get_design_context calls per minute"
    - "For pages with 10+ elements: batch by component group, not per-element"
    - "If rate limited (429 error): wait 60 seconds, retry"
    - "Cache results: if same nodeId requested twice in one session, reuse first result"
    - "Prefer get_design_context with parent node over multiple child node calls"

  optimization:
    strategy: "Fetch parent container first, extract child values from parent's code hints"
    example: "Instead of 5 calls for header/title/subtitle/icon/button → 1 call for the card container"
```

---

## 9. Error Handling

```yaml
errors:
  invalid_file_key:
    symptom: "get_design_context returns empty or error"
    fix: "Verify fileKey from URL. Check if file is accessible (not deleted/restricted)."

  access_denied:
    symptom: "401 or 403 from Figma MCP"
    fix: "Check Figma MCP connection. User may need to re-authenticate in Figma."

  node_not_found:
    symptom: "get_design_context returns null for nodeId"
    fix: "Node may have been deleted or moved. Re-extract nodeId from current Figma URL."

  rate_limited:
    symptom: "429 Too Many Requests"
    fix: "Wait 60 seconds. Reduce call frequency. Use parent-node batching."

  empty_code_hints:
    symptom: "get_design_context returns screenshot but no code"
    fix: "Node may be a group/frame without auto-layout. Try child nodes individually."

  raster_instead_of_svg:
    symptom: "Asset URL returns PNG for icons"
    fix: "See figma-coding-rules section 4 (Icon Extraction). Ask user to export SVG."
```
