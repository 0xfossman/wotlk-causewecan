# wotlk-causewecan
The official Addon for the Guild <Cause We Can>

## Included addon: CauseWeCanGuildTracker

This repository contains a Wrath of the Lich King (3.3.5a) addon in `CauseWeCanGuildTracker/`.

## Current functionality

### 1) Guildmate position sharing (30-second interval)
- The addon sends your character position to the guild via addon messages every **30 seconds**.
- Shared payload includes: player name, level, zone, continent, zone index, X, Y.
- Position data is refreshed on a timer to reduce performance impact.

### 2) World map guildmate markers (default map)
- Incoming position data from guildmates running the addon is stored and displayed as markers on the **default World Map**.
- Markers show **name + level**.
- Markers are rendered only if the currently shown map zone matches the shared zone/continent.
- Stale player entries are cleaned up after a timeout.

### 3) Death alert to guild chat (English)
- On player death, the addon sends an English guild chat message with:
  - character name
  - character level
  - zone/location

### 4) Guild bank activity alerts to guild chat (English)
- On guild bank log updates, the addon can post English guild chat messages for:
  - item deposits
  - item withdrawals
  - money deposits
  - money withdrawals
- A simple duplicate guard prevents repeated posting of the same latest log entry.

## Requirements / Notes
- Intended for Wrath (`Interface: 30300`).
- For full map tracking, guildmates must also run this addon.
- Uses Blizzard addon messaging and the default map frame APIs.

## Installation
1. Copy `CauseWeCanGuildTracker` into your WoW `Interface/AddOns/` folder.
2. Enable the addon on character select.
3. Ensure every guild member who should be tracked has the addon enabled.
4. Reload UI (`/reload`) or restart the game.
