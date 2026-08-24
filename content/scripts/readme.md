# Tabletop Simulator Dynamic Content Loader

An asynchronous JSON-driven content distribution system for Tabletop Simulator (TTS). This loader fetches remote manifests and component configurations (hosted via GitHub Pages or local web servers), processes alias shorthands, attaches external Lua scripts, and hydrates TTS objects and container bags dynamically.

---

## Loader Lifecycle & Event Chains

The initialization lifecycle progresses linearly through four distinct operational phases tracked inside the global `LOADER` state machine:

```
[ Unpack Trigger ]
──► ( Registering )
──► ( Spawning )
──► ( Bagging )
──► [ Ready ]
```

Major functions and their sequence is as follows:

```
──► unpackGame(title = "Legacy of Iseria")
──► JSONLoader.read(url = "index.json")
──► onAllComponentsRegistered()
──► JsonAdapter.spawnAllComponents()
──► queueBagInsertion()
──► onBaggingComplete()
```


### Event Sequence Overview

```
unpackGame(title)
 ├── JSONLoader.read(indexUrl)
 │    └── WebRequest.get("content/index.json")
 │         └── loadComponentJson(request)
 │              ├── [STATE = "Registering"]
 │              └── loop componentPath in index.json:
 │                   └── loadComponent(path)
 │                        └── JsonAdapter.registerComponent(path, root)
 │                             ├── expandIncludesAsync() [Recursively resolves include files]
 │                             ├── registerComponentSet()
 │                             │    ├── Merge defaults, sets, items, and quantities
 │                             │    ├── expandAliases() [Converts clean JSON keys to TTS format]
 │                             │    ├── resolveAllPaths() [Normalizes relative HTTP URLs]
 │                             │    ├── Registry.addScript() [Registers external Lua scripts]
 │                             │    └── Registry.addComponent()
 │                             └── Fetch pending external Lua scripts (Async WebRequest)
 │                                  └── Wait.condition() -> checkRegisteringReady()
 ├── setDungeonGrid()
 │
 └── (Once LOADER.registering.progress >= LOADER.registering.total)
      └── onAllComponentsRegistered()
           ├── [STATE = "Spawning"]
           └── JsonAdapter.spawnAllComponents()
                ├── Phase 1: Spawn Custom_Model_Bag objects first (Locked)
                └── Phase 2: Spawn non-bag objects (Cards, Tiles, Models, etc.)
                     └── JsonAdapter.spawnComponent(entry)
                          ├── spawnObjectData()
                          └── callback_function
                               ├── if item has .bag attribute:
                               │    └── queueBagInsertion(bagId, entry)
                               │         └── Wait.condition() [Polls for bag and item existence]
                               │              └── Wait.frames() -> putObject()
                               │                   └── checkBaggingReady()
                               └── else: setLock(false)
                               
 └── (Once LOADER.bagging.progress >= LOADER.bagging.total)
      └── onBaggingComplete()
           ├── [STATE = "Ready"]
           └── unlockAllBags()

```

---



## Core Architecture Components


### Lifecycle State Machine (`LOADER`)

Tracks global setup progress and state transitions:

* **`Registering`**: Index and component JSONs are fetched; relative paths, alias shorthands, and external scripts are parsed into memory.
* **`Spawning`**: Game objects and custom containers are instantiated into the TTS world scene via `spawnObjectData`.
* **`Bagging`**: Spawned objects target designated container bags, wait for physical stability, and insert themselves via asynchronous queueing.
* **`Ready`**: Container bags are unlocked; system initialization completes.


### Runtime Registry (`Registry`)

An in-memory store managing parsed object configurations and external Lua script text:

* **`_keys`**: Map of component identifiers to fully hydrated object definitions.
* **`_types`**: Categorized index of objects grouped by TTS type (`CardCustom`, `Custom_Model`, `Custom_Model_Bag`, etc.).
* **`_scripts`**: Cache storing string contents of remote external scripts to attach to spawned entities.


### Translation Layer (`JsonAdapter`)

Normalizes high-level user JSON configurations into raw Tabletop Simulator JSON schematics:

* Deep-merges base object templates (`TTS_ObjectData`) with sets and item-level overrides.
* Converts custom unit keys (`position`, `rotation`, `scale`, `color`, `snappoints`) to official TTS fields (`Transform`, `ColorDiffuse`, `SnapPoints`).
* Calculates relative offsets for batch items (`spawnOffset`) and generates uniquely indexed duplicate entries (`quantity`).

---



## Path Resolution & Alias Shorthands

To simplify hand-written JSON manifests, `JsonAdapter` translates abbreviated schema keys into nested TTS data trees.


### Property Aliases

