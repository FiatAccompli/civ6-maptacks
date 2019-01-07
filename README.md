# Map Tacks Plus 1.0.0 

* Adds new map tack icons.
* Enhances list interface and world view tacks.
* Fixes bugs and styling.

Based on the original Map Tacks mod by Bradd Szonye.

### Installation
To use this mod you also need to have [Settings Manager](https://github.com/FiatAccompli/Civ6Mods/tree/master/SettingsManager) ([Steam workshop version](https://steamcommunity.com/sharedfiles/filedetails/?id=1564628360)).
  * STEAM_LINK
  * LOCAL_DOWNLOAD_LINK

## Features

### New icons
Numerous new icons added to the map tack editor.  All nicely categorized and 
allows you to hide the categories you don't want.

* Districts, customized with civilization unique districts
* Improvements, including unique & bonus improvements from civilization
  abilities, city states, and governors.
* Unit actions like harvesting, repair, archaeology, and espionage
* Great people
* Wonders
* Units
* Governors
* Random other icons

For improvements and units there are configuration settings for which civ/leader 
uniques are shown.  You can show uniques only from your own civilization, 
from civs you have met, from all civs in game, or from all civs (in-game or not).

![Map Tacks editor popup](Documentation/MapTacksEditor.jpg)

### Usability improvements
* Keybinding for adding/editing a map tack (ctrl+E by default).
* Right-click to delete a tack (works on both the world-view tack and in tack list).

All new icons have tooltips, with game effects for districts and improvements.

### Scrollable map tack list 
The list dynamically resizes to show up to 15 map tacks, with a scrollbar to
manage longer lists.  It groups all named locations at the top, followed by all
unnamed locations in numerical order.

![Map Tacks list](Documentation/MapTacksList.jpg)

### Bug fixes and restyling
The mod fixes a few base-game bugs and styling problems.  It handles large
numbers of map tacks without breaking the popup list or causing performance
problems.  Unnamed markers now sort correctly when there are more than ten.
Labels and controls have more consistent alignment and spacing.  The mod
improves overlapping and stacked icons, so that closer tacks always look
closer, and the current player always appears on top in multiplayer.

### Improved pin look

The text associated with a tack is now "signposted" rather than floating randomly
above the pin making it easy to read regardless of world background.

![Map Tacks improved pin](Documentation/MapTack.jpg)


### Compatibility
The Map Tacks Plus mod does not affect saved games, so you can add it to a game in
progress or disable it without breaking your game.  In general it should override 
map pin features in other UI mods, but as with any civ 6 mods, if multiple active mods 
are touching the same files you're asking for trouble.  Map Tacks Plus is compatible
with Unique District Icons and uses the unique icons for districts as well as mods that 
add new civilizations/districts.
