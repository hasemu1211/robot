local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action
local mux = wezterm.mux

-- ─────────────────────────────────────────────
-- 프로젝트 선택기
-- ─────────────────────────────────────────────
local function get_projects()
  local projects = {}
  -- ~/robot/는 parent template 레포. child들(directory 또는 symlink)이 여기 등록됨.
  -- 프로젝트 판별 기준: 하위에 `.claude/` 디렉토리 존재 (bootstrap-child.sh가 생성).
  -- 이로써 scripts/, wiki/, .omc/ 등 non-project 디렉토리 자동 제외.
  local projects_dir = wezterm.home_dir .. '/robot'
  local handle = io.popen(
    'for d in ' .. projects_dir .. '/*/; do ' ..
    '  [ -d "${d}.claude" ] && echo "$d"; ' ..
    'done 2>/dev/null'
  )
  if handle then
    for path in handle:lines() do
      local name = path:match('([^/]+)/?$') or path
      table.insert(projects, { label = '  ' .. name, id = path:gsub('/$', '') })
    end
    handle:close()
  end
  -- parent robot 자체도 pickable (global wiki 작업, bootstrap-child.sh 실행용)
  table.insert(projects, 1, {
    label = '  robot (parent)',
    id = wezterm.home_dir .. '/robot',
  })
  return projects
end

local function open_project_picker(window, pane)
  local projects = get_projects()
  window:perform_action(act.InputSelector {
    title = '  프로젝트 선택',
    choices = projects,
    fuzzy = true,
    action = wezterm.action_callback(function(win, p, id, label)
      if id then
        win:perform_action(act.SpawnCommandInNewTab {
          cwd = id,
        }, p)
      end
    end),
  }, pane)
end

-- WezTerm 시작 시 프로젝트 선택기 자동 실행
wezterm.on('gui-startup', function(cmd)
  local tab, pane, window = mux.spawn_window(cmd or {})
  window:gui_window():perform_action(act.InputSelector {
    title = '  프로젝트 선택',
    choices = get_projects(),
    fuzzy = true,
    action = wezterm.action_callback(function(win, p, id, label)
      if id then
        win:perform_action(act.SpawnCommandInNewTab { cwd = id }, p)
      end
    end),
  }, pane)
end)

-- ─────────────────────────────────────────────
-- 탭 이름: 번호 + 현재 디렉토리 + 실행 중인 프로세스
-- ─────────────────────────────────────────────
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local pane = tab.active_pane

  -- 현재 디렉토리 (마지막 폴더 이름만)
  local cwd = pane.current_working_dir
  local cwd_str = '~'
  if cwd then
    local path = cwd.file_path
    -- 홈 디렉토리 ~ 로 치환
    local home = os.getenv('HOME') or ''
    path = path:gsub('^' .. home, '~')
    -- 마지막 경로만 표시
    cwd_str = path:match('[^/]+/?$') or path
    cwd_str = cwd_str:gsub('/$', '')
  end

  -- 실행 중인 프로세스 (bash/zsh/sh 는 숨김)
  local process = pane.foreground_process_name or ''
  process = process:match('[^/]+$') or ''
  local shells = { bash = true, zsh = true, sh = true, fish = true }
  local proc_str = ''
  if process ~= '' and not shells[process] then
    proc_str = '  ' .. process
  end

  local index = tab.tab_index + 1
  local title = ' ' .. index .. '  ' .. cwd_str .. proc_str .. ' '

  if tab.is_active then
    return {
      { Foreground = { Color = '#7aa2f7' } },
      { Text = title },
    }
  end
  return {
    { Foreground = { Color = '#565f89' } },
    { Text = title },
  }
end)

-- ─────────────────────────────────────────────
-- 상태바: 왼쪽 (워크스페이스 이름)
-- ─────────────────────────────────────────────
wezterm.on('update-left-status', function(window, pane)
  local workspace = window:active_workspace()
  window:set_left_status(wezterm.format {
    { Foreground = { Color = '#7aa2f7' } },
    { Text = '  ' .. workspace .. '  ' },
    { Foreground = { Color = '#3b4261' } },
    { Text = '│' },
  })
end)