| High-Level Property | Targets / Structural Mapping | Notes |
| --- | --- | --- |
| **`identifier`** | `Nickname` | Object label shown in UI and used for lookup |
| **`color`** | `ColorDiffuse` | Accepts named strings (`"Red"`, `"Blue"`), Hex (`"#FF0000"`), or RGBA tables |
| **`position`** | `Transform.posX`, `posY`, `posZ` | Auto-calculated with `spawnOffset` if defined |
| **`rotation`** | `Transform.rotX`, `rotY`, `rotZ` | Applied to base transform |
| **`scale`** | `Transform.scaleX`, `scaleY`, `scaleZ` | Scaled against standard TTS bounds |
| **`snappoints`** | `SnapPoints` array | Expands `cols`, `rows`, and `grid` offsets into absolute local snap vectors |


### Component Type Mappings

| Component Type | Shortcut Keys | TTS Schema Placement |
| --- | --- | --- |
| **`CardCustom` / `DeckCustom**` | `face`, `back` | `CustomDeck["1"].FaceURL`, `BackURL` |
| **`Custom_Tile`** | `face`, `back`, `type` | `CustomImage.ImageURL`, `ImageSecondaryURL`, `CustomTile.Type` |
| **`Custom_Model` / `Custom_Model_Bag**` | `mesh`, `texture`, `normal`, `collider` | `CustomMesh.MeshURL`, `DiffuseURL`, `NormalURL`, `ColliderURL` |
| **`Custom_Assetbundle`** | `bundle`, `typeIndex`, `materialIndex` | `CustomAssetbundle.AssetbundleURL`, `TypeIndex`, `MaterialIndex` |
| **`Custom_PDF`** | `pdf` | `CustomPDF.PDFUrl` |

---



## Manifest Schemas & JSON Structure


### Global Index (`content/index.json`)

Defines all top-level entry paths to load into the registry.

```json
{
  "components": [
    "bags/dungeon_bags.json",
    "cards/hero_cards.json",
    "models/monsters.json"
  ]
}

```


### Component File with Nested Includes (`cards/hero_cards.json`)

```json
{
  "components": [
    {
      "include": "subcategories/warrior_deck.json"
    },
    {
      "set": {
        "Name": "CardCustom",
        "bag": "Hero_Deck_Bag",
        "script": "scripts/cards/card_base.lua",
        "spawnOffset": { "x": 0, "y": 0.5, "z": 0 }
      },
      "items": [
        {
          "identifier": "Paladin_Aura",
          "face": "textures/cards/paladin.png",
          "back": "textures/cards/back.png",
          "quantity": 2
        }
      ]
    }
  ]
}

```

---



## Technical Safeguards & Recovery Logic

* **Two-Phase Spawning Hierarchy**: Bags (`Custom_Model_Bag` / items with `Bag` parameters) spawn prior to standard world components. Non-bag items remain locked during instantation to prevent unwanted collision physics.
* **Asynchronous Queue Retries**: Object containment uses `Wait.condition()` polling combined with attempt bounds (`MAX_ATTEMPTS = 10`). If dynamic spawning suffers network latency or missing asset dependencies, the loader soft-fails gracefully without blocking subsequent registry operations.
* **Script Validation**: External web requests check for valid Lua formatting (`isValidLuaScript`) prior to injection, preventing silent UI failures caused by server 404/500 HTML error pages returned in HTTP bodies.

---



# Supporting Component Scripts

These specialized Lua scripts run on individual objects or container items in Tabletop Simulator (TTS), interfacing with the central `Global.lua` loader to handle user interactions, indexing, and component synchronization.

---


## Script Summaries & Usage


### `gamebox.lua` (Unpack Controller)

**Attached to:** Game Box / Starter Container

Provides the primary player interface to unpack remote content into the current session.

* **Key Features:**
* **Context Menu:** Adds an `"Unpack Game"` context menu option upon load.
* **Environment Switching:** Allows toggling between production (`PROD_URL`) and local development (`LOCAL_URL`) server endpoints prior to execution.
* **Global Trigger:** Dispatches the `Global.call("unpackGame", title)` routine.

---


### `archiveContainerBehavior.lua` (Numeric Index Search & Auto-Transfer)

**Attached to:** Storage Containers / Archive Decks / Draw Bags

Enables rapid card or component retrieval via keypress/hover interactions and automates item behavior upon entering/leaving the container.

* **Key Features:**
* **Hover + Type Draw (`onNumberTyped`):** Hovering over the container and typing a number (e.g., typing `101` searches for zero-padded name index `101`) immediately draws matching cards straight to the player's hand.
* **Multi-Search Support:** Supports retrieving either the first matching instance (`SEARCH_TYPE_FIRST`) or extracting all matching index instances simultaneously (`SEARCH_TYPE_ALL`).
* **Automatic Deck Splitting:** Automatically breaks down dropped multi-card decks into individual cards when added to the container.
* **Orientation & Dungeon Tracking:** Forces cards/tiles face-down on exit (`ENSURE_FACEDOWN_WHEN_DRAWN`) and integrates with `Global.lua` to track or unregister temporary dungeon items (`TRACK_DUNGEON_ITEMS`).


