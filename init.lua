-- HEADSPACE
--
-- You need in namespace a table at `config.spaces`.
-- `config.spaces` is a table that is passed to a chooser.
--
-- You can specify blocking of apps via a `whitelist`, `blacklist`, and you can
-- say what you want to have `launch` when you launch that space.
--
-- A space with a `blacklist` will allow anything _but_ apps tagged with the
-- blacklist tags, untagged apps, or apps with a whitelisted attribute.
--
-- A space with a `whitelist` will allow **only** the apps tagged with tags in
-- the whitelist, untagged apps, or apps with a whitelisted attribute.
--
-- There is presently an interaction between the two where if an app is
-- whitelisted by a tag and blacklisted by a tag, whitelist wins.
--
-- The `launch` list tells the space to auto launch certain things at startup.
--
-- Optionally, you can define a setup function at config.spaces.<key> that is
-- run when the space is started.
--
-- OPTIONS:
--
-- If you are using toggl timer, putting anything in quotes will pass that as a
-- custom description to toggl. e.g. Design "Working on jira ticket" will match
-- a space named Design, but pass a custom description to your timer.
--
-- If you want a pomodoro countdown, add a colon followed by integers. e.g. :45
-- will count down 45 minutes, then play a musical cue and prompt you to choose
-- a new space.
--
-- # Example:
--
-- config.spaces = {
--   text = "Example",
--   subText = "More about the example",
--   image = hs.image.imageFromAppBundle('foo.bar.com'),

--   setup = "example",

--   launch = {"table", "of", "tags"},
--   blacklist = {"table", "of", "tags"},
--   == OR ==
--   whitelist = {"table", "of", "tags"}

--   toggl_proj = "id of toggl project",
--   toggl_descr = "description of toggl timer
-- }
--
-- config.spaces.setup.example = function()
--   hs.urlevent.openURL("http://hammerspoon.org")
-- end
--
-- The goal is to get into another space, even when working from home.
--
-- Future expansions...
-- DND status?
-- Custom Desktop Background with prompts for focus, writing, code?
-- Musical cues?

local m = {
  name = "Headspace",
  version = "1.0",
  author = "Evan Travers <evantravers@gmail.com>",
  license = "FIXME"
}

local fn    = require('hs.fnutils')
local toggl = dofile(hs.spoons.resourcePath('toggl.lua'))

local moduleStyle = fn.copy(hs.alert.defaultStyle)
      moduleStyle.atScreenEdge = 1
      moduleStyle.strokeColor = { white = 1, alpha = 0 }
      moduleStyle.textSize = 36
      moduleStyle.radius = 9

m.init = function()
  m.tagged = {}
end

m.enable_watcher = function(self) self.watcher_enabled = true end

local set_space = function(space)
  hs.settings.set('headspace', {
    text = space.text,
    whitelist = space.whitelist,
    blacklist = space.blacklist,
    launch = space.launch,
    funcs = space.funcs
  })
end

local compute_tagged = function(list_of_applications)
  fn.map(list_of_applications, function(app_config)
    if app_config.tags then
      fn.map(app_config.tags, function(tag)
        if not m.tagged[tag] then module.tagged[tag] = {} end
        table.insert(m.tagged[tag], app_config.bundleID)
      end)
    end
  end)
end

local allowed = function(app_config)
  if app_config and app_config.tags then
    if app_config.whitelisted then
      return true
    else
      local space = hs.settings.get("headspace")
      if space then
        if space.whitelist then
          return fn.some(space.whitelist, function(tag)
            return fn.contains(m.tagged[tag], app_config.bundleID)
          end)
        else
          if space.blacklist then
            return fn.every(space.blacklist, function(tag)
              return not fn.contains(app_config.tags, tag)
            end)
          end
        end
      end
    end
  end
  return true
end

-- Expects a table with a key for "spaces" and a key for "setup".
m.start = function(config_table)
  m.config = config_table

  compute_tagged(config_table.applications)

  if m.watcher_enabled then
    m.watcher = hs.application.watcher.new(function(app_name, event, hsapp)
      if event == hs.application.watcher.launched then
        local app_config = m.config.applications[hsapp:bundleID()]

        if not allowed(app_config) then
          hs.alert(
            "🛑: " .. hsapp:name() .. "\n" ..
            "📂: " .. hs.settings.get("headspace").text,
            moduleStyle
          )
          hsapp:kill()
        end
      end
    end):start()
  end
end

local has_func = function(key, func)
  return m.config.funcs[key] and module.config.funcs[key][func]
end

