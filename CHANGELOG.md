# SimpleHeal Changelog

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
