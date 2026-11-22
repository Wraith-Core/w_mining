# w_mining

Open-source **Mining, Mineral Processing & Smelting Furnace** resource for **Wraith Framework RedM**, built 100% with **`w_lib`** interfaces and world helpers.

## Features

- **3 Classic RDR2 Mines + Wild Rock Mining** — 32 spawned ore & salt veins across **Annesburg Mine**, **Gaptooth Breach Mine**, and **Grizzlies Mine** (`mp_sca_rock_grp_l_03`), plus dynamic wild rock mining outside restricted towns.
- **Interactive Pickaxe Mining (`w_lib`)** — Walk up to any vein and press **`J`** (`w.prompt.at`). Plays authentic RDR2 mining animations (male `WORLD_HUMAN_PICKAXE_WALL` scenario + female `amb_work@world_human_pickaxe@wall@male_d@base` with attached `p_pickaxe01x`), optional `lib.skillCheck` for bonus yield & higher gem rate, and `lib.progressBar`.
- **Rich Ore & Gem Drops** — Extracts `rock`, `coal`, `clay`, `salt`, `iron`, `copper`, `lead_ore`, `sulfur`, `nitrite`, `raw_silver`, `goldnugget`, plus rare gems (`ruby`, `uncut_emerald`, `uncut_diamond`).
- **4 Smelting Furnaces & Mining Camps** — Annesburg, Valentine, Gaptooth Breach, and Grizzlies (`w.blip` + `w.prompt.at` on **`J`**):
  - **Smelting Furnace** (`lib.registerContext` + `lib.inputDialog` batch smelting): Iron Ingots, Copper Ingots, Lead Ingots, Silver Ingots, Steel Ingots, and Gold Bars (from raw nuggets or washed gold).
  - **Rock Crusher** — Break raw rocks into ores and rare gems.
  - **Gold Washing** — Refine `goldnugget` into `washed_gold` for higher smelting efficiency and value.
  - **Ore & Ingot Trader + Pickaxe Shop** — Sell individually, Sell All with confirmation (`lib.alertDialog`), or buy a Pickaxe on site.
- **Server-Authoritative & Bilingual** — Mining session validation, global node cooldowns, atomic smelting rollback on full bag, full English (`en`) and Arabic (`ar`) localization.

## Dependencies

- [`w_lib`](https://github.com/Wraith-Core/w_lib)
- [`w_core`](https://github.com/Wraith-Core/w_core)
- [`w_inventory`](https://github.com/Wraith-Core/w_inventory)

## Installation

1. Place `w_mining` inside `resources/[wraith]/w_mining`.
2. Add to `server.cfg` after `w_inventory`:
   ```cfg
   ensure w_mining
   ```
3. Customize mine nodes, smelting recipes, prices, or pickaxe wear in `config.lua`.

## License

Licensed under the **GNU General Public License v3.0 (GPL-3.0)** — see [LICENSE](LICENSE) and [CREDITS.md](CREDITS.md).
