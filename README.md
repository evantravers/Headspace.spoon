# Headspace

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
  }
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
