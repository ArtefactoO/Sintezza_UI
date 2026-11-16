# Changelog

## 1.5.147

- Localized the raid check window, nameplate status, and action-bar diagnostics in English and Russian.

### По-русски

- Переведены окно проверки рейда, статусы неймплейтов и диагностика панели команд.

## 1.5.146

- Returned quest marker visibility and layering to the game and the addons that draw them.

### По-русски

- Отображение и порядок квестовых меток снова определяют игра и аддоны, которые их рисуют.

## 1.5.145

- Keep Shortest Path journeys active when it reports a new route or updates a waypoint during planning or guidance.
- Choose the visible copy of an overlapping Questie minimap marker when another copy fades or leaves range.

### По-русски

- Маршрут Shortest Path сохраняется при запуске и при обновлении путевой метки во время расчета или ведения.
- Если одна из одинаковых меток Questie на миникарте гаснет или выходит за край, остается видимая копия.

## 1.5.144

- Grouped overlapping Questie minimap marks for the same quest giver or turn-in when Questie's tooltip can still show every quest.

### По-русски

- На миникарте наложенные метки Questie одного квестодателя или NPC для сдачи объединяются, если подсказка Questie показывает все задания.

## 1.5.143

- Moved map settings into their own scrollable page and kept the party marker settings on the party page.
- Added stitched OpenMap quest markers to layering and duplicate detection. Added quest priority for supported minimap addon markers.

### По-русски

- Настройки карты перенесены на отдельную страницу с прокруткой. Настройки сопартийцев остались в разделе группы.
- Приоритет и проверка дублей учитывают квестовые метки на сшитой карте OpenMap. Приоритет также применяется к поддерживаемым меткам аддонов на миникарте.

## 1.5.142

- Added independent map options for stacking Muddy Boots tabs below the quest log, raising quest markers, and hiding supported duplicate quest markers.

### По-русски

- Добавлены три переключателя карты для размещения вкладок Muddy Boots под вкладками журнала, приоритета квестовых меток и скрытия распознанных дублей.

## 1.5.141

- Combat, stealth, aggro and banner signals use the shared faction crests from Sintezza Theme.

### По-русски

- Боевой герб, герб скрытности, герб агро и знамя используют общие эмблемы фракций из Sintezza Theme.

## 1.5.140

- Added optional critical health and dungeon/raid aggro alerts.
- Added separate styles, custom text, colors, size, position, display modes, and previews for the two alerts.

### По-русски

- Добавлены отключенные по умолчанию сигналы критического здоровья и получения агро в подземельях и рейдах.
- У каждого сигнала есть свой стиль, редактируемый текст, цвета, размер, положение, режим отображения и предпросмотр.

## 1.5.139

- Added Flag, Brackets, Fissure, and Side panel combat signal styles.
- Added Footprints, Mask, and Mist to the separate stealth signal style picker.

### По-русски

- Для боевых сигналов добавлены «Знамя», «Скобы», «Трещина» и «Плашка».
- В отдельном списке стилей скрытности появились «Следы», «Маска» и «Дымка».

## 1.5.138

- Grouped integration settings by addon. Click a header to expand or collapse its settings.
- Added a separate style selector for stealth signals and preserved the previous visual during migration.
- The combat crest shows the player character's faction emblem with the theme's glow.

### По-русски

- Интеграции собраны по аддонам. Нажатие на название сворачивает или раскрывает настройки.
- Для сигналов скрытности добавлен отдельный выбор стиля. Текущий вид переносится при обновлении.
- Боевой стиль «Герб» показывает эмблему фракции персонажа с подсветкой темы.

## 1.5.137

- Expanded **Features → Integrations** with dependency checks and controls for Sintezza's optional adapters.
- Removed the single **General** tab from **Home** and added themed help for hover animation and icon growth.
- Added five combat signal styles, editable combat and stealth messages, and optional theme colors. Existing text and manual palette choices are preserved.

### По-русски

- На вкладке **Функции → Интеграции** появились проверки зависимостей и переключатели адаптеров Sintezza.
- С **Главной** убрана одиночная вкладка **Общие**. Добавлены подсказки анимации наведения и увеличения иконок.
- Для сигналов боя доступны пять стилей, редактируемые фразы боя и скрытности и цвета темы. Сохраненные фразы и ручные цвета переносятся в новую версию.

## 1.5.136

- The selected Sintezza combat font takes priority over the EllesmereUI combat font while the override is enabled.
- During login, Sintezza reapplies the selected font if EllesmereUI replaces it.
- Disabling the override or using **Restore previous font** restores the previous combat font.

### По-русски

- Выбранный в Sintezza боевой шрифт получает приоритет над шрифтом EllesmereUI при включенном переопределении.
- При входе Sintezza повторно применяет выбор, если EllesmereUI заменяет шрифт.
- При отключении переопределения или нажатии **Вернуть прежний шрифт** восстанавливается предыдущий боевой шрифт.