---


### `defaultCardBehavior.lua` (Registry-Aware Card Base)

**Attached to:** Standard Spawned Cards

Acts as a template wrapper for dynamically instantiated cards that need to hydrate local state from the `Global` registry.

* **Key Features:**
* **Asynchronous Registry Hydration:** Polls `Global.call("getRegistryComponentJSON", id)` with exponential frame delays until object metadata is retrieved.
* **Component Context Menu:** Registers dynamic actions (e.g., `"Announce <ID>"`) once registry data is successfully loaded.
* **Self-Contained Logger:** Features an embedded multi-level logger (`DEBUG`, `INFO`, `WARN`, `ERROR`).


---


### `narrativeCardBehavior.lua` (Booklet / Cross-Reference Integration)

**Attached to:** Narrative Cards, Quest Items, NPC Cards

Connects physical game cards directly to external narrative booklets or rulebooks spawned in the scene.

* **Key Features:**
* **Ping & Hotkey Triggers:** Intercepts player pings (`onPlayerPing`) or custom hotkeys (`"Card -> Open Book"`) when hovering over the card.
* **Booklet Sync:** Reads `component.booklet` metadata from the hydrated registry payload, locates the matching target booklet object in TTS, and invokes `book.call("openPageToId", component.identifier)`.
* **Context Menu Access:** Adds an explicit `"Open Book <BookletID>"` menu entry directly on the object.


---

Here are the summaries for the additional supporting component scripts to add to your `README.md`.

---


### `combatBagBehavior.lua` (Dungeon Item Tracking & Combat Container)

**Attached to:** Combat Draw Bags / Encounter Containers

Extends container functionality by enforcing strict tracking and cleanup behavior for active dungeon encounters.

* **Key Features:**
* **Automated Cleanup Registration:** Registers items via `Global.call("registerDungeonObject")` as soon as they leave the bag, linking them to the bag's GUID so `cleanupDungeon()` can automatically return them when the encounter ends.
* **Auto-Shuffle & Facing:** Automatically shuffles sub-bags placed inside (`SHUFFLE_ON_ADD = true`) and ensures cards/tiles drawn are placed face-down (`ENSURE_FACEDOWN_WHEN_DRAWN = true`).
* **Name Masking:** Sets drawn object names to their description (`HIDE_NAME = true`) to obfuscate hidden stats or face-up text until revealed.


---


### `combatBoard.lua` (Encounter & Cleanup Controller)

**Attached to:** Play Mat / Combat Board

Provides a central scene interaction point to reset or clear active dungeon/encounter components.

* **Key Features:**
* **Context Menu Interface:** Adds a `"Cleanup Dungeon"` right-click option directly on the game board.
* **Global Dispatch:** Triggers `Global.call("cleanupDungeon")`, executing the board-wide item sweep that returns registered dungeon items back to their origin bags or destroys dynamically cloned tokens.


---


### `summableComponent.lua` (Registry-Aware Value Summation)

**Attached to:** Gold Tokens, Resource Tiles, VP Markers

Allows players to quickly calculate cumulative numerical totals across multiple selected objects in the scene.

* **Key Features:**
* **Value Extraction (`getValue`):** Reads and parses numerical values directly from the hydrated `component.value` field in the global registry.
* **Multi-Selection Summation:** Calculates the aggregate total of all highlighted/selected objects in the player's selection box via `Player.getSelectedObjects()`.
* **Player Reporting:** Displays calculated resource totals directly in the chat window via `"Show Sum"`.


---


### `bookletBehavior.lua` (AssetBundle Page Indexer & Remote Reader)

**Attached to:** Custom AssetBundle Booklet Objects / PDF/Rulebook Guides

Allows AssetBundle-based booklets to automatically index embedded trigger effects and turn directly to specific pages based on external function calls or user keypresses.

* **Key Features:**
* **Dynamic Page Indexing (`buildPageIndex`):** Scans the AssetBundle's trigger effects (`getTriggerEffects()`) upon loading and builds an internal `PAGE_INDEX` mapping named effect labels (e.g., card IDs or section names) to zero-based animation frame indices.
* **External Invocation (`openPageToId`):** Exposes an interface function callable by other scripts (such as `narrativeCardBehavior.lua`) to instantly jump to the target ID's page via `playTriggerEffect(index)`.
* **Hover + Type Jump (`onNumberTyped`):** Hovering over the booklet and typing an index number (e.g., typing `101` searches for padded string `101`) searches non-generic trigger labels and flips the booklet directly to the matching page.
* **Asset Initialization Safeguard:** Uses `Wait.condition()` to ensure Unity AssetBundle data and trigger effects are completely loaded in TTS memory before attempting to build the page index.


---
