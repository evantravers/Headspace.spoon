-- TOGGL
--
-- Relies on a toggl api key in `hs.settings.get('secrets').toggl.key`.

local module = {}

module.key = function()
  if hs.settings.get("secrets").toggl.key then
    return hs.settings.get("secrets").toggl.key
  else
    print("You need to load a Toggl.com API key in to hs.settings under secrets.toggl.key")
  end
end

module.startTimer = function(projectId, description)
  local key = module.key()
  hs.http.asyncPost(
    "https://www.toggl.com/api/v8/time_entries/start",
    hs.json.encode(
      {
        ['time_entry'] = {
          ['description'] = description,
          ['pid'] = projectId,
          ['created_with'] = 'hammerspoon'
        }
      }
    ),
    {
      ["Content-Type"] = "application/json; charset=UTF-8",
      ["Authorization"] = "Basic " .. hs.base64.encode(key .. ":api_token")
    },
    function(httpNumber, body, headers)
      print("Timer started...")
      print(hs.inspect(body))
    end
  )
end

module.currentTimer = function()
  local key = module.key()
  httpNumber, body, headers = hs.http.get(
    "https://www.toggl.com/api/v8/time_entries/current",
    {
      ["Content-Type"] = "application/json; charset=UTF-8",
      ["Authorization"] = "Basic " .. hs.base64.encode(key .. ":api_token")
    }
  )
  if httpNumber == 200 then
    if body == '{"data":null}' then
      return nil
    else
      return hs.json.decode(body)
    end
  else
    print("problems!")
    print(httpNumber)
    print(body)
  end
end

module.getProject = function(pid)
  local key = module.key()
  httpNumber, body, headers = hs.http.get(
    "https://www.toggl.com/api/v8/projects/" .. pid,
    {
      ["Content-Type"] = "application/json; charset=UTF-8",
      ["Authorization"] = "Basic " .. hs.base64.encode(key .. ":api_token")
    }
  )
  if httpNumber == 200 then
    return hs.json.decode(body)
  else
    print("problems!")
    print(httpNumber)
    print(body)
  end
end

module.stopTimer = function()
  local current = module.currentTimer()
  if current then
    local key = module.key()
    httpNumber, body, headers = hs.http.doRequest(
      "https://www.toggl.com/api/v8/time_entries/" .. current['data']['id'] .. "/stop",
      "PUT",
      nil,
      {
        ["Content-Type"] = "application/json; charset=UTF-8",
        ["Authorization"] = "Basic " .. hs.base64.encode(key .. ":api_token")
      }
    )
    if httpNumber == 200 then
      return hs.json.decode(body)
    else
      print("problems!")
      print(httpNumber)
      print(body)
    end
  else
    print("No timer running!")
  end
end

return module