-- ─────────────────────────────────────────────
-- 상태바: 오른쪽 (날짜 / 시간)
-- ─────────────────────────────────────────────
wezterm.on('update-right-status', function(window, pane)
  local date = wezterm.strftime '%Y-%m-%d'
  local time = wezterm.strftime '%H:%M:%S'
  window:set_right_status(wezterm.format {
    { Foreground = { Color = '#3b4261' } },
    { Text = '│' },
    { Foreground = { Color = '#9ece6a' } },
    { Text = '  ' .. date },
    { Foreground = { Color = '#3b4261' } },
    { Text = '  │  ' },
    { Foreground = { Color = '#e0af68' } },
    { Text = time .. '  ' },
  })
end)

-- ─────────────────────────────────────────────
-- 폰트
-- ─────────────────────────────────────────────
config.font = wezterm.font('JetBrainsMono Nerd Font Mono', { weight = 'Regular' })
config.warn_about_missing_glyphs = false
config.font_size = 14.0
config.line_height = 1.2

-- ─────────────────────────────────────────────
-- 테마
-- ─────────────────────────────────────────────
config.color_scheme = 'Tokyo Night'

-- ─────────────────────────────────────────────
-- 창 외관
-- ─────────────────────────────────────────────
config.window_background_opacity = 0.95
config.window_decorations = 'TITLE | RESIZE'
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.initial_cols = 220
config.initial_rows = 50

-- ─────────────────────────────────────────────
-- 탭바
-- ─────────────────────────────────────────────
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = false
config.tab_max_width = 36
config.status_update_interval = 1000

-- ─────────────────────────────────────────────
-- 스크롤
-- ─────────────────────────────────────────────
config.scrollback_lines = 10000
config.enable_scroll_bar = true

-- ─────────────────────────────────────────────
-- IME (한국어 입력)
-- ─────────────────────────────────────────────
config.use_ime = true

