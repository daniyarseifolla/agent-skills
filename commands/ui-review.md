---
description: "Run UI review: functional testing + Figma visual comparison. Usage: /ui-review [app-url]"
human_description: "UI ревью: тестирование в браузере + сравнение с Figma."
---

# UI Review (standalone)

Arguments: $ARGUMENTS

1. Load Skill: ui-review
2. If app URL provided → use it; otherwise detect/ask
3. Detect current branch → find Figma URLs in docs/plans/
4. Run: functional tests (agent-browser) + visual comparison (Figma) + visual-qa (screenshots)
5. Output: ui-review.md
