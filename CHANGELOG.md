# SimpleHeal Changelog

## v1.7.1
- Fixed: range fade now correctly fades players in another layer/phase or across the map (battlegrounds). Players the spell check cannot answer for use Blizzard's API range check instead of being assumed reachable
- GCD sweep now only animates on the frame you last cast from, not all frames
- New option "Hide tooltips over frames" (default on): suppresses unit tooltips - including from tooltip addons like GearScore - while the mouse is over a SimpleHeal frame
- Fixed: role icons and role-based layouts now work on battlegrounds (the game auto-assigns everyone DAMAGER there, which hid healer/tank icons and lumped everyone into the DPS column)

## v1.7.0
New features:
- Hover-cast keys (Clique-style): bind up to 5 keyboard keys (e.g. F1 or SHIFT-Q) that cast on the frame under your mouse - no clicking needed, works in combat
- Scroll wheel is now part of the binding list: pick "Wheel Up"/"Wheel Dn" as the button, with any modifier (Ctrl/Alt scroll now possible). Old scroll spells migrate automatically
- Low HP warning: pulsing red border on players below 30% health (toggleable)
- GCD indicator: small cooldown swirl on frames while your global cooldown runs (toggleable)
- Debuff stacks and remaining time shown next to the dispellable debuff icon
- Feign Death shows "FD" instead of DEAD - no more wasted rezzes on hunters
- Spacing slider: gap between frames (0-10px)
- Range check spell setting: pick which spell measures range fade, or leave empty for auto-detection (macros are parsed too)

UI simplifications:
- Save button removed - everything applies instantly, the button is now just "Close"
- Display checkboxes grouped under Elements / Style headers
- Sliders arranged two per row - shorter panel
- "Reset" renamed to "Reset spells" with a clarifying tooltip
- Hover-cast shows 3 rows with "+ 2 more" to expand
- Binding counter on the add button, e.g. "+ Add binding (5/20)"

Fixes:
- Range fade now works when left click is a macro or "target"
- Buff tracking fields allow 255 characters

## v1.6.1
- Fixed: casting on an out-of-range player no longer falls back to healing yourself (all casts now use hard @unit macro conditionals)
- Grid layout rework: two grid modes - groups as rows or groups as columns. Players are sorted by raid subgroup in stable roster order, so frames no longer shuffle around during battlegrounds
- Binding spell fields now allow 255 characters (was 40) - room for full macros
- Up to 20 click bindings in a scrollable list
- Fixed: Blizzard raid/party frames reappearing on every group change
- Fixed: missing-health text overlapping HoT icons in two-line text mode (now centered)

## v1.6.0
- New three-tab settings panel: Spells / Display / Advanced
- Health text options: missing health, percent, or both
- "Pets in own group" option - pets in their own column (right of DPS) or row instead of below owners
- Auto Profile for arena (takes priority over party/raid)
- Macro bindings: type "/cast [@unit,dead] Rebirth; [@unit,nodead] Swiftmend" in a spell field (@unit is replaced per frame). Also "target" and "menu" as special values
- Two-line text option: name on top, missing health below (great for square frames)
- Buff indicators now turn orange when a tracked buff has under 2 minutes left
- "Track buffs from any class" option - track buffs you cannot cast yourself
- Auto Profile: automatically switch profile in party, raid and arena
- Hide Blizzard frames now also hides the classic party frames
- 8 new display toggles: mana bar, HoT icons, smooth bars, OOC indicator, aggro border, role labels, range fade, minimap button (all default on)
- Test mode overhaul: fake players grouped by role with labels, role icons, pets and ticking HoT icons - damage and healing is simulated live
- Every setting updates the test frames instantly
- Duplicate binding warning lists all conflicts

## v1.5.1
- Safer settings migration: when upgrading from pre-1.4, ALL characters now inherit your previous setup (previously only the first character to log in got it)
- New command /sh copy <name> - copy all settings from another character (use this if a character lost its setup after the 1.4 per-character change)
- Duplicate binding warning: red text in the settings panel and a chat warning when two bindings use the same modifier+button (all conflicts listed)
- On duplicate bindings the first one always wins - a new row can never overwrite an existing spell
- New command /sh bind - prints active bindings and frame attributes for troubleshooting

