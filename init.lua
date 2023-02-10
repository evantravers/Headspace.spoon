--- === Headspace ===
---
--- You need in namespace a table at `config.spaces`.
--- `config.spaces` is a table that is passed to a chooser.
---
--- You can specify blocking of apps via a `whitelist`, `blacklist`, and you can
--- say what you want to have `launch` when you launch that space.
---
--- A space with a `blacklist` will allow anything _but_ apps tagged with the
--- blacklist tags, untagged apps, or apps with a whitelisted attribute.
---
--- A space with a `whitelist` will allow **only** the apps tagged with tags in
--- the whitelist, untagged apps, or apps with a whitelisted attribute.
---
--- There is presently an interaction between the two where if an app is
--- whitelisted by a tag and blacklisted by a tag, whitelist wins.
---
--- The `launch` list tells the space to auto launch certain things at startup.
---
--- Optionally, you can define a setup function at config.spaces.<key> that is
--- run when the space is started.
---
--- OPTIONS:
---
--- # Example:
---
--- config.spaces = {
---   text = "Example",
---   subText = "More about the example",
---   image = hs.image.imageFromAppBundle('foo.bar.com'),
---
---   funcs = "example",
---
---   launch = {"table", "of", "tags"},
---   blacklist = {"table", "of", "tags"},
---   == OR ==
---   whitelist = {"table", "of", "tags"}
---
---   intentRequired = true
---   intentSuggestions = {}
--- }
---
--- config.funcs.example = {
---   setup = function()
---     hs.urlevent.openURL("http://hammerspoon.org")
---   end
--- }
---
--- The goal is to get into another space, even when working from home.
---
--- Future expansions...
--- DND status?
--- Custom Desktop Background with prompts for focus, writing, code?
--- Musical cues?

local m = {
  name = "Headspace",
  version = "1.1",
  author = "Evan Travers <evantravers@gmail.com>",
  license = "MIT <https://opensource.org/licenses/MIT>",
  homepage = "https://github.com/evantravers/headspace.spoon",
  tagged = {}
}

-- CONFIG ==============

local fn    = require('hs.fnutils')

local moduleStyle = fn.copy(hs.alert.defaultStyle)
      moduleStyle.atScreenEdge = 1
      moduleStyle.strokeColor = { white = 1, alpha = 0 }
      moduleStyle.textSize = 36
      moduleStyle.radius = 9
      moduleStyle.padding = 36

-- API =================

--- Headspace:start() -> table
--- Method
--- Starts the application watcher that "blocks" applications.
---
--- Returns:
---  * self
function m:start()
  m.watcher = hs.application.watcher.new(function(appName, event, hsapp)
    if event == hs.application.watcher.launched then
      local appConfig = m.config.applications[hsapp:bundleID()]
      local space = m.getSpace()

      if not m.allowed(appConfig) then
        hs.alert(
          "🛑: " .. hsapp:name() .. "\n" ..
          "📂: " .. space.text,
          moduleStyle
        )
        hsapp:kill()
      end
    end
    hs.urlevent.bind("switchSpace", m.switchSpace)
    hs.urlevent.bind("stopSpace", m.stopSpace)
  end):start()

  return self
end

--- Headspace:stop() -> table
--- Method
--- Kills the application watcher and any running timers.
---
--- Returns:
---  * self
function m:stop()
  -- kill any watchers
  m.watcher = nil
  -- kill any timers
  m.timer = nil

  hs.urlevent.bind("switchSpace", nil) -- remove callback
  hs.urlevent.bind("stopSpace", nil) -- remove callback
  return self
end

--- Headspace:loadConfig(configTable) -> table
--- Method
--- Adds a device to USBObserver's watch list
---
--- Parameters:
---  * configTable - A table containing the spaces and applications.-
---
--- Returns:
---  * self
function m:loadConfig(configTable)
  -- FIXME: Do error checking when loaded? (should be applications, etc.)
  m.config = configTable
  m.computeTagged(m.config.applications)
  return self
end

-- HELPERS =============

-- Switching spaces

m.setSpace = function(space)
  hs.settings.set('headspace', space.text)
end

m.getSpace = function()
  return hs.fnutils.find(m.config.spaces, function(space)
    return hs.settings.get('headspace') == space.text
  end)
end

m.hasFunc = function(key, func)
  return m.config.funcs[key] and m.config.funcs[key][func]
end

m.switchSpace = function(_eventName, params)
  local space = hs.fnutils.find(m.config.spaces, function(s)
    return s.text:find(params["name"])
  end)
  m.switch(space)
end

m.stopSpace = function(_eventName, _params)
  hs.settings.clear('headspace')
  return nil
end

m.switch = function(space)
  if space ~= nil then
    m.setSpace(space)

    -- launch / close apps
    if space.launch then
      m.tagsToBundleid(space.launch, function(bundleID)
        hs.application.launchOrFocusByBundleID(bundleID)
      end)
    end

    if space.blacklist then
      m.tagsToBundleid(space.blacklist, function(bundleID)
        local app = hs.application.get(bundleID)
        if app then app:kill() end
      end)
    end

    if space.whitelist then
      fn.map(m.config.applications, function(appConfig)
        if not m.allowed(appConfig) then
          local app = hs.application.get(appConfig.bundleID)
          if app then
            app:kill()
          end
        end
      end)
    end
  end
end

m.computeTagged = function(listOfApplications)
  fn.map(listOfApplications, function(appConfig)
    if appConfig.tags then
      fn.map(appConfig.tags, function(tag)
        if not m.tagged[tag] then m.tagged[tag] = {} end
        table.insert(m.tagged[tag], appConfig.bundleID)
      end)
    end
  end)
end

m.appsTaggedWith = function(tag)
  return m.tagged[tag]
end

m.tagsToBundleid = function(listOfTags, func)
  fn.map(listOfTags, function(tag)
    fn.map(m.appsTaggedWith(tag), function(appConfig)
      func(appConfig)
    end)
  end)
end

m.allowed = function(appConfig)
  if appConfig and appConfig.tags then
    if appConfig.whitelisted then
      return true
    else
      local space = m.getSpace()
      if space.whitelist then
        return fn.some(space.whitelist, function(tag)
          return fn.contains(m.tagged[tag], appConfig.bundleID)
        end)
      else
        if space.blacklist then
          return fn.every(space.blacklist, function(tag)
            return not fn.contains(appConfig.tags, tag)
          end)
        end
      end
    end
  end
  return true
end

return m
