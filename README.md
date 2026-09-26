# WoW Currency

WoW Currency is a lightweight currency dashboard for Retail, Classic Era, and Mists of Pandaria Classic. 

## Screenshot

[WoWCurrency](WoWCurrency.png)

## Features

- Displays character gold on every supported client
- Lists currencies exposed by the current game client's currency API
- Searches currencies by name or category
- Filters currencies using Blizzard's categories
- Sorts by currency name, amount owned, maximum, or weekly progress
- Shows caps, weekly progress, descriptions, currency IDs, and account-wide or transferable status when those details are supplied by the client
- Provides a movable minimap button and dashboard window
- Remembers window and minimap-button positions between sessions
- Uses only Blizzard UI assets and requires no external libraries

Classic Era does not provide the same currency-list API as Retail and MoP Classic, so the dashboard displays character gold there. Additional currencies and metadata vary by client and expansion.

## Supported clients

- Retail
- Classic Era
- Mists of Pandaria Classic

## Installation

1. Download or copy the addon into the selected WoW client's `Interface/AddOns` directory.
2. Make sure the final layout is:

   ```text
   Interface/AddOns/WowCurrency.toc
   Interface/AddOns/WoWCurrency.lua
   ```

3. Fully restart World of Warcraft if the addon was installed while the game was running. `/reload` does not discover newly installed addons.

## Usage

Left-click the minimap button to open or close the dashboard. Drag the button around the minimap to reposition it, or drag the dashboard to move the window. Right-click the minimap button to hide it.

Hover over a currency row to see the details available from the game client.

## Commands

- `/wcurrency` or `/wowcurrency` — toggle the dashboard
- `/wcurrency minimap` — restore the minimap button after hiding it
- `/wcurrency reset` — reset the window and minimap-button positions
- `/wcurrency help` — print the command list
