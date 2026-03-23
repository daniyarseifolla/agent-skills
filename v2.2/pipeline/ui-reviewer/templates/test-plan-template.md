## Test Plan: {task-key}

### Agent Groups
| # | Agent Name | Test Cases | Type |
|---|-----------|-----------|------|
| 1 | QA: Search functional | F1-F4 | functional |
| 2 | QA: Search visual | V1-V2 | visual (Figma) |
| 3 | QA: Search edge cases | E1-E3 | edge cases |
| 4 | QA: Mobile responsive | M1-M2 | responsive |

### Test Cases
Functional (F1-F8 style):
- F1: Navigate to /search → page loads, search input visible
- F2: Type "test" → results update, playlists filtered
- F3: Clear search → all results shown

Visual (V1-V5 style):
- V1: Search page (desktop) → compare with Figma frame
- V2: Search results card → per-element Figma check

Edge Cases (E1-E5 style, from qa-playbook):
- E1: Search with cyrillic "тест" → results correct
- E2: Search with empty string → no crash
- E3: Search with 500+ chars → graceful handling

Mobile (M1-M3 style):
- M1: Search page at 375px → responsive layout
- M2: Search page at 768px → tablet layout
