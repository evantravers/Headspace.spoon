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

local m = {
  name = "Headspace",
  version = "2.0",
  author = "Evan Travers <evantravers@gmail.com>",
  license = "MIT <https://opensource.org/licenses/MIT>",
  homepage = "https://github.com/evantravers/headspace.spoon",
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
      if not m.allowed(hsapp) then
        hs.alert(
          "🛑: " .. hsapp:name(),
          moduleStyle
        )
        hsapp:kill()
      end
    end
  end):start()

  hs.urlevent.bind("blacklist", m.setBlacklist)
  hs.urlevent.bind("whitelist", m.setWhitelist)

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

  -- clear residual spaces
  hs.settings.clear("headspace")

  hs.urlevent.bind("setBlacklist", nil)
  hs.urlevent.bind("setWhitelist", nil)

  return self
end

m.getWhitelist = function()
  return hs.settings.get("headspace")["whitelist"]
end

m.getBlacklist = function()
  return hs.settings.get("headspace")["blacklist"]
end

m.allowed = function(app)
  local tags = hs.fs.tagsGet(app:path())

  if not tags then return true end

  if fn.contains(tags, "whitelisted") then
    return true
  end

  if m.getWhitelist then
    return fn.some(m.getWhitelist, function(tag)
      return fn.contains(tags, tag)
    end)
  else
    if m.getBlacklist then
      return fn.every(m.getBlacklist, function(tag)
        return not fn.contains(tags, tag)
      end)
    end
  end

  return true
end

function m.setBlacklist(_eventName, params)
  local l = fn.split(params["tags"])
  hs.settings.set("headspace", { ["blacklist"] = l })
end

function m.setWhitelist(_eventName, params)
  local l = fn.split(params["tags"])
  hs.settings.set("headspace", { ["whitelist"] = l })
end

return m
