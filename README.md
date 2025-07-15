# OCConfigReader
Reads through one's config.plist, and returns informations, oddities, etc

# How to run
You need newer version of Lua(5.1 is not accepted at moment, JIT also uses 5.1)
```lua main.lua /path/to/config.plist```
If you are using most Unix based OSes(includes Linux and macOS), you can also use this
```./main.lua /path/to/config.plist```

# FAQ
## Is this gatekeeping?
Absolutely not. This tool is primarily for a community full of people who are willing to do their own stuff, instead of always relying on others. If you want your hands to be held, you could go to Olarila forms or other places - definitely not /r/Hackintosh Paradise, the Discord server.
r/hackintosh, the subreddit appears to allow OpCore Simplify at the time of writing(although OpenCore Configurator was banned)

To be honest, hunting for these kind of tools and modifying the plist to avoid detection is way worse than what we do - We're just trying to help somebody who wants to learn, and tool creators are trying to force us to help somebody who just wants macOS without knowing how to maintain the install.

## Is LuaJIT supported?
Unfortunately, no. This project requires a feature that only newer Lua supports.

## An error occured while parsing
Verify that none of the stuffs are dragged around(OCValidate can help with this), and make an issue.

