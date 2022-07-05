# Headspace

A combination Toggl client and definer of workspaces. I use it to prevent me
from keeping open distracting appliacations when I should be working.

Requires:
- A toggl API token.
  ([instructions](https://support.toggl.com/en/articles/3116844-where-is-my-api-token-located))
- [AutoLayout.spoon](https://github.com/evantravers/AutoLayout.spoon)
- A configuration table of spaces and applications. You can find mine
  [here](https://github.com/evantravers/hammerspoon-config/blob/master/init.lua).

```lua
local config = {
  spaces = {
    {
      text = "Deep",
      subText = "Work on focused work.",
      blacklist = {'distraction'},
      intentRequired = true
    },
    {
      shallow = "Communication",
      subText = "Talk to people.",
      blacklist = {'focus'}
    }
  },
  applications = {
    ['com.apple.mail'] = {
      bundleID = 'com.apple.mail',
      tags = {'distraction'},
    },
    ['com.microsoft.VSCode'] = {
      bundleID = 'com.microsoft.VSCode',
      tags = {'focus'},
    },
  }
}

hs.loadSpoon('Headspace')
spoon.Headspace:start()
               :bindHotKeys({ choose = {{'control'}, 'space'}})
               :setTogglKey('string of toggl API key')
               :loadConfig(config)
```
