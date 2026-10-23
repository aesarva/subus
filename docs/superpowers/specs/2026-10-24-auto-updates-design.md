# Subus: автообновления и первый релиз 1.0.0

Дата: 2026-10-24
Статус: черновик на ревью
Основа: автообновления Ochre (`~/projects/ochre/docs/superpowers/specs/2026-10-24-auto-updates-design.md`, выпущены в Ochre 1.1.0). Схема та же; ниже описано, чем Subus от неё отличается.

## 1. Цель

Subus сам узнаёт о новой версии, показывает это в панели и бейджем на значке в строке меню и ставит её одним нажатием: скачивание, замена приложения, перезапуск. Первый публичный релиз на GitHub, 1.0.0, уже содержит обновлятель.

**Что сказал пользователь:**

- Обновление сделать так же, как в Ochre.
- Залить на GitHub и выпустить релиз.
- Версия первого публичного релиза — 1.0.0.
- Вне панели обновление показывает маленький бейдж на значке.

**Критерии успеха:**

- Через сутки после публикации релиза запущенная копия показывает строку «Доступна версия X» в панели и бейдж на значке.
- Одно нажатие «Установить и перезапустить» приводит к запущенной новой версии. Окон Sparkle и второго нажатия нет. Исключение — системный запрос пароля администратора, если у пользователя нет прав записи туда, где лежит Subus: этот запрос показывает macOS. Если его отменить, обновление остаётся предложенным (`installationCanceled`, как в Ochre).
- Обновление, не подписанное нашим ключом EdDSA или Developer ID, не устанавливается.
- Песочница остаётся включённой. Список entitlements расширяется только исключениями, которых требует Sparkle (§4.2).
- 1.0.0 подписан Developer ID, нотаризован и открывается без обхода Gatekeeper.

**Не цели:**

- дельта-обновления и бета-канал;
- «Пропустить версию»;
- список изменений внутри приложения;
- обновление копий, собранных до 1.0.0: в них нет обновлятеля.

## 2. Подход

Sparkle 2, ровно 2.10.0, как в Ochre. Интерфейс свой: класс, реализующий `SPUUserDriver`.

- **Sparkle отвечает за:** проверку ленты, скачивание, подписи (EdDSA и Apple code signing), замену бандла и перезапуск.
- **Subus отвечает за:** показ состояния и ответы на запросы Sparkle.

Код Ochre переносится почти без изменений: модель состояния, драйвер, контроллер, лента и шаги релиза. Отличия от Ochre:

| | Ochre | Subus |
| --- | --- | --- |
| Песочница | нет | есть: служба запуска установщика Sparkle и исключения mach-lookup (§4.2) |
| Сборка | SwiftPM, `build-app.sh` собирает бандл сам | XcodeGen и xcodebuild: Sparkle подключается в `project.yml`, Xcode встраивает фреймворк |
| Минимальная macOS | 26 | 14: без `.glassProminent`, кнопки по DESIGN.md |
| Строки | только русский | ключи на английском, перевод в `Localizable.xcstrings` |
| Сигнал на значке | точка | бейдж (§3.4): в центре значка Subus уже есть фирменная оранжевая точка |

## 3. Компоненты

| Файл | Ответственность |
| --- | --- |
| `Packages/SubusCore/Sources/SubusCore/Updates/UpdateState.swift` | `UpdateState`, `UpdateEvent`, `UpdateModel` и `UpdateLocation` — перенос из Ochre без изменений поведения. Не зависит от Sparkle. Покрыт тестами. |
| `Packages/SubusCore/Sources/SubusCore/Updates/UpdateErrors.swift` | Разбор кодов ошибок Sparkle — перенос из Ochre. |
| `App/Updates/AppUserDriver.swift` | `SPUUserDriver`: переводит вызовы Sparkle в `UpdateEvent` (как `PanelUserDriver` в Ochre). Предложение снимается и проверяется заново через сутки. `showUpdateInFocus` открывает панель. |
| `App/Updates/UpdateController.swift` | `@MainActor @Observable`. Владеет `SPUUpdater` и драйвером, публикует `model`. Методы: `start()`, `install()`, `checkNow()`. Свойство `automaticallyChecks`. Отладочная лента `-UpdateFeedURL`. |
| `App/Panel/Components/UpdateRow.swift` | Строка над подвалом панели, на вкладках и на карточке подписки. |
| `App/StatusItem/MenuBarIcon.swift`, `StatusItemController.swift` | Бейдж на значке, пока `model.showsBadge`; VoiceOver добавляет «доступно обновление». |
| `App/Settings/GeneralTab.swift` | Раздел «Обновления»: переключатель «Проверять обновления автоматически», кнопка «Проверить сейчас» и под ней результат («Установлена последняя версия», ошибка, «Доступна версия X»). |
| `App/Settings/AboutTab.swift` | Текст о сети упоминает проверку обновлений на GitHub. |

