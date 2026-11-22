# Changelog

## 1.6.2

- Fixed debuff rules skipping names and health numbers when aura data is restricted, and applied spell filters when creating health bar and border overlays.
- Clipped the EllesmereUI player frame's dispel overlay to the rounded health bar.
- Added a dungeons-and-raids-only option for low-health signals, shared with Sintezza Notifications.
- Ship the Sintezza UI logo with Sintezza UI and use it in the addon list, settings, minimap button, and raid check.

## 1.6.1

- Fixed the Squint icon appearing over the selected stealth effect on the first alert after login or reload.

## 1.6.0

First CurseForge package for WoW Forever 1.60.1.

- Rounded Danders borders mask native square artwork before combat so native border refreshes keep the rounded appearance.
- Danders border presets and reset synchronize the legacy gradient flag. Rounded borders and their preview preserve native inset, offsets, scale and blend mode. Restricted frames are skipped and combat changes are deferred.
- DandersFrames Cyrillic registration now requires verified complete Russian coverage and avoids repeating identical registrations.
- Removed the Sintezza Pandemic feature, preview, and saved profile settings.
- Stock Forever nameplates can wrap Blizzard-filtered buffs into up to two rows with a separate profile choice and preview.
- Aura previews keep buff icons in proportion and show the stock Blizzard layout.
- Debuff previews align icons beside the health bar and show the tapped-target state. Tapped-target priority sits with the aura rules. The spell picker includes class debuffs and previously remembered entries.
- Nameplates use one page for buff rows and debuff rules with a separate live preview for each. Removed Sintezza threat and selected-target overlays and their EllesmereUI links.
- Route preview brings new dots into view and fades passed dots with the in-game route painter.
- Settings keyboard navigation yields to the shared Sintezza color picker.
- Added optional Sintezza Perf developer measurements for transport timer calculations and map refresh counts.
- Aura rule previews draw the active EllesmereUI basic or custom border under the rule outline.
- Nameplate aura rules have a compact list next to the editor and preview. Adding a rule or condition opens its fields on demand. The sample uses the active nameplate provider and limits text coloring to EllesmereUI.
- Alerts translate saved built-in captions using the interface language.
- Removed the Lueur settings adapter. Nameplate threat and target textures use EllesmereUI when the corresponding native features are available.
- Removed nameplate text outline and shadow overrides. EllesmereUI controls the font styling.
- Frame previews read dimensions and border settings from the active EllesmereUI and DandersFrames profiles, including inherited EllesmereUI borders.
- Mist reveals its caption from 10% to 80% over 2.5 seconds, then fades the caption and cloud together on both transitions.
- Moved Unit Frames under Integrations, with live samples for the shared shape, individual frames, and DandersFrames borders.
- Added a searchable registration font list and a live text sample. Moved setting explanations to tooltips.
- Increased the time the Squint stays visible in both stealth transitions.
- Aligned the four alert tabs around the same enable switch, preview, and settings sections.
- The window uses the shared header with the version beside the title.
- Mist uses one smoke cloud and animates it together with the stealth caption.
- Removed tooltip font overrides that could make item tooltip text jump with EllesmereUI.
- Updated the stealth eye to the approved Squint design.
- Fixed opening Combat Text by initializing both preview fonts before setting their sample strings.
- Removed Runic seal, Embers, and Fissure from alerts. Profiles using these styles fall back to the default for each alert.
- Mist uses three larger layers of rolling smoke.
- Simplified the resting glyphs and removed their animation tooltip.
- The settings error page uses the shared Theme section style.
- Replaced boxed settings groups with shared section headings and thin dividers, including aura and buff rule editors.
- Route previews use the live dot renderer for reveal, motion, and fade on both maps.
- Added a separate transport preview with the Shortest Path ferry pin, dock timers, and an arrival and departure replay.
- Thickened the resting letters and brought them down to the clock edge.
- The Diagnostics status rows sit on the page background under a shared Theme heading.
- Alert previews play above open windows. Alert captions fit the available width, and input hints stay inside the fields.
- The combat font preview keeps the selected font after applying it. Added a sample text field and coverage help, and moved both font toggles into one row.
- Resting letters use soft illustrated glyphs placed closer together.
- The Window and minimap section on the Home page uses the shared Theme heading and divider.
- Softened settings cards, refined the resting letters, and kept nameplate and integration help available while settings are enabled.
- Added animated cooldown and recharge examples, a solo pull countdown preview, custom route dot colors and sizes, and animated route and transport previews.
- Simplified the DandersFrames tab to one integration checkbox. Border settings remain available per frame.
- Raid checks refresh when group members change and show unknown when aura readings are inaccessible.
- Removed the map tab positioning option specific to Muddy Boots and ForeverCore.
- Left-clicking the minimap icon opens or closes the window.
- Edit the Game Bar visually by dragging icons between slots, or select a slot to move, hide, or replace its button.
- Added live previews for the Game Bar, minimap bar, raid bars, cooldown shading, and observed transport timers. Grouped map settings and previews to match the settings mockup.
- Resting letters now appear one above the other and fade together.
- Made settings search compact and increased the contrast of sidebar disclosure arrows.
- Connected window scale, opacity, and layer to the shared Theme settings.
- Restored the original rising Zz animation on the minimap bar.
- Show the minimap bar's tabs immediately and identify the friend and guild lists in layout settings.
- Added separate background color and transparency controls to both bars. Whole-bar transparency is available under General.
- Moved setting descriptions and setup hints into the Sintezza Theme help tooltips.
- Updated the project logo and in-game addon icon.
- Removed the standalone talent panel in WoW Forever. The Talents shortcut remains available on the Game Bar.
- Reorganized settings around a home page, collapsible navigation, and search. Profiles are at the bottom of System.
- Moved common minimap bar controls to the first screen and kept the detailed controls under Advanced. Preview Zz on the real minimap bar and play configured alerts from the top of their pages.
- Added a sample of Shortest Path route dots on both maps using the in-game animation. Integration rows link to the relevant settings when a module already owns the control.
- Moved the standalone talent button settings into the game bar's Advanced section on Forever.
- Detect the Shortest Path renderer, OpenXP routing and localization, and OpenMap capabilities directly. The Shortest Path setting and the renderer use the same check.
- Restored animated gold dots on the minimap and world map with Shortest Path Forever v1.40.0.
- Restored the Zz pulse on the minimap bar in rest areas and in the settings preview.

