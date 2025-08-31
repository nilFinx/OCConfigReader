# OCConfigReader

Reads through one's config.plist, and returns informations, oddities, etc

## How to run

You need newer version of Lua (Lua 5.1/JIT is not supported! Sorry!)
```lua main.lua /path/to/config.plist```
If you are using most Unix based OSes(includes Linux and macOS, not Windows), you can also use this
```./main.lua /path/to/config.plist```

## FAQ

### What are these extra files?

If alt-detection-methods.txt is being pushed - MAKE AN ISSUE IMMEDIATELY, please. This file is not meant to be seen in public.
proppy.lua should be hidden too

smbios-message-parser - It is a script to convert /r/Hackintosh Paradise's #smbios channel messages to a JSON file, for Min/Max macOS version info.

All plist files are some kind of OpenCore config, for testing the tool. You can try it for yourself!

.gitignore - For newbies, this file has a list of files that I want to keep it hidden from public eyes. You can add it for your own project, to make sure that your Discord token won't be public, for example! (Only if you store your token within a separate file - be warned.)

exampleplugin.lua - Example plugin

### Is this gatekeeping?

Absolutely not. This tool is primarily for a community full of people who are willing to do their own stuff, instead of always relying on others. If you want your hands to be held, you could go to Olarila forms or other places - definitely not /r/Hackintosh Paradise, the Discord server.
r/hackintosh, the subreddit appears to allow OpCore Simplify at the time of writing(although OpenCore Configurator was banned)

To be honest, hunting for these kind of tools and modifying the plist to avoid detection is way worse than what we do - We're just trying to help somebody who wants to learn, and tool creators are trying to force us to help somebody who just wants macOS without knowing how to maintain the install.

Hackclub also discourages vibe coding, so people can actually learn, and many events encourages more work, instead of being lazy

To summarize my thoughts, please head to r/hackintosh if you want to use auto tools, we just don't want to help absolutely clueless users, who are just looking to get macOS on their unsupported machines(Yes, the compatibility checker exists, but it's their choice to ignore it)

### Is LuaJIT supported?

Unfortunately, no. This project requires a feature that only newer Lua supports. (please don't make an issue aobut this - I already know why, and I'm considering about supporting it in future.)

### An error occured while parsing

Verify that none of the stuff are dragged around(OCValidate can help with this), and make an issue.

### I get (n) total detections, but the detection count is lower?

Intentional! Some checks are hidden, because it is meant to be a joke check.

### Can I make a feature/detection request?

Yes! If I don't consider it to be too useful, I will ask you to make it a plugin instead of making a PR here though.
Also, autotool detection request is completely banned right now. Do not make a PR about it!

### Credits

[jonathanpoelen](https://github.com/jonathanpoelen) created the XML parser

[1Revenger1](https://github.com/1revenger1) created the SMBIOS collection, and [CorpNewt](https://github.com/corpnewt) kept it updated

[rxi](https://github.com/rxi) created the JSON library

[lzhoang2801](https://github.com/lzhoang2801) for being an asshole :3