### 3.1 Состояние

`UpdateState`: `idle`, `checking`, `upToDate`, `available(version, notesURL)`, `downloading(version, progress)`, `installing(version)`, `failed(message)`, `needsMove`.

События и переходы — как в Ochre (`UpdateModel.apply`):

- фоновая ошибка → `idle`;
- ошибка ручной проверки, скачивания или установки → `failed`;
- `dismissed` сохраняет `available`, `failed` и `upToDate`;
- успешная фоновая проверка снимает старые `failed` и `upToDate`;
- прогресс считается целыми процентами, не больше 1; при неизвестной длине — `nil`;
- `showsBadge` в состояниях `available`, `downloading`, `installing`.

### 3.2 Драйвер

Поведение как в Ochre, §3.2:

- разрешение на проверки отвечается «автоматически, без профиля системы»;
- `showReadyToInstallAndRelaunch` сразу отвечает `.install`;
- `showUpdateInstalledAndRelaunched` подтверждается сразу;
- ошибки и «обновлений нет» переводятся в события и подтверждаются сразу;
- через 5 секунд повторяется `retryTerminatingApplication`, если приложение не закрылось.

Отличия Subus:

- Перед установкой Subus закрывает окна редактора без вопросов. Несохранённая форма теряется — так же, как при «Выход».
- Окно «Год» и настройки закрываются вместе с приложением.

### 3.3 Строка в панели

Над подвалом панели (`PanelFooter`), под разделителем, с отступами 16 pt. Типографика и цвета — по DESIGN.md: шрифт 12 pt, вторичный текст `.secondary`. Строка видна и на вкладках, и на карточке подписки.

| Состояние | Строка |
| --- | --- |
| `available` | Бейдж-точка, «Доступна версия 1.1», ссылка «Что нового» справа. Ниже — кнопка «Установить и перезапустить» на всю ширину, `.borderedProminent`, `controlSize(.large)`, цвет `Brand.accent`. |
| `downloading` | «Скачивание 1.1» и полоса прогресса (неопределённая при `nil`). |
| `installing` | Маленький `ProgressView` и «Установка…». |
| `checking` | «Проверка обновлений…», вторичным цветом. Бывает только после ручной проверки или «Повторить». |
| `failed` | «Не удалось обновить» (текст ошибки во всплывающей подсказке) и справа «Повторить». |
| `needsMove` | «Перенесите Subus в «Программы», чтобы получать обновления», вторичным цветом, в несколько строк. |
| `idle`, `upToDate` | строки нет; `upToDate` видно только в настройках. |

Английские строки: "Version \(version) is available", "What's New", "Install and Relaunch", "Downloading \(version)", "Installing…", "Checking for updates…", "Couldn't update", "Try Again", "Move Subus to Applications to get updates".

### 3.4 Бейдж на значке

Точка диаметром 5 pt системного акцентного цвета (`NSColor.controlAccentColor`) в правом нижнем углу кадра 18×18 pt. Вокруг неё — вырез шириной 1,5 pt в кольце: точка не сливается с линией кольца. Акцентный, а не фирменный оранжевый: оранжевая точка в центре — часть знака и есть всегда, а бейдж должен читаться как отдельный сигнал.

- Бейдж есть в состояниях `available`, `downloading` и `installing`, и со счётчиком дней, и без него.
- VoiceOver значка: «Subus, доступно обновление»; со счётчиком метка дополняется той же фразой.
- Точную геометрию проверяем на снимке в светлой и тёмной строке меню, в 1× и 2×.

## 4. Сборка, подпись, песочница

### 4.1 Сборка

**`project.yml`:**

- пакет `Sparkle`: `url: https://github.com/sparkle-project/Sparkle`, `exactVersion: 2.10.0`;
- зависимость цели `Subus` с `embed: true`.

