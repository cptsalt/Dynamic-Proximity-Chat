# Notice
- This mod is not polished, and I made it half asleep in a week, so expect there to be a few bugs. Feel free to report them or make a pull request to fix them.
- This mod will not work with other language or proximity mods, and it is recommended that these conflicting mods are disabled.

# About
This is a chat mod that takes very heavy inspiration from a very technically impressive server that closed some time ago; this is my attempt to recreate some of those functions from memory. It is built based on Degranon's Star Custom Chat proximity plugin, and thus requires the base mod, as well as either StarExtensiosn or OpenStarbound.
In essence, this mod searches for certain characters to dictate different modes within the message, then it determines whether or not the receiving player can see the components of the message. Quotes can be garbled or muffled, and there are modifiers for things like volume.

The mod additionally adds virtually infinite languages for roleplaying. You can create a language with a code to use in chat, which encodes any dialogue until the language is set again in the message.
Each character has a proficiency for any given language. This proficiency depends on how many language items the character has in their inventory, between 0 and 10.
Users who only know some (or none) of a language will have some of the words scrambled depending on the proficiency.

There is also an included configurable autocorrect feature. With this feature, you can add mistyped words and their intended word to a list.
When activated, the feature will scan messages you send and replace any words you've provided in the list.
You can add and remove words to a list, and can choose to turn the feature on or off (it is off by default).

Note that this mod will require everyone who interacts with you to have it, as they will not be able to see your messages without the mod.

# Requirements
This mod requires [StarCustomChat](https://github.com/KrashV/StarCustomChat) 1.8.8+ by Degranon, [StarExtensions](https://github.com/StarExtensions/StarExtensions) v.1.9.24+ by Kae and [OpenStarbound](https://github.com/OpenStarbound/OpenStarbound) 0.1.8+ or [xStarbound](https://github.com/xStarbound/xStarbound) v3.5.2.1+ by FezzedOne.

# How to use the mod:

## Chat controls:
- Actions - He does this: Default state, writing a full message without any quotes or indicators will post an action. Actions require line of sight to be received.
- Quotes - "Hello": Use "" to open and close quotes. They have a shorter range than actions, but do not need direct line of sight so long as there is open air between the sender and receiver.
- Sounds - <bang>: Use <> to open and close sounds. They are identical to quotes in function, but are intended for noises made by things, rather than people.
- Volume Control - :+/:- : Use :+ to increase the volume of a quote/sound. Use :- to decrease it. Use := to reset it. You can make noises louder/quieter four times in each direction (:++++, :----)
- Local OOC - ((Hello)): Use (()) for local OOC. Local OOC has a range, and does not require line of sight, but may not be seen if players are far away.
- Radio - {Hello}: Use {} for radio chat. This can be seen through walls, but is distinct from OOC, and supports languages.
- Emphasis - Look \*there\*: Use ** or // for emphasis (either one works). This changes nothing about the chat, but makes it anything inside of it a specific color.
- Item Emphasis - The \Titled Object\: Functionally identical to normal emphasis, but uses a different color.
- Rolling - |100|: Rolls a number between 1 and the provided maximum. The value should be consistent between players.

## Languages:
Languages in this mod work by checking player inventories for items that are created with language codes made up of some amount of letters. Depending on how many items with a given code a player has, they will understand more or less of a language.

Someone who's 90/80/50/etc% proficient will know about 90/80/50/etc% of the words in the language. This proficiency can be increased or decreased with more or fewer items in your inventory. By default, the language [!!] is universal, and everyone can understand it regardless of whether or not they have any items with the code.

Known words are unique to each player and language, and each language's scrambling seed is unique.
- For (arbitrary) example: The language [LA] will always encode "Hello" to something like "Mylli", and the language [PT] will always encode "Hello" to something like "Jotta".

Languages also have their own color for scrambled words, they also stay the same for a given language.

Using empty brackets [] will reset the active language to the player's default language, or [!!] if they do not have one.

You can have multiple default languages, the mod will find the first one in your inventory. Just remember to switch them around when you need them.
- *Note:* Language items show up in the crafting components section of your inventory, since they're components to craft dialogue, or something like that.

## Typo Correction 
You can add and remove typos from a list that's stored in your player file.

Once you've added and removed the typos to your liking, you should then use the /typotoggle or /typocheck commands to make sure the tool is active or inactive. When you add a typo and correction, the mod will scan and replace any typos that match that word before sending your message if the typo correction tool is active.
- *Note:* Typos will only be corrected as words with punctuation or spaces around them, excluding language brackets.

## Commands:
/newlangitem name (String), code (String), count (Number), default (True/False), color (#hex code) - Createse new language items for your character.
- name: One word name for the language (you must use one word, no more)
- code: The code that the language uses.
- count: The number of items you're going to spawn, between 1 and 10. 
- default: Whether or not the language is a default language, meaning it will automatically be used when no code is provided
- color: A custom color in which you'll see scrambled words of the language, otherwise they'll be random 
    - *Note:* Since this mod is clientside, only you will see the color you set for the language. If you make an item with blue, and someone else makes the same item with red, you'll see it as blue and they'll see it as red.

/addtypo typo (String), correction (String) - Adds a typo to your typo list
- typo: The mistyped word, such as "hte, adn, weast, s"
- correction: The intended word, such as "the, and, eest, a"

/removetypo typo (String) - Removes a typo from your typo list
- typo: The typo to remove
Note: Correction is not provided here, since you typically wouldn't need to remove a word based on what it corrects to.

/typotoggle - Activates or Deactivates typo correction, off by default.

/typocheck - Checks the status of the typo correction tool.

# Tips:
- [!!] can be used for the code in a language item, so it may be worthwhile to generate a set of default language items with that code in case you make others later for niche situations
- Since languages are managed with items, you can share them between players and quickly add/delete them.
- Sounds and quotes have a different volume manager, you can run a string like ":++HEY" <:--scuffle> "COME HERE!!", and the sound will have "-2" volume, while the quotes will have "+2" for both segments.
- Typos are case sensitive, though I may change this in the future. You can enter typos for caps lock or holding shift for too long, I guess.
- This mod comes with NO typos pre-made, so you'll have to configure your own. You can do this by editing your player file if you want, but only do that after you've run the add/remove/toggle command at least once.

# Planned Enhancements:
- /showtypos command to see all of your typos and corrections
- Global radio channels (difficult to do clientside)
- Global OOC chat
- Encrypted radio channels
- Automatically omitting character names from language scrambling
- Russian Support. Right now this mod won't work with non-ASCII script