-- ─────────────────────────────────────────────
-- 키 바인딩
-- ─────────────────────────────────────────────
config.keys = {

  -- ── 탭 관리 ──────────────────────────────────
  -- 새 탭: 현재 디렉토리에서 열기
  { key = 't', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function(window, pane)
      local cwd = pane:get_current_working_dir()
      if cwd then
        window:perform_action(act.SpawnCommandInNewTab { cwd = cwd.file_path }, pane)
      else
        window:perform_action(act.SpawnTab 'CurrentPaneDomain', pane)
      end
    end)
  },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },
  { key = 'LeftArrow',  mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(1) },
  { key = '1', mods = 'CTRL|SHIFT', action = act.ActivateTab(0) },
  { key = '2', mods = 'CTRL|SHIFT', action = act.ActivateTab(1) },
  { key = '3', mods = 'CTRL|SHIFT', action = act.ActivateTab(2) },
  { key = '4', mods = 'CTRL|SHIFT', action = act.ActivateTab(3) },
  { key = '5', mods = 'CTRL|SHIFT', action = act.ActivateTab(4) },
  { key = '6', mods = 'CTRL|SHIFT', action = act.ActivateTab(5) },
  { key = '7', mods = 'CTRL|SHIFT', action = act.ActivateTab(6) },
  { key = '8', mods = 'CTRL|SHIFT', action = act.ActivateTab(7) },
  { key = '9', mods = 'CTRL|SHIFT', action = act.ActivateTab(8) },

  -- ── 패널 분할 (현재 디렉토리 유지) ────────────
  -- ── 패널 분할 (현재 디렉토리 유지) ────────────
  { key = '|', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function(window, pane)
      local cwd = pane:get_current_working_dir()
      window:perform_action(act.SplitHorizontal {
        domain = 'CurrentPaneDomain',
        cwd = cwd and cwd.file_path or nil,
      }, pane)
    end)
  },
  { key = '_', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function(window, pane)
      local cwd = pane:get_current_working_dir()
      window:perform_action(act.SplitVertical {
        domain = 'CurrentPaneDomain',
        cwd = cwd and cwd.file_path or nil,
      }, pane)
    end)
  },

  -- ── 패널 포커스 이동 ──────────────────────────
  { key = 'h', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },

  -- ── 패널 닫기 / 줌 ───────────────────────────
  { key = 'x', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },
  { key = 'z', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },

  -- ── 패널 크기 조절 ────────────────────────────
  { key = 'h', mods = 'CTRL|SHIFT|ALT', action = act.AdjustPaneSize { 'Left',  5 } },
  { key = 'j', mods = 'CTRL|SHIFT|ALT', action = act.AdjustPaneSize { 'Down',  5 } },
  { key = 'k', mods = 'CTRL|SHIFT|ALT', action = act.AdjustPaneSize { 'Up',    5 } },
  { key = 'l', mods = 'CTRL|SHIFT|ALT', action = act.AdjustPaneSize { 'Right', 5 } },

  -- ── 워크스페이스 ──────────────────────────────
  { key = 's', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'WORKSPACES' } },
  { key = 'n', mods = 'CTRL|SHIFT', action = act.PromptInputLine {
      description = '새 워크스페이스 이름:',
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:perform_action(act.SwitchToWorkspace { name = line }, pane)
        end
      end),
    }
  },
  { key = 'r', mods = 'CTRL|SHIFT', action = act.PromptInputLine {
      description = '워크스페이스 새 이름:',
      action = wezterm.action_callback(function(window, pane, line)
        if line and line ~= '' then
          wezterm.mux.rename_workspace(window:active_workspace(), line)
        end
      end),
    }
  },
  { key = 'd', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function(window, pane)
      local workspaces = wezterm.mux.get_workspace_names()
      if #workspaces <= 1 then return end
      local current = window:active_workspace()
      for _, ws in ipairs(workspaces) do
        if ws ~= current then
          window:perform_action(act.SwitchToWorkspace { name = ws }, pane)
          break
        end
      end
      for _, mux_win in ipairs(wezterm.mux.all_windows()) do
        if mux_win:get_workspace() == current then
          for _, tab in ipairs(mux_win:tabs()) do
            tab:activate()
            window:perform_action(act.CloseCurrentTab { confirm = false }, pane)
          end
        end
      end
    end)
  },

  -- ── 프로젝트 선택기 ──────────────────────────
  { key = 'p', mods = 'CTRL|SHIFT', action = wezterm.action_callback(open_project_picker) },

  -- ── 기타 ─────────────────────────────────────
  { key = 'f',     mods = 'CTRL|SHIFT', action = act.ToggleFullScreen },
  { key = 'c',     mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v',     mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'Space', mods = 'CTRL|SHIFT', action = act.QuickSelect },
  { key = '=',     mods = 'CTRL',       action = act.IncreaseFontSize },
  { key = '-',     mods = 'CTRL',       action = act.DecreaseFontSize },
  { key = '0',     mods = 'CTRL',       action = act.ResetFontSize },

  -- ── 단축키 안내 패널 ──────────────────────────
  { key = '?', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function(window, pane)
      local keybindings_path = os.getenv('HOME') .. '/.config/wezterm/KEYBINDINGS.md'
      wezterm.run_child_process({
        'wezterm', 'cli', 'split-pane',
        '--pane-id', tostring(pane:pane_id()),
        '--right', '--percent', '38',
        '--', 'bash', '-c',
        '/usr/bin/glow --pager ' .. keybindings_path,
      })
    end)
  },
}

-- ─────────────────────────────────────────────
-- 마우스: 드래그 선택→자동 복사, 우클릭 붙여넣기
-- ─────────────────────────────────────────────
config.mouse_bindings = {
  -- 우클릭으로 클립보드 붙여넣기
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.PasteFrom 'Clipboard',
  },
  -- 드래그 릴리즈 시 선택 텍스트를 클립보드+기본선택영역에 복사
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  -- Shift+드래그도 동일 (tmux 우회용)
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'SHIFT',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  -- 더블클릭: 단어 선택 + 복사
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  -- 트리플클릭: 줄 선택 + 복사
  {
    event = { Up = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
}

return config