**`scripts/build-app.sh`:** после `ditto` бандла вложенный код Sparkle переподписывается изнутри наружу:

1. `XPCServices/Installer.xpc`;
2. `Autoupdate`;
3. `Updater.app`;
4. сам фреймворк;
5. приложение с `--entitlements`, как сейчас.

`Downloader.xpc` удаляется из бандла: у Subus уже есть `network.client`, и Sparkle скачивает в процессе приложения. Флаги подписи:

- у Developer ID — `--options runtime --timestamp`;
- в конце — `codesign --verify --deep --strict`.

**Ad-hoc сборка.** Ochre выяснил, что ad-hoc подпись без Team ID с hardened runtime не загружает Sparkle.framework: library validation отвечает «different Team IDs». Поэтому:

- `build-app.sh` с подписью `-` подписывает без `--options runtime`, как Ochre;
- в `project.yml` `ENABLE_HARDENED_RUNTIME` = `YES` только для Release, в Debug — `NO`. Песочница остаётся в обеих конфигурациях.

`make build`, `make run` и `make snapshots` собирают Debug и не проходят через `build-app.sh`.

**Переподпись из `xcodebuild`.** Встраивание через Xcode не заменяет переподпись вложенных helpers. `Downloader.xpc` удаляется до подписи фреймворка и приложения. Каталог `XPCServices` целиком не удаляется: `Installer.xpc` нужен.

### 4.2 Песочница

Sparkle 2 в песочнице устанавливает обновление через службу запуска установщика.

- **Info.plist:** `SUEnableInstallerLauncherService = YES`.
- **`Subus.entitlements`:** `com.apple.security.temporary-exception.mach-lookup.global-name` со строками `io.github.aesarva.Subus-spks` и `io.github.aesarva.Subus-spki`. Значения литеральные: `build-app.sh` подписывает файлом entitlements напрямую, и `$(PRODUCT_BUNDLE_IDENTIFIER)` там не раскрывается.

Остальные entitlements не меняются. README и SECURITY.md перечисляют новый ключ и объясняют, зачем он нужен.

### 4.3 Info.plist и номер сборки

**Info.plist:**

- `SUFeedURL` = `https://github.com/aesarva/subus/releases/latest/download/appcast.xml`;
- `SUPublicEDKey` — публичный ключ Subus (§5);
- `SUEnableAutomaticChecks` = `YES`;
- `SUScheduledCheckInterval` = `86400`.

**Номер сборки** `CFBundleVersion` — по-прежнему число коммитов. Sparkle сравнивает версии по нему, поэтому релиз всегда собирается из `main`.

**Отладка:** `-UpdateFeedURL <url>` через `SPUUpdaterDelegate.feedURLString(for:)`, только из аргументов запуска.

## 5. Ключи и релиз

**Однократно:**

1. Создать ключ: `generate_keys --account io.github.aesarva.Subus`. Пара EdDSA отдельная от Ochre. Приватный ключ хранится в связке ключей, публичный записывается в Info.plist.
2. Сделать резервную копию: `generate_keys --account io.github.aesarva.Subus -x <файл>`. Файл пользователь уносит с этого Mac. Без копии после потери ключа сменить его можно только релизом, подписанным тем же Developer ID (правила ротации Sparkle). Если утеряны и ключ, и сертификат, установленные копии не примут ни одного обновления.

**Нотаризация.** Профиля `Subus` в связке ключей нет. Учётные данные notarytool привязаны к Apple ID и команде, а не к приложению, поэтому годится профиль `Ochre`. `release.sh` по-прежнему читает `NOTARY_PROFILE`, и релиз запускается с `NOTARY_PROFILE=Ochre`.

**`release.sh`.** После нотаризации и скрепления DMG вызывается `scripts/make-appcast.sh` — перенос из Ochre. Он печатает `dist/appcast.xml` с одним элементом:

- `sparkle:version` (номер сборки), `sparkle:shortVersionString`, `pubDate`;
- `sparkle:minimumSystemVersion` = `14.0`;
- ссылка на страницу релиза `https://github.com/aesarva/subus/releases/tag/v<версия>`;
- `enclosure` на `…/releases/download/v<версия>/Subus-<версия>.dmg` с подписью `sign_update --account io.github.aesarva.Subus` и длиной.

`sign_update` берётся из `build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/` — это каталог `build-app.sh`. У `make build` каталог другой: `build`.

**Релиз 1.0.0:**

