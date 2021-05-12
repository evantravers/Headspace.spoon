-- TOGGL

local m = {}

function m:setKey(key)
  m.apiToken = key
  return self
end

m.key = function()
  if m.apiToken then
    return m.apiToken
  else
    print("You need to load a Toggl.com API key using toggl:setKey(key)")
  end
end

m.startTimer = function(projectId, description)
  local key = m.key()
  hs.http.asyncPost(
    "https://api.track.toggl.com/api/v8/time_entries/start",
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

m.currentTimer = function(callback)
  local key = m.key()
  hs.http.asyncGet(
    "https://api.track.toggl.com/api/v8/time_entries/current",
    {
      ["Content-Type"] = "application/json; charset=UTF-8",
      ["Authorization"] = "Basic " .. hs.base64.encode(key .. ":api_token")
    },
    function(httpNumber, body, headers)
      if httpNumber == 200 then
        if body == '{"data":null}' then
          return nil
        else
          callback(hs.json.decode(body))
        end
      else
        print("problems!")
        print(httpNumber)
        print(body)
      end
    end
  )
end

m.getProject = function(pid)
  local key = m.key()
  httpNumber, body, headers = hs.http.get(
    "https://api.track.toggl.com/api/v8/projects/" .. pid,
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

m.stopTimer = function()
  m.currentTimer(function(current)
    local key = m.key()
    httpNumber, body, headers = hs.http.doRequest(
      "https://api.track.toggl.com/api/v8/time_entries/" .. current['data']['id'] .. "/stop",
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
  end)
end

return m