## v1.5.0
- Fully flexible click bindings (Cell/HealBot style): bind any spell to any mouse button (Left, Right, Middle, Button 4, Button 5) with any modifier (None, Shift, Ctrl, Alt)
- Add up to 10 click bindings with the "+ Add binding" button, remove with X
- Bindings apply instantly when edited (out of combat)
- Existing bindings migrate automatically to the new system
- New import/export format (old strings still import fine)

## v1.4.0
- Updated for patch 2.5.6 (Interface 20506)
- Settings are now saved per character (existing settings migrate to the first character you log in with)
- Role icons - tank/healer icon next to the name (toggleable)
- Blizzard-style tabs on the settings panel
- Live spell validation - names turn green (known) or red (unknown) as you type
- Spell name autocomplete from your spellbook in all spell and buff fields
- Unified dropdown style for preset, profile and spec selectors
- Spell icon preview next to buff tracking fields
- Divider between click and scroll wheel bindings
- Smooth animated health bars
- Health as percent option
- Skull icon on dead players
- Icon size slider for HoT icons and buff indicators
- Toggle for the SimpleHeal title on the drag handle

## v1.3.1
- Major performance overhaul: unit events now update only the affected frame instead of all frames (~90% less CPU in raids)
- Single buff scan per frame update instead of six separate loops
- Cached spellbook lookups
- Target highlight - white border around your current target
- Color mode option: class-colored bars or dark bars with class-colored names (HealBot style)
- Spell name validation on save - warns about typos or unlearned spells

## v1.3.0
- Two-tab settings panel: Spells & Profiles / Settings
- Bar texture themes (Minimalist, Default, Flat, Blizzard, Smooth)
- Layout modes: columns by role, rows by role, or compact grid
- Ctrl/Alt click modifiers - 4 extra spell bindings
- Font size slider for frame text
- Show/hide pets checkbox
- Test mode (/sh test or Test button) - preview with 15 fake players
- Mouseover highlight on frames
- Dead/offline players sorted last in grid layout
- Presets and checkboxes now apply instantly (no Save needed)
- Tooltips on all settings controls
- Welcome message with quick-start guide on first login
- All sliders update frames live while dragging
- Performance: cached lookup tables, class colors and buff parsing
- Fixed own pet not showing in party mode

## v1.2.0
- Added "Only show in group/raid" option
- Added opacity slider
- Added name truncation for long names
- Added out-of-combat indicator
- Added import/export of spell setups
- DPS splits into multiple columns (max 5 per column)
- Fixed profile switching not updating spells
- Fixed StaticPopup compatibility with TBC Anniversary client

## v1.1.0
- Added profile system with save/load/delete and undo support
- Added "Only show in group/raid" option
- Added settings checkboxes for lock, click-to-target, and hide Blizzard frames
- Click-to-target now also casts spells (target + cast in one click)
- Spec dropdown now shows tree names (Balance, Feral, Restoration) instead of numbers
- Auto-hide SimpleHeal and restore Blizzard frames when switching to off-spec
- Fixed combat lockdown taint errors
- Fixed GetPrimaryTree compatibility with TBC Anniversary client

## v1.0.0
- Initial release
- Click-to-heal raid/party frames with configurable spell bindings
- Left click, right click, shift+click, scroll wheel bindings
- Class/spec presets (Resto Druid, Holy Paladin, Holy/Disc Priest, Resto Shaman)
- Auto-detect class and apply matching preset on first use
- Spec-based visibility (show only for selected talent tree)
- Role-based grouping (tanks, healers, DPS in columns)
- HoT/buff icons with duration timers (class-relevant spells only)
- Missing buff indicators
- "No thorns" text on tanks missing Thorns (Druid only)
- Dispellable debuff highlight borders (filtered by class)
- Incoming heal prediction bar
- Aggro indicator
- Resurrection indicator
- AFK text
- Mana bar
- Raid target markers
- Ready check icons
- Pet frames (hunters/warlocks, shown below owners)
- Frame size sliders (width/height)
- Toggle to hide Blizzard raid frames
- Lock/unlock position
- Minimap button
- Slash commands: /sh, /sh lock, /sh target, /sh blizz, /sh reset