1. На `develop`:
   - `MARKETING_VERSION` = `1.0.0` в `project.yml` и `VERSION` в `Makefile`;
   - в CHANGELOG `## Unreleased` становится `## 1.0.0 — <дата>`, туда же пункт об автообновлениях;
   - `make test`, `make snapshots`.
2. Слить в `main` с `--no-ff`, поставить тег `v1.0.0`.
3. `NOTARY_PROFILE=Ochre scripts/release.sh 1.0.0`.
4. Запушить `main` и тег, перемотать `develop` на `main`, запушить `develop`.
5. `gh release create v1.0.0` с файлами `Subus-1.0.0.dmg`, `Subus.dmg` и `appcast.xml`. Заметки к релизу — раздел 1.0.0 из CHANGELOG.
6. В README (EN/RU) ссылка на DMG последнего релиза. Раздел про обход Gatekeeper убирается: сборка нотаризована.

Тег 0.1.0 не ставится: 0.1.0 публично не выходил. Его раздел в CHANGELOG остаётся как история.

## 6. Ошибки

- **Нет сети при фоновой проверке:** молча, следующая попытка по расписанию.
- **Ошибка при ручной проверке, скачивании или установке:** `failed` с текстом Sparkle и «Повторить».
- **Неверная подпись:** Sparkle отказывает, показ как выше.
- **Запуск из DMG или после App Translocation:** `needsMove`, Sparkle не запускается. Это проверка `UpdateLocation` до `updater.start()` и коды 1003/1005.
- **Песочница не пускает к службе установщика** (неверные исключения mach-lookup): `failed`. Сквозная проверка (§7) ловит это до релиза.

## 7. Тесты и проверка

**Модульные тесты.** `Packages/SubusCore/Tests/SubusCoreTests/UpdateStateTests.swift` переносит тесты Ochre:

- фоновая ошибка → `idle`, ручная → `failed`;
- прогресс с неизвестной длиной и ограничение единицей;
- `dismissed` сохраняет `failed`;
- `backgroundCheckSucceeded`;
- `UpdateLocation`;
- `UpdateErrors`.

**Снимки** (`make snapshots`, свет/тьма × en/ru):

- панель в `available`, `downloading`, `failed` и `needsMove`;
- значок с бейджем, со счётчиком и без;
- раздел «Обновления» в настройках.

`SNAPSHOT_EXPECTED` растёт на число новых снимков.

**Сквозная проверка вживую до релиза.** Обе сборки — как релиз: Developer ID, песочница, нотаризация и скрепление. Часть политик подписи Sparkle проверяет только между нотаризованными сборками.

1. Номер сборки задаётся переменной `BUILD_NUMBER`; без неё он по-прежнему равен числу коммитов. Старая сборка получает номер N−1, новая — N, то есть релизный DMG 1.0.0. Лента подписывается ключом Subus и раздаётся с `127.0.0.1`.
2. Старая копия лежит в `/Applications` и запускается с `-UpdateFeedURL`.
3. Проверяется:
   - строка и бейдж появились;
   - «Установить и перезапустить» скачивает и перезапускает;
   - у запущенной копии номер сборки N;
   - данные на месте.
4. Негативный случай — несовпадение EdDSA. После `sign_update` в копию DMG дописывается байт; лента ссылается на изменённый файл со старой подписью и длиной исправленного файла. Обновление отклоняется, строка показывает «Не удалось обновить».

На macOS 14 вживую не проверяем: такой машины нет. Минимальная версия закреплена в `LSMinimumSystemVersion` и в ленте.

**Независимая проверка Codex** — на каждом этапе.

## 8. Документация

- **README (EN/RU):**
  - «Приватность и сеть»: третий случай — раз в сутки запрос ленты обновлений к GitHub, без данных о системе; отключается в настройках;
  - пункт об обновлениях в возможностях;
  - установка: DMG из последнего релиза, без обхода Gatekeeper;
  - entitlements: новый ключ mach-lookup.
- **PRODUCT.md:** строка о сети.
- **SECURITY.md:** entitlements и подпись обновлений.
- **CONTRIBUTING:**
  - создание ключа и резервная копия;
  - три файла в релизе;
  - `NOTARY_PROFILE`;
  - `-UpdateFeedURL`.
- **CHANGELOG:** пункт об автообновлениях в 1.0.0.
- **DESIGN.md:** строка обновления и бейдж.
