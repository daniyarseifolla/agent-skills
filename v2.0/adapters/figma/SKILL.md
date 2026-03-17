---
name: adapter-figma
description: "Figma design adapter. Provides design context extraction, screenshot comparison, and design token mapping. Loaded by pipeline skills when design is figma."
allowed-tools: mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot, mcp__plugin_figma_figma__get_metadata, mcp__plugin_figma_figma__get_variable_defs
---

# Adapter: Figma (design)

Implements the `design` adapter contract. Loaded when `project.yaml` has `design: figma`.

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
