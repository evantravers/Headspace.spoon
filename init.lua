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
--- If you are using toggl timer, putting anything in quotes will pass that as a
--- custom description to toggl. e.g. Design "Working on jira ticket" will match
--- a space named Design, but pass a custom description to your timer.
---
--- If you want a pomodoro countdown, add a colon followed by integers. e.g. :45
--- will count down 45 minutes, then play a musical cue and prompt you to choose
--- a new space.
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
---   togglProj = "id of toggl project",
---   togglDesc = "description of toggl timer
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
local toggl = dofile(hs.spoons.resourcePath('toggl.lua'))

local moduleStyle = fn.copy(hs.alert.defaultStyle)
      moduleStyle.atScreenEdge = 1
      moduleStyle.strokeColor = { white = 1, alpha = 0 }
      moduleStyle.textSize = 36
      moduleStyle.radius = 9

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

      if not m.allowed(appConfig) then
        hs.alert(
          "????: " .. hsapp:name() .. "\n" ..
          "????: " .. hs.settings.get("headspace").text,
          moduleStyle
        )
        hsapp:kill()
      end
    end
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

  return self
end

function m:bindHotKeys(mapping)
  local spec = {
    choose = hs.fnutils.partial(self.choose, self)
  }
  hs.spoons.bindHotkeysToSpec(spec, mapping)

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

--- Headspace:setTogglKey(key) -> table
--- Method
--- Sets the toggl API key.
---
--- Parameters:
---  * key - Your toggl API key as a string.
---
--- Returns:
---  * self
function m:setTogglKey(key)
  toggl:setKey(key)
  return self
end

--- Headspace.stopToggl() -> nil
--- Method
--- Stops any running toggl timers
m.stopToggl = function()
  toggl.stopTimer()
end

--- Headspace.choose() -> nil
--- Method
--- Launch an hs.chooser to select a new headspace.
m.choose = function()
  local chooser = hs.chooser.new(function(space)
    if space and space.intentRequired and not m.parsedQuery.description then
      local intention = hs.chooser.new(function(descr)
        m.parsedQuery.description = descr.text
        m.switch(space)
      end)

      local intentSuggestions = {}
      if space.intentSuggestions then
        intentSuggestions = space.intentSuggestions
      end

      local focused = hs.window.frontmostWindow()
      table.insert(intentSuggestions, 1, {
        text = focused:title():gsub(' . ' .. focused:application():name() , '')
      })

      intention
      :placeholderText("What do you intend?")
      :choices(intentSuggestions)
      :queryChangedCallback(function(query)
        local choices = fn.filter(intentSuggestions, function(choice)
          return string.match(choice.text, query)
        end)

        table.insert(choices, {
          text = query,
          togglDesc = query
        })

        intention:choices(choices)
      end)
      :show()
    else
      m.switch(space)
    end
  end)

  chooser
    :placeholderText("Select a headspace???")
    :choices(m.config.spaces)
    :queryChangedCallback(function(query)
      chooser:choices(m.filter(query))
    end)
    :showCallback(function()
      toggl.currentTimer(function(timer)
        chooser:placeholderText(m.timerStr(timer))
      end)
    end)
    :show()
end

-- HELPERS =============

-- Switching spaces

m.setSpace = function(space)
  hs.settings.set('headspace', {
    text = space.text,
    whitelist = space.whitelist,
    blacklist = space.blacklist,
    launch = space.launch,
    funcs = space.funcs
  })
end

m.hasFunc = function(key, func)
  return m.config.funcs[key] and m.config.funcs[key][func]
end

m.switch = function(space)
  if space ~= nil then

    local previousSpace = hs.settings.get('headspace')
    -- teardown the previous space
    if previousSpace then
      if m.hasFunc(previousSpace.funcs, 'teardown') then
        m.config.funcs[previousSpace.funcs].teardown()
      end

      if previousSpace.layouts then
        spoon.AutoLayout:pop()
      end
    end

    -- Store headspace in hs.settings
    m.setSpace(space)

    -- Start timer unless holding shift
    if not hs.eventtap.checkKeyboardModifiers()['shift'] then

      -- Get either the space's default description or one passed between
      -- quotes.
      local description = nil
      if m.parsedQuery.description then
        description = m.parsedQuery.description
      else
        description = space.togglDesc
      end

      if space.togglProj or description then
        toggl.startTimer(space.togglProj, description)
      end
    end

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

    -- run setup()
    if m.hasFunc(space.funcs, 'setup') then
      m.config.funcs[space.funcs].setup()
    end

    -- use layout
    if space.layouts then
      spoon.AutoLayout:push(space.layouts)
      spoon.AutoLayout:autoLayout()
    end

    if m.parsedQuery.duration then -- make this a timed session
      m.timer =
        hs.timer.doAfter(m.parsedQuery.duration * 60, function()
          hs.sound.getByName("Blow"):play()
          hs.alert(
            "???: Time is up!",
            moduleStyle
          )
          m.choose()
          m.timer = nil
        end)
    end
  end
end

m.timerStr = function(runningTimer)
  local str = ""

  local space = hs.settings.get("headspace")

  if runningTimer and runningTimer.data then
    local timer = runningTimer.data

    local descr = ""
    if timer.description then
      descr = '"' .. timer.description .. '" '
    end

    local proj = ""
    if timer.pid then
      local project = toggl.getProject(timer.pid)
      if project and project.data then
        proj = project.data.name .. " "
      end
    end

    local duration = ""
    if m.timer then
      duration = "" .. math.ceil(m.timer:nextTrigger() / 60) .. "m remaining"
    else
      duration = math.floor((hs.timer.secondsSinceEpoch() + runningTimer.data.duration) / 60) .. "m"
    end

    str = proj .. descr .. "(" .. duration .. ")"
  else
    if space then
      str = "????: " .. space.text .. " "
    end
  end

  return str
end

-- Query

m.filter = function(searchQuery)
  local parsedQuery = m.parseQuery(searchQuery)

  local query = m.lowerOrEmpty(parsedQuery.query)
  m.parsedQuery = parsedQuery -- store this for later

  local results = fn.filter(m.config.spaces, function(space)
    local text = m.lowerOrEmpty(space.text)
    local subText = m.lowerOrEmpty(space.subText)
    return (string.match(text, query) or string.match(subText, query))
  end)

  table.insert(results, {
    text = query,
    subText = "Start a toggl timer with this description...",
    image = hs.image.imageFromAppBundle('com.toggl.toggldesktop.TogglDesktop'),
    togglDesc = parsedQuery.query
  })

  return results
end

m.parseQuery = function(query)
  -- extract out description: any "string" or 'string'
  local descriptionPattern = "[\'\"](.+)[\'\"]"
  local description = string.match(query, descriptionPattern)
  -- extract out duration: a colon followed by number of minutes (:45)
  local durationPattern    = ":(%d+)"
  local duration    = string.match(query, durationPattern)

  return {
    description = description,
    duration = tonumber(duration),
    query = query
            :gsub(descriptionPattern, "")
            :gsub(durationPattern, "")
            :gsub("^%s*(.-)%s*$", "%1") -- trim
  }
end

m.lowerOrEmpty = function(str)
  if str then
    return string.lower(str)
  else
    return ""
  end
end

-- Tags

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
      local space = hs.settings.get("headspace")
      if space then
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
  end
  return true
end

return m