## 1.5.147

- Localized the raid check window, nameplate status, and action-bar diagnostics in English and Russian.

## 1.5.146

- Returned quest marker visibility and layering to the game and the addons that draw them.

## 1.5.145

- Keep Shortest Path journeys active when it reports a new route or updates a waypoint during planning or guidance.
- Choose the visible copy of an overlapping Questie minimap marker when another copy fades or leaves range.

## 1.5.144

- Grouped overlapping Questie minimap marks for the same quest giver or turn-in when Questie's tooltip can still show every quest.

## 1.5.143

- Moved map settings into their own scrollable page and kept the party marker settings on the party page.
- Added stitched OpenMap quest markers to layering and duplicate detection. Added quest priority for supported minimap addon markers.

## 1.5.142

- Added independent map options for stacking Muddy Boots tabs below the quest log, raising quest markers, and hiding supported duplicate quest markers.

## 1.5.141

- Combat, stealth, aggro and banner signals use the shared faction crests from Sintezza Theme.

## 1.5.140

- Added optional critical health and dungeon/raid aggro alerts.
- Added separate styles, custom text, colors, size, position, display modes, and previews for the two alerts.

## 1.5.139

- Added Flag, Brackets, Fissure, and Side panel combat signal styles.
- Added Footprints, Mask, and Mist to the separate stealth signal style picker.

## 1.5.138

- Grouped integration settings by addon. Click a header to expand or collapse its settings.
- Added a separate style selector for stealth signals and preserved the previous visual during migration.
- The combat crest shows the player character's faction emblem with the theme's glow.

## 1.5.137

- Expanded **Features → Integrations** with dependency checks and controls for Sintezza's optional adapters.
- Removed the single **General** tab from **Home** and added themed help for hover animation and icon growth.
- Added five combat signal styles, editable combat and stealth messages, and optional theme colors. Existing text and manual palette choices are preserved.

## 1.5.136

- The selected Sintezza combat font takes priority over the EllesmereUI combat font while the override is enabled.
- During login, Sintezza reapplies the selected font if EllesmereUI replaces it.
- Disabling the override or using **Restore previous font** restores the previous combat font.