m.switch = function(space)
  if space ~= nil then

    local previous_space = hs.settings.get('headspace')
    -- teardown the previous space
    if previous_space then
      if has_func(previous_space.funcs, 'teardown') then
        m.config.funcs[previous_space.funcs].teardown()
      end
    end

    -- Store headspace in hs.settings
    set_space(space)

    -- Start timer unless holding shift
    if not hs.eventtap.checkKeyboardModifiers()['shift'] then

      -- Get either the space's default description or one passed between
      -- quotes.
      local description = nil
      if m.parsedQuery.description then
        description = m.parsedQuery.description
      else
        description = space.toggl_desc
      end

      if space.toggl_proj or description then
        toggl.start_timer(space.toggl_proj, description)
      end
    end

    -- launch / close apps
    if space.launch then
      m.tags_to_bundleID(space.launch, function(bundleID)
        hs.application.launchOrFocusByBundleID(bundleID)
      end)
    end

    if space.blacklist then
      m.tags_to_bundleID(space.blacklist, function(bundleID)
        local app = hs.application.get(bundleID)
        if app then app:kill() end
      end)
    end

    if space.whitelist then
      fn.map(m.config.applications, function(app_config)
        if not allowed(app_config) then
          local app = hs.application.get(app_config.bundleID)
          if app then
            app:kill()
          end
        end
      end)
    end

    -- run setup()
    if has_func(space.funcs, 'setup') then
      m.config.funcs[space.funcs].setup()
    end

    -- use layout
    if space.layouts then
      hs.window.layout.applyLayout(space.layouts)
    end

    if m.parsedQuery.duration then -- make this a timed session
      m.timer =
        hs.timer.doAfter(m.parsedQuery.duration * 60, function()
          hs.sound.getByName("Blow"):play()
          hs.alert(
            "⏲: Time is up!",
            moduleStyle
          )
          m.choose()
          m.timer = nil
        end)
    end
  end
end

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
    toggl_desc = parsedQuery.query
  })

  return results
end

m.choose = function()
  local chooser = hs.chooser.new(function(space)
    if space.intent_required and not m.parsedQuery.description then
      local intention = hs.chooser.new(function(descr)
        m.parsedQuery.description = descr.text
        m.switch(space)
      end)

      local suggestions = {}
      if space.suggestions then
        suggestions = space.suggestions
      end

      local focused = hs.window.frontmostWindow()
      table.insert(suggestions, 1, {
        text = focused:title():gsub(' . ' .. focused:application():name() , '')
      })

      intention
      :placeholderText("What do you intend?")
      :choices(suggestions)
      :queryChangedCallback(function(query)
        local choices = fn.filter(suggestions, function(choice)
          hs.inspect(choice)
          return string.match(choice.text, query)
        end)

        table.insert(choices, {
          text = query,
          toggl_desc = query
        })

        intention:choices(choices)
      end)
      :show()
    else
      m.switch(space)
    end
  end)

  chooser
    :placeholderText("Select a headspace…")
    :choices(m.config.spaces)
    :queryChangedCallback(function(query)
      chooser:choices(m.filter(query))
    end)
    :showCallback(function()
      if m.timer_str() ~= "" then
        chooser:placeholderText(m.timer_str())
      end
    end)
    :show()
end

m.timer_str = function()
  local str = ""

  local space = hs.settings.get("headspace")
  local running_timer = toggl.current_timer()

  if running_timer and running_timer.data then
    local timer = running_timer.data

    local descr = ""
    if timer.description then
      descr = '"' .. timer.description .. '" '
    end

    local proj = ""
    if timer.pid then
      local project = toggl.get_project(timer.pid)
      if project and project.data then
        proj = project.data.name .. " "
      end
    end

    local duration = ""
    if m.timer then
      duration = "-" .. math.ceil(m.timer:nextTrigger() / 60) .. "m"
    else
      duration = math.floor((hs.timer.secondsSinceEpoch() + running_timer.data.duration) / 60) .. "m"
    end

    str = proj .. descr .. "(" .. duration .. ")"
  else
    if space then
      str = "📂: " .. space.text .. " "
    end
  end

  return str
end

m.lowerOrEmpty = function(str)
  if str then
    return string.lower(str)
  else
    return ""
  end
end

m.parseQuery = function(query)
  -- extract out description: any "string" or 'string'
  local description_pattern = "[\'\"](.+)[\'\"]"
  local description = string.match(query, description_pattern)
  -- extract out duration: a colon followed by number of minutes (:45)
  local duration_pattern    = ":(%d+)"
  local duration    = string.match(query, duration_pattern)

  return {
    description = description,
    duration = tonumber(duration),
    query = query
            :gsub(description_pattern, "")
            :gsub(duration_pattern, "")
            :gsub("^%s*(.-)%s*$", "%1") -- trim
  }
end

m.appsTaggedWith = function(tag)
  return m.tagged[tag]
end

m.tags_to_bundleID = function(list_of_tags, func)
  fn.map(list_of_tags, function(tag)
    fn.map(m.appsTaggedWith(tag), function(app_config)
      func(app_config)
    end)
  end)
end

return m
