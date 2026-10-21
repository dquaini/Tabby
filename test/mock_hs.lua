-- Finto Hammerspoon, abbastanza per far girare Tabby e simulare l'uso
LOG = {}
local function log(...) local t = {} for i = 1, select('#', ...) do t[#t+1] = tostring(select(i, ...)) end LOG[#LOG+1] = table.concat(t, " ") end

local timers = {}
function FLUSH(n)
  for _ = 1, (n or 20) do
    if #timers == 0 then return end
    local q = timers; timers = {}
    for _, fn in ipairs(q) do fn() end
  end
end

local SCREEN = {
  frame = function() return {x = 0, y = 25, w = 1440, h = 875} end,
  fullFrame = function() return {x = 0, y = 0, w = 1440, h = 900} end,
  id = function() return 1 end,
  name = function() return "Built-in Retina Display" end,
}

APPS, FRONT, MOUSE = {}, nil, {x = 100, y = 10}
HS_APP = nil

WID = 100
function newWindow(app, title, urls)
  WID = WID + 1
  local w = {_frame = {x = 50, y = 80, w = 800, h = 600}, _app = app, _title = title,
             _fs = false, _min = false, _id = WID, _urls = urls or {}}
  function w:id() return self._id end
  function w:raise() end
  function w:unminimize() self._min = false end
  function w:isStandard() return true end
  function w:isVisible() return true end
  function w:isFullScreen() return self._fs end
  function w:isMinimized() return self._min end
  function w:screen() return SCREEN end
  function w:setFrame(r) self._frame = {x = r.x, y = r.y, w = r.w, h = r.h} end
  function w:frame() return self._frame end
  function w:setTopLeft(p) self._frame.x, self._frame.y = p.x, p.y end
  function w:application() return self._app end
  function w:title() return self._title end
  function w:close() for i, x in ipairs(self._app._wins) do if x == self then table.remove(self._app._wins, i); break end end; LOGW = (LOGW or 0) + 1 end
  function w:minimize() self._min = true end
  function w:focus() FRONT = self._app; self._app._hidden = false; self._app._focused = self end
  function w:setFullScreen(v) self._fs = v end
  return w
end

function ADDAPP(bid, name)
  local a = {_bid = bid, _name = name, _hidden = false, _wins = {}, _running = true}
  function a:bundleID() return self._bid end
  function a:name() return self._name end
  function a:kind() return 1 end
  function a:isHidden() return self._hidden end
  function a:hide() self._hidden = true; log("hide", self._bid) end
  function a:unhide() self._hidden = false end
  function a:allWindows() return self._wins end
  function a:mainWindow() return self._wins[1] end
  function a:focusedWindow() return self._focused or self._wins[1] end
  function a:isRunning() return self._running end
  function a:pid() return #self._bid end
  function a:activate() FRONT = self; self._hidden = false end
  function a:kill() self._running = false; for i, x in ipairs(APPS) do if x == self then table.remove(APPS, i) end end; log("kill", self._bid) end
  table.insert(a._wins, newWindow(a, name .. " – finestra"))
  table.insert(APPS, a)
  return a
end

local function findApp(h)
  for _, a in ipairs(APPS) do if a._bid == h or a._name == h then return a end end
end

local SETTINGS = {}
CANVASES = {}

local function newCanvas(fr)
  local c = {_frame = fr, _els = {}, _shown = false}
  function c:level() return self end
  function c:behavior() return self end
  function c:clickActivating() return self end
  function c:mouseCallback(fn) self._cb = fn; return self end
  function c:frame(f) if f then self._frame = f; return self end return self._frame end
  function c:replaceElements(e) self._els = e; return self end
  function c:show() self._shown = true; return self end
  function c:hide() self._shown = false; return self end
  function c:orderAbove() return self end
  function c:topLeft(p) self._frame = {x = p.x, y = p.y, w = (self._frame or {}).w, h = (self._frame or {}).h}; return self end
  function c:delete() end
  function c:imageFromCanvas() return {setSize = function(s) return s end} end
  table.insert(CANVASES, c)
  return c
end

MENU = nil
TAPS = {}

hs = {
  window = {
    animationDuration = 0,
    focusedWindow = function() return FRONT and (FRONT._focused or FRONT._wins[1]) end,
    filter = {
      windowCreated = "created", windowDestroyed = "destroyed",
      windowFullscreened = "fs", windowUnfullscreened = "unfs", windowFocused = "focused", windowTitleChanged = "title",
      new = function()
        local f = {subs = {}}
        function f:setDefaultFilter() return self end
        function f:subscribe(ev, fn)
          if type(ev) == "table" then for _, e in ipairs(ev) do self.subs[e] = fn end else self.subs[ev] = fn end
          return self
        end
        function f:getWindows()
          local out = {}
          for _, a in ipairs(APPS) do for _, w in ipairs(a._wins) do table.insert(out, w) end end
          return out
        end
        WINFILTER = f
        return f
      end,
    },
  },
  settings = {
    get = function(k) return SETTINGS[k] end,
    set = function(k, v) SETTINGS[k] = v end,
  },
  screen = {
    primaryScreen = function() return SCREEN end,
    watcher = {new = function() return {start = function(s) return s end} end},
  },
  geometry = {rect = function(x, y, w, h) return {x = x, y = y, w = w, h = h} end},
  image = {imageFromAppBundle = function(b) return {setSize = function(s) return s end, _b = b} end,
           imageFromURL = function(u, cb) FAVICON_REQ = (FAVICON_REQ or 0) + 1; FAVICON_URLS = FAVICON_URLS or {}; table.insert(FAVICON_URLS, u); if cb then if FAVICON_FAIL and u:find(FAVICON_FAIL, 1, true) then cb(nil) else cb({setSize = function(s) return s end, size = function() return {w = 32, h = 32} end, _url = u}) end end end},
  application = {
    runningApplications = function() local o = {} for _, a in ipairs(APPS) do o[#o+1] = a end return o end,
    get = function(h) if h == "com.apple.dock" then return {} end return findApp(h) end,
    applicationsForBundleID = function(b) if b == "com.apple.dock" then return {{}} end local a = findApp(b); return (a and a._bid == b and a._running ~= false) and {a} or {} end,
    frontmostApplication = function() return FRONT end,
    launchOrFocusByBundleID = function(b) local a = findApp(b); if a then a:activate(); log("focus", b) end end,
    nameForBundleID = function(b) return b end,
    pathForBundleID = function(b) return "/Applications/" .. b end,
    infoForBundlePath = function(p) local b = p:match("/Applications/(.+)%.app$"); return b and {CFBundleIdentifier = b} or nil end,
    watcher = {
      activated = "act", launched = "launch", terminated = "term",
      new = function(fn) APPWATCH = fn; return {start = function(s) return s end} end,
    },
  },
  timer = {
    doAfter = function(_, fn) table.insert(timers, fn); return {} end,
    doEvery = function(_, fn) return {fn = fn} end,
    delayed = {new = function(_, fn) return {start = function() table.insert(timers, fn) end} end},
    secondsSinceEpoch = function() return CLOCK or 1000 end,
    absoluteTime = function() return 0 end,
  },
  canvas = {
    new = newCanvas,
    windowLevels = {floating = 3, dragging = 500},
  },
  spaces = {watcher = {new = function() return {start = function(s) return s end} end}},
  battery = {
    percentage = function() return 72 end,
    isCharging = function() return false end,
    powerSource = function() return "Battery Power" end,
    watcher = {new = function() return {start = function(s) return s end} end},
  },
  eventtap = {
    event = {types = {keyDown = 10, leftMouseDragged = 6, leftMouseUp = 2}},
    new = function(types, fn)
      local t = {types = types, fn = fn, on = false}
      function t:start() self.on = true; return self end
      function t:stop() self.on = false; return self end
      function t:isEnabled() return self.on end
      table.insert(TAPS, t)
      return t
    end,
    keyStroke = function() end,
  },
  keycodes = {map = {}},
  mouse = {absolutePosition = function() return {x = MOUSE.x, y = MOUSE.y} end},
  menubar = {new = function()
    return {setMenu = function(s, items) MENU = items; return s end, popupMenu = function() end}
  end},
  hotkey = {bind = function(m, k, fn) HOTKEYS = HOTKEYS or {}; HOTKEYS[k] = fn; return {} end},
  alert = {show = function(m) log("alert", m) end},
  dialog = {blockAlert = function() return "Chiudi tutte" end, chooseFileOrFolder = function() return nil end},
  osascript = {
    javascript = function() return true, "" end,
    applescript = function(src)
      if AS_DENIED then return false, nil end
      local name = src:match('tell application "([^"]+)"')
      local a = findApp(name == "Google Chrome" and "com.google.Chrome" or name)
      if not a then return false, nil end
      local out = ""
      for _, w in ipairs(a._wins) do
        -- come il vero browser: il nome della finestra (senza profilo) e la posizione
        local f = w._frame
        out = out .. (w._asName or w._title) .. "\t"
        if not NO_BOUNDS then out = out .. f.x .. "," .. f.y .. "," .. (f.x + f.w) .. "," .. (f.y + f.h) .. "\t" end
        for _, u in ipairs(w._urls) do out = out .. u .. "\t" end
        out = out .. "\n"
      end
      return true, out
    end,
  },
  axuielement = {applicationElement = function()
    local items = {}
    for bid, label in pairs(DOCK_BADGES or {}) do
      table.insert(items, {attributeValue = function(_, k)
        if k == "AXStatusLabel" then return label end
        if k == "AXURL" then return {url = "file:///Applications/" .. bid .. ".app/"} end
        if k == "AXTitle" then return bid end
      end})
    end
    local list = {attributeValue = function(_, k) if k == "AXChildren" then return items end end}
    return {attributeValue = function(_, k) if k == "AXChildren" then return {list} end end}
  end},
  webview = {
    new = function(r)
      local wv = {_frame = r, _shown = false, _js = {}}
      for _, m in ipairs({"windowStyle","windowTitle","allowTextEntry","deleteOnClose","level","behaviorAsLabels","windowCallback","html"}) do
        wv[m] = function(self, v) if m == "html" then self._html = v end; return self end
      end
      function wv:frame(f) if f then self._frame = f end return self._frame end
      function wv:show() self._shown = true; return self end
      function wv:hide() self._shown = false; return self end
      function wv:hswindow() return {focus = function() end} end
      function wv:evaluateJavaScript(js) table.insert(self._js, js) end
      MEMO = wv
      return wv
    end,
    usercontent = {new = function() return {setCallback = function(self, fn) MEMO_CB = fn; return self end} end},
  },
  focus = function() FRONT = HS_APP end, reload = function() end, openConsole = function() end,
}

-- tastiera: mappa bidirezionale come quella vera
local codes = {["0"]=29,["1"]=18,["2"]=19,["3"]=20,["4"]=21,["5"]=23,["6"]=22,["7"]=26,["8"]=28,["9"]=25,
  c=8, m=46, left=123, right=124, down=125, up=126, escape=53, ["return"]=36, padenter=76, tab=48}
for k, v in pairs(codes) do hs.keycodes.map[k] = v; hs.keycodes.map[v] = k end

function KEY(name, mods)
  local flags = {}
  for _, m in ipairs(mods or {}) do flags[m] = true end
  local ev = {getFlags = function() return flags end, getKeyCode = function() return codes[name] end}
  for _, t in ipairs(TAPS) do
    if t.types[1] == 10 and t.on then return t.fn(ev) end
  end
end

function BAR() return CANVASES[1] end
function CLICK(id) BAR()._cb(BAR(), "mouseUp", id) end
function OVERLAY_CLICK(id) for _, c in ipairs(CANVASES) do if c ~= BAR() and c._cb then c._cb(c, "mouseUp", id) end end end

function DRAGTAP() for _, t in ipairs(TAPS) do if t.types[1] == 6 then return t end end end
function DRAG(id, from, to)
  MOUSE = {x = from.x, y = from.y}
  BAR()._cb(BAR(), "mouseDown", id)
  local tap = DRAGTAP()
  for s = 1, 5 do
    MOUSE = {x = from.x + (to.x - from.x) * s / 5, y = from.y + (to.y - from.y) * s / 5}
    tap.fn({getType = function() return 6 end})
  end
  tap.fn({getType = function() return 2 end})
  BAR()._cb(BAR(), "mouseUp", id)   -- il canvas riceve comunque il mouseUp
  FLUSH()
end

function TABNAMES()
  local o = {}
  for _, t in ipairs(Tabby.tabs) do o[#o+1] = t.name end
  return table.concat(o, " | ")
end

HS_APP = {_bid = "org.hammerspoon.Hammerspoon", _wins = {}, bundleID = function() return "org.hammerspoon.Hammerspoon" end,
  kind = function() return 1 end, isHidden = function() return false end, pid = function() return 1 end,
  allWindows = function() return {} end, name = function() return "Hammerspoon" end}

function ADDBROWSER(bid, name, windows)
  local a = ADDAPP(bid, name)
  a._wins = {}
  for _, w in ipairs(windows) do table.insert(a._wins, newWindow(a, w[1], w[2])) end
  return a
end

-- tasti con modificatori, anche "tab", "left", ...
function KEY2(name, mods) return KEY(name, mods) end
