# Sintezza UI

| CurseForge field | Value |
| --- | --- |
| Game | World of Warcraft |
| Class | Addons |
| Flavor and version | Forever 1.60.1 |
| Main category | Miscellaneous |
| Additional categories | Action Bars, Unit Frames, Combat, Map & Minimap |
| CurseForge relations | Sintezza Theme (Required Dependency) |
| Project license | MIT. See the repository for third-party notices. |

## Summary

Game and raid tools, configurable combat alerts, and extensions for EllesmereUI and other WoW Forever addons.

## Description

Open `/sui` to configure the game bar, raid controls, combat and stealth alerts, and map and nameplate tools. Add low-health and dungeon or raid aggro alerts, or use `/sui fonts` to pick a font for combat numbers and Sintezza alerts. The font preview displays numbers and localized text. Log out to character selection and back in after changing the font for numbers above targets.

Open **Features → Integrations** to see which addons are available and toggle the supported adaptations.

### Requirements

Install and enable [Sintezza Theme](https://github.com/ArtefactoO/Sintezza_Theme). Open `/stheme` to change the palette and fonts used by this addon's windows. Each integration also needs its target addon and any listed companion. Sintezza's own modules can be used with Theme alone.

## Integrated addons

| Addon or module | What Sintezza UI changes |
| --- | --- |
| [EllesmereUI Nameplates](https://www.curseforge.com/wow/addons/ellesmereui) | Target marking, threat outlines, aura rules, buff rows, and label outlines and shadows. |
| EllesmereUI Action Bars | Shaped cooldown and charge swipes, out-of-range shading, and XP-bar shaping. |
| EllesmereUI Cooldown Manager | Shaped swipes and compatible glows, spark visibility, and stack-based pulse, outline, or sound alerts. |
| EllesmereUI Unit Frames, Raid Frames, and Resource Bars | Corner radius, borders, and dimensions for supported frames and bars. |
| EllesmereUI Aura Buff Reminders | Compatible glows follow the icon shape. |
| EllesmereUI Damage Meters | Keep one decimal place on supported values below 1 in Forever. |
| EllesmereUI Forever Essentials | Talent and spellbook shortcuts use the EllesmereUI route when available. |
| EllesmereUI Blizzard Skin and [Mastercraft](https://www.curseforge.com/wow/addons/mastercraft) | Retain the EllesmereUI font, size, and outline on tooltip lines added by Mastercraft and other compatible addons. |
| EllesmereUI shared glow and combat font | Use its glow on Sintezza panels and apply the Sintezza combat-font override when enabled. |
| [DandersFrames](https://www.curseforge.com/wow/addons/danders-frames) | Separate party and raid borders, rounded corners, and absorb-bar spacing for supported glow presets. |
| [Does It Die Advanced](https://www.curseforge.com/wow/addons/does-it-die-advanced) + EllesmereUI | Clip DoT forecasts to the rounded target frame or supported nameplate. |
| [TacoTip](https://www.curseforge.com/wow/addons/tacotip-gearscore) | Match the item-level and GearScore footer to the theme font on Forever. |
| [LibSharedMedia](https://www.curseforge.com/wow/addons/libsharedmedia-3-0) and [SharedMediaAdditionalFonts](https://www.curseforge.com/wow/addons/shared-media-additional-fonts) | Add compatible fonts to Sintezza pickers, share frame textures, and register selected Cyrillic fonts for DandersFrames. |
| [FontMagic](https://www.curseforge.com/wow/addons/fontmagic), FontMagicCustomFonts, and Sintezza UI Local Fonts | Detect FontMagic's combat-number override and expose available personal font slots. |
| [Lueur](https://www.curseforge.com/wow/addons/lueur) | Apply its outside-combat highlighting options and restore the previous values when disabled. |
| [OpenMap](https://www.curseforge.com/wow/addons/openmap) | Show party positions and personal waypoints on the stitched world map. |
| [Muddy Boots](https://www.curseforge.com/wow/addons/muddy-boots) and ForeverCore map tabs | Place Muddy Boots below the native and ForeverCore tabs when stacking is enabled. |
| [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) and [WaypointUI](https://www.curseforge.com/wow/addons/waypointui) | Route to a Sintezza waypoint, show walking dots and supported transport timers, and clear compatible navigation when clearing the waypoint. |
| [OpenXP](https://www.curseforge.com/wow/addons/openxp-free-leveling-guides-for-wow-forever), [QuestieDB](https://www.curseforge.com/wow/addons/questiedb), and [RestedXP](https://www.curseforge.com/wow/addons/restedxp-guide) | Localize supported OpenXP labels on the Russian client, supplement names from Questie when available, and route to the current OpenXP step with Shortest Path. An active RestedXP guide keeps its own route. |
| [FlowUp](https://www.curseforge.com/wow/addons/flowup-forever), [ForeverGuide](https://www.curseforge.com/wow/addons/foreverguide), and [TomTom](https://www.curseforge.com/wow/addons/tomtom) | Use supported single guide destinations as Sintezza waypoints. The TomTom-compatible fallback is used when standalone TomTom is absent. |
| [Sintezza Rivals](https://github.com/ArtefactoO/Sintezza_Rivals) and [Sintezza Execute](https://github.com/ArtefactoO/Sintezza_Execute) | Dock the Rivals map toggle below the party-map button. Execute can import the old Sintezza UI marker's appearance. |

**EllesmereUI nameplate example.** Set an aura rule for your specialization, then choose whether it colors the health bar, border, or supported text. A rule can require two debuffs or highlight the refresh window for a single DoT. Enable a separate outline for open-world aggro so the threat state stays visible alongside the aura color.

**OpenXP and Shortest Path example.** Enable the Sintezza waypoint and guide following in Shortest Path. When OpenXP advances to a supported step with a destination, Sintezza can pass that point to Shortest Path and use its walking route. The active OpenXP pointer can be hidden during routing and restored when the route ends.

<!-- Changelog field -->

### Changelog

[View the release history on GitHub](https://github.com/ArtefactoO/Sintezza_UI/blob/main/CHANGELOG.md).

Source, installation details, and credits are available on [GitHub](https://github.com/ArtefactoO/Sintezza_UI).
