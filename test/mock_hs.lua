NO_DIARY = true   -- il diario su file solo sul Mac vero
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
  desktopImageURL = function() return "file:///System/Library/CoreServices/DefaultDesktop.heic" end,
  id = function() return 1 end,
  name = function() return "Built-in Retina Display" end,
}

APPS, FRONT, MOUSE = {}, nil, {x = 100, y = 10}
ZORDER = {}
function TOFRONT(app, win)
  local mine = {}
  if win then mine[1] = win end
  for _, w in ipairs(app._wins) do if w ~= win then table.insert(mine, w) end end
  local rest = {}
  for _, w in ipairs(ZORDER) do if w._app ~= app then table.insert(rest, w) end end
  ZORDER = mine
  for _, w in ipairs(rest) do table.insert(ZORDER, w) end
end
HS_APP = nil

WID = 100
function newWindow(app, title, urls)
  WID = WID + 1
  local w = {_frame = {x = 50, y = 80, w = 800, h = 600}, _app = app, _title = title,
             _fs = false, _min = false, _id = WID, _urls = urls or {}}
  function w:id() return self._id end
  -- sul Mac vero portare davanti una finestra la rende anche quella attiva della sua
  -- app, e macOS lo annuncia (RAISE_FOCUS = true per simularlo)
  function w:raise()
    RAISES = (RAISES or 0) + 1
    if RAISE_FOCUS and self._app._focused ~= self then
      self._app._focused = self
      if WINFILTER and WINFILTER.subs["focused"] then WINFILTER.subs["focused"](self) end
    end
  end
  function w:unminimize() self._min = false end
  -- come macOS 26: una finestra ridotta, o di un'app nascosta, si dice "dialogo"
  -- (solo per le finestre con _macos26 = true)
  function w:isStandard() return not (self._macos26 and (self._min or self._app._hidden)) end
  function w:subrole() return self:isStandard() and "AXStandardWindow" or "AXDialog" end
  function w:role() return "AXWindow" end
  function w:isVisible() return true end
  function w:isFullScreen() return self._fs end
  function w:isMinimized() return self._min end
  function w:screen() return SCREEN end
  function w:setFrame(r) SETFRAMES_ALL = (SETFRAMES_ALL or 0) + 1; self._frame = {x = r.x, y = r.y, w = r.w, h = r.h} end
  function w:frame() return self._frame end
  function w:setTopLeft(p) self._frame.x, self._frame.y = p.x, p.y end
  function w:application() return self._app end
  function w:title() return self._title end
  function w:close() for i, x in ipairs(self._app._wins) do if x == self then table.remove(self._app._wins, i); break end end; LOGW = (LOGW or 0) + 1 end
  function w:minimize() self._min = true end
  function w:focus() FRONT = self._app; self._app._hidden = false; self._app._focused = self; TOFRONT(self._app, self) end
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
  function a:activate() FRONT = self; self._hidden = false; TOFRONT(self, self._focused) end
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
  function c:behavior(b) self._behavior = b; return self end
  function c:clickActivating() return self end
  function c:mouseCallback(fn) self._cb = fn; return self end
  function c:frame(f) if f then self._frame = f; return self end return self._frame end
  function c:replaceElements(e) self._els = e; return self end
  function c:show() self._shown = true; return self end
  function c:hide() self._shown = false; return self end
  function c:orderAbove() return self end
  function c:canvasMouseEvents() return self end
  function c:topLeft(p) self._frame = {x = p.x, y = p.y, w = (self._frame or {}).w, h = (self._frame or {}).h}; return self end
  function c:delete() end
  function c:alpha(a) if a then self._alpha = a; return self end return self._alpha or 1 end
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
    -- finestre visibili, da quella davanti a quella più dietro: prima la finestra
    -- attiva, poi le altre
    -- finestre visibili, da quella davanti a quella più dietro (ZORDER: ogni app
    -- attivata porta davanti le sue finestre, la finestra attiva per prima)
    orderedWindows = function()
      local out, seen = {}, {}
      local fw = FRONT and (FRONT._focused or FRONT._wins[1])
      local function add(w)
        if w and not seen[w] and not w._min and not w._app._hidden and w._app._running ~= false then
          local alive = false
          for _, x in ipairs(w._app._wins) do if x == w then alive = true end end
          if alive then seen[w] = true; table.insert(out, w) end
        end
      end
      add(fw)
      for _, w in ipairs(ZORDER) do add(w) end
      for _, a in ipairs(APPS) do for _, w in ipairs(a._wins) do add(w) end end
      return out
    end,
    filter = {
      windowCreated = "created", windowDestroyed = "destroyed",
      windowFullscreened = "fs", windowUnfullscreened = "unfs", windowFocused = "focused", windowTitleChanged = "title",
      windowVisible = "visible", windowNotVisible = "notvisible", windowMinimized = "minimized", windowUnminimized = "unminimized",
      new = function(which)
        local f = {subs = {}}
        function f:setDefaultFilter() WINFILTER = self; return self end
        function f:setAppFilter(name) self._apps = self._apps or {}; self._apps[name] = true; NCFILTER = self; return self end
        function f:subscribe(ev, fn)
          if type(ev) == "table" then for _, e in ipairs(ev) do self.subs[e] = fn end else self.subs[ev] = fn end
          return self
        end
        function f:getWindows()
          local out = {}
          for _, a in ipairs(APPS) do for _, w in ipairs(a._wins) do table.insert(out, w) end end
          return out
        end
        -- il filtro di Spotlight è a parte (SPOTFILTER), quello di tutte le finestre è WINFILTER
        if which == "Spotlight" then SPOTFILTER = f elseif which ~= false then WINFILTER = f end
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
  image = {imageFromAppBundle = function(b) return {setSize = function(s) return s end, _b = b, encodeAsURLString = function() return "data:image/png;base64,ICONA" end} end,
           imageFromPath = function(p) if not p:find("%.heic$") then return nil end return {setSize = function(s) return s end, size = function() return {w = 480, h = 300} end, encodeAsURLString = function() return "data:image/jpeg;base64,SFONDO" end} end,
           imageFromURL = function(u, cb) FAVICON_REQ = (FAVICON_REQ or 0) + 1; FAVICON_URLS = FAVICON_URLS or {}; table.insert(FAVICON_URLS, u); if cb then if FAVICON_FAIL and u:find(FAVICON_FAIL, 1, true) then cb(nil) else cb({setSize = function(s) return s end, size = function() return {w = 32, h = 32} end, _url = u}) end end end},
  application = {
    runningApplications = function() local o = {} for _, a in ipairs(APPS) do o[#o+1] = a end return o end,
    get = function(h) if h == "com.apple.dock" then return {} end return findApp(h) end,
    applicationsForBundleID = function(b) if b == "com.apple.dock" or b == "com.apple.Spotlight" then return {{}} end local a = findApp(b); return (a and a._bid == b and a._running ~= false) and {a} or {} end,
    frontmostApplication = function() return FRONT end,
    launchOrFocusByBundleID = function(b) local a = findApp(b); if a then a:activate(); log("focus", b) end end,
    nameForBundleID = function(b) return b end,
    pathForBundleID = function(b) return "/Applications/" .. b end,
    infoForBundlePath = function(p) local b = p:match("/Applications/(.+)%.app$"); return b and {CFBundleIdentifier = b} or nil end,
    watcher = {
      activated = "act", launched = "launch", terminated = "term", hidden = "hide", unhidden = "unhide",
      new = function(fn) APPWATCH = fn; return {start = function(s) return s end} end,
    },
  },
  timer = {
    doAfter = function(_, fn)
      local t = {cancelled = false}
      function t:stop() self.cancelled = true; return self end
      table.insert(timers, function() if not t.cancelled then fn() end end)
      return t
    end,
    doEvery = function(_, fn)
      local t = {fn = fn, on = true}
      function t:stop() self.on = false; return self end
      function t:start() self.on = true; return self end
      function t:running() return self.on end
      return t
    end,
    delayed = {new = function(_, fn) return {start = function() table.insert(timers, fn) end} end},
    -- timer ripetuto, fermo finché non lo avvii (es. il puntatore vicino alla sfera)
    new = function(_, fn)
      local t = {fn = fn, on = false}
      function t:start() self.on = true; return self end
      function t:stop() self.on = false; return self end
      function t:running() return self.on end
      return t
    end,
    secondsSinceEpoch = function() return CLOCK or 1000 end,
    absoluteTime = function() return 0 end,
  },
  pasteboard = {getContents = function() return CLIPBOARD end},
  sound = {getByName = function(n) return {play = function() SOUNDS = (SOUNDS or 0) + 1 end} end},
  canvas = {
    new = newCanvas,
    windowLevels = {floating = 3, modalPanel = 8, dragging = 500},
  },
  spaces = {watcher = {new = function() return {start = function(s) return s end} end},
            focusedSpace = function() return 1 end,
            spaceType = function() return SPACE_KIND or "user" end},
  battery = {
    percentage = function() return 72 end,
    isCharging = function() return false end,
    powerSource = function() return "Battery Power" end,
    watcher = {new = function() return {start = function(s) return s end} end},
  },
  eventtap = {
    event = {types = {keyDown = 10, leftMouseDragged = 6, leftMouseUp = 2, gesture = 29, leftMouseDown = 1, rightMouseDown = 3}},
    new = function(types, fn)
      local t = {types = types, fn = fn, on = false}
      function t:start() self.on = true; return self end
      function t:stop() self.on = false; return self end
      function t:isEnabled() return self.on end
      table.insert(TAPS, t)
      return t
    end,
    keyStroke = function(m, k) KEYSTROKES = KEYSTROKES or {}; table.insert(KEYSTROKES, table.concat(m or {}, "+") .. "+" .. tostring(k)) end,
    keyStrokes = function(s) TYPED = s end,
    checkKeyboardModifiers = function() return HELD or {} end,
  },
  keycodes = {map = {}},
  mouse = {absolutePosition = function() return {x = MOUSE.x, y = MOUSE.y} end},
  menubar = {new = function()
    return {setMenu = function(s, items) MENU = items; return s end, popupMenu = function() end}
  end},
  hotkey = {bind = function(m, k, fn) HOTKEYS = HOTKEYS or {}; HOTKEYS[k] = fn; return {} end},
  alert = {show = function(m) log("alert", m) end},
  dialog = {blockAlert = function(_, _, b1) return BLOCK_ANSWER or b1 end, chooseFileOrFolder = function() return nil end,
            textPrompt = function(_, _, def, b1, b2) local t = PROMPT_TEXT; PROMPT_TEXT = nil; if t == false then return b2, "" end return b1, t or def end},
  -- comandi esterni (usato per osascript): la risposta arriva "dopo", come sul Mac
  task = {new = function(path, cb, args)
    local t = {}
    function t:start()
      TASKS = (TASKS or 0) + 1
      table.insert(timers, function()
        if path:find("/shortcuts$") then
          -- l'app Comandi: «list» dice i comandi rapidi che hai, «run» ne fa partire uno
          SHORTCUTS_RUN = SHORTCUTS_RUN or {}
          if args[1] == "run" then table.insert(SHORTCUTS_RUN, args[2]) end
          if cb then cb(0, args[1] == "list" and (SHORTCUTS_LIST or "") or "", "") end
          return
        end
        if path:find("/open$") then
          -- "open -g -b <app> [indirizzo]": apre un'app (o un sito) senza portarla davanti
          OPENS = OPENS or {}
          table.insert(OPENS, table.concat(args, " "))
          if OPEN_HOOK then OPEN_HOOK(args) end
          if cb then cb(0, "", "") end
          return
        end
        if args[2]:find("make new") then
          -- il browser apre una finestra nuova (con un sito)
          MAKES = MAKES or {}
          table.insert(MAKES, args[2])
          if MAKE_HOOK then MAKE_HOOK(args[2]) end
          if cb then cb(0, "", "") end
          return
        end
        local ok, out = hs.osascript.applescript(args[2])
        if cb then cb(ok and 0 or 1, ok and out or "", ok and "" or (AS_TIMEOUT and "errore -1712" or "errore -1743")) end
      end)
      return self
    end
    function t:terminate() end
    return t
  end},
  osascript = {
    javascript = function() return true, "" end,
    applescript = function(src)
      if AS_DENIED then return false, nil end
      local name = src:match('tell application "([^"]+)"')
      local a = findApp(name == "Google Chrome" and "com.google.Chrome" or name)
      if not a then return false, nil end
      local out = ""
      -- come il vero macOS: dentro "tell application" la parola tab è la
      -- scheda del browser, e "x" & tab dà "xtab" (non una tabulazione)
      local inner = src:match('tell application.-end tell') or ""
      local T9 = inner:find("&%s*tab%f[^%w]") and "tab" or "\t"
      for _, w in ipairs(a._wins) do
       if not w._noAS then   -- le finestrelle (video in miniatura) non sono nell'elenco del browser
        -- come il vero browser: il nome della finestra (senza profilo) e la posizione
        local f = w._frame
        out = out .. (w._asName or w._title) .. T9 .. "id" .. w._id .. T9
        if not NO_BOUNDS then out = out .. f.x .. "," .. f.y .. "," .. (f.x + f.w) .. "," .. (f.y + f.h) .. T9 end
        for _, u in ipairs(w._urls) do out = out .. u .. T9 end
        out = out .. "\n"
       end
      end
      return true, out
    end,
  },
  axuielement = {
  -- l'interno di una finestra di browser letto con l'Accessibilità (DuckDuckGo):
  -- w._ntabs pulsanti delle schede e la pagina w._page
  windowElement = function(w)
    local function el(role, attrs, kids)
      return {attributeValue = function(_, k)
        if k == "AXRole" then return role end
        if k == "AXChildren" then return kids or {} end
        return attrs and attrs[k]
      end}
    end
    local tabs = {}
    for i = 1, (w._ntabs or 1) do tabs[i] = el("AXButton", {AXRoleDescription = "scheda"}) end
    -- il pallino verde: 16x16, a 48 punti dal bordo sinistro, in alto
    local f = w._frame or {x = 0, y = 0}
    local green = el("AXButton", {AXPosition = {x = f.x + 48, y = f.y + 6}, AXSize = {w = 16, h = 16}})
    -- il testo della finestra (w._texts): per «Cerca nelle finestre»
    local page = {el("AXTextField", {AXValue = "non-deve-leggermi.com"})}
    for _, t in ipairs(w._texts or {}) do table.insert(page, el("AXStaticText", {AXValue = t})) end
    AXREADS = (AXREADS or 0) + 1
    local win = el("AXWindow", {AXFullScreenButton = green, AXPosition = w._axpos}, {el("AXGroup", nil, tabs),
      el("AXWebArea", {AXURL = {url = w._page}}, page)})
    -- spostare la finestra (es. quella delle notifiche di macOS)
    win.setAttributeValue = function(_, k, v) if k == "AXPosition" then w._axpos = v end end
    return win
  end,
  applicationElement = function(app)
    if app and app._extras then   -- un'app con l'icona nella barra dei menu
      local entries = {}
      for _, title in ipairs(app._menu or {}) do
        table.insert(entries, {attributeValue = function(_, k)
          if k == "AXRole" then return "AXMenuItem" end
          if k == "AXTitle" then return title end
        end, performAction = function(_, act) PRESSED = (PRESSED or "") .. title .. ":" .. act .. ";" end})
      end
      local menu = {attributeValue = function(_, k)
        if k == "AXRole" then return "AXMenu" end
        if k == "AXChildren" then return entries end
      end}
      local item = {performAction = function(_, act) PRESSED = (PRESSED or "") .. app._bid .. ":" .. act .. ";" end,
                    attributeValue = function(_, k)
                      if k == "AXChildren" then return app._menu and {menu} or {} end   -- un menu solo se l'app ce l'ha
                      if k == "AXPosition" then return app._extrasPos or {x = 1200, y = 0} end
                    end}
      local bar = {attributeValue = function(_, k) if k == "AXChildren" then return {item} end end}
      return {attributeValue = function(_, k) if k == "AXExtrasMenuBar" then return bar end end}
    end
    local items = {}
    for bid, label in pairs(DOCK_BADGES or {}) do
      table.insert(items, {attributeValue = function(_, k)
        if k == "AXStatusLabel" then return label end
        if k == "AXURL" then return {url = "file:///Applications/" .. bid .. ".app/"} end
        if k == "AXTitle" then return bid end
      end})
    end
    local list = {attributeValue = function(_, k) if k == "AXChildren" then return items end end}
    return {attributeValue = function(_, k)
      if k == "AXChildren" then return {list} end
      if k == "AXWindows" then return SPOT_WINDOWS or {} end   -- finestre di Spotlight
    end}
  end},
  webview = {
    new = function(r, _, ucc)
      local wv = {_frame = r, _shown = false, _js = {}, _ucc = ucc}
      for _, m in ipairs({"windowStyle","windowTitle","allowTextEntry","deleteOnClose","level","behaviorAsLabels","windowCallback","html","transparent","bringToFront","alpha"}) do
        wv[m] = function(self, v)
          if m == "html" then
            self._html = v
            -- come la pagina vera: appena caricata dice "pronta"
            table.insert(timers, function() if ucc and ucc._cb then ucc._cb({body = {ready = true}}) end end)
          end
          return self
        end
      end
      function wv:frame(f) if f then self._frame = f end return self._frame end
      function wv:show() self._shown = true; return self end
      function wv:isVisible() return self._shown end
      function wv:hide() self._shown = false; return self end
      function wv:delete() self._deleted = true; self._shown = false end
      function wv:hswindow() return {focus = function() end} end
      function wv:evaluateJavaScript(js) table.insert(self._js, js) end
      if ucc and ucc._name == "tabbyorb" then ORBVIEW = wv
      elseif ucc and ucc._name == "tabbyfocus" then FOCUSVIEW = wv
      elseif ucc and ucc._name == "tabbysearch" then SEARCHVIEW = wv
      elseif ucc and ucc._name == "tabbynotice" then NOTICEVIEW = wv
      elseif ucc and ucc._name == "tabbyopen" then OPENVIEW = wv
      else MEMO = wv end
      return wv
    end,
    usercontent = {new = function(name) return {_name = name, setCallback = function(self, fn)
      self._cb = fn
      if name == "tabbyorb" then ORB_CB = fn
      elseif name == "tabbyfocus" then FOCUS_CB = fn
      elseif name == "tabbysearch" then SEARCH_CB = fn
      elseif name == "tabbynotice" then NOTICE_CB = fn
      elseif name == "tabbyopen" then OPEN_CB = fn
      else MEMO_CB = fn end
      return self
    end} end},
  },
  focus = function() FRONT = HS_APP end, reload = function() end, openConsole = function() end,
}

-- tastiera: mappa bidirezionale come quella vera
local codes = {["0"]=29,["1"]=18,["2"]=19,["3"]=20,["4"]=21,["5"]=23,["6"]=22,["7"]=26,["8"]=28,["9"]=25,
  a=0, c=8, f=3, m=46, s=1, w=13, l=37, n=45, i=34, t=17, v=9, delete=51, x=7, left=123, right=124, down=125, up=126, escape=53, ["return"]=36, padenter=76, tab=48}
for k, v in pairs(codes) do hs.keycodes.map[k] = v; hs.keycodes.map[v] = k end

function KEY(name, mods)
  local flags = {}
  for _, m in ipairs(mods or {}) do flags[m] = true end
  local ev = {getFlags = function() return flags end, getKeyCode = function() return codes[name] end,
              getCharacters = function() return CHARS or (#name == 1 and name) or "" end}
  for _, t in ipairs(TAPS) do
    if t.types[1] == 10 and t.on then return t.fn(ev) end
  end
end

-- scrive un testo, un carattere alla volta (come la tastiera)
function TYPE(s)
  for _, c in utf8.codes(s) do CHARS = utf8.char(c); KEY("x"); FLUSH() end
  CHARS = nil
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
