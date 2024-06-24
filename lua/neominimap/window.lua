local M = {}

local api = vim.api
local config = require("neominimap.config").get()
local log = require("neominimap.log")

---@type table<integer, integer>
local winid_to_mwinid = {}

--- The winid of the minimap attached to the given window
---@param winid integer
---@return integer?
M.get_minimap_winid = function(winid)
    return winid_to_mwinid[winid]
end

--- Set the winid of the minimap attached to the given window
---@param winid integer
---@param mwinid integer?
M.set_minimap_winid = function(winid, mwinid)
    winid_to_mwinid[winid] = mwinid
end

--- Return the list of windows that one minimap attached to
--- @return integer[]
M.list_windows = function()
    return vim.tbl_keys(winid_to_mwinid)
end

---@param winid integer
---@return boolean
local function should_show_minimap(winid)
    if not api.nvim_win_is_valid(winid) then
        return false
    end
    local util = require("neominimap.util")
    local bufnr = api.nvim_win_get_buf(winid)
    local buffer = require("neominimap.buffer")
    if not buffer.get_minimap_bufnr(bufnr) then
        return false
    end

    if util.win_get_height(winid) == 0 or api.nvim_win_get_width(winid) == 0 then
        return false
    end

    return true
end

---@param winid integer
local function get_window_config(winid)
    local util = require("neominimap.util")
    local minimap_height = util.win_get_height(winid)
    if config.max_minimap_height then
        minimap_height = math.min(minimap_height, config.max_minimap_height)
    end

    local col = api.nvim_win_get_width(winid)
    local row = 0

    local height = (function()
        local border = config.window_border
        if type(border) == "string" then
            return border == "none" and minimap_height or minimap_height - 2
        else
            local h = minimap_height
            if border[2] ~= "" then
                h = h - 1
            end
            if border[6] ~= "" then
                h = h - 1
            end
            return h
        end
    end)()

    return {
        relative = "win",
        win = winid,
        anchor = "NE",
        width = config.minimap_width + 4,
        height = height,
        row = row,
        col = col,
        focusable = false,
        zindex = config.z_index,
        style = "minimal",
        border = config.window_border,
        noautocmd = true,
    }
end

--- WARN: This function do not check whether a minimap should be created for this window nor this window is valid.
--- Create the minimap attached to the given window
---@param winid integer
---@return integer? mwinid winid of the minimap window if created, nil otherwise
local create_minimap_window = function(winid)
    local buffer = require("neominimap.buffer")
    local win_cfg = get_window_config(winid)

    local bufnr = api.nvim_win_get_buf(winid)
    local mbufnr = buffer.get_minimap_bufnr(bufnr)

    log.notify("Showing minimap for window " .. tostring(winid), vim.log.levels.INFO)
    if not mbufnr then
        log.notify("Minimap buffer not available for window " .. tostring(winid), vim.log.levels.INFO)
        return nil
    end
    local util = require("neominimap.util")
    local ret = util.noautocmd(function()
        local mwinid = api.nvim_open_win(mbufnr, false, win_cfg)
        M.set_minimap_winid(winid, mwinid)

        vim.wo[mwinid].winhl = "Normal:NeominimapBackground,FloatBorder:NeominimapBorder"
        vim.wo[mwinid].wrap = false
        vim.wo[mwinid].foldcolumn = "0"
        vim.wo[mwinid].scrolloff = 0
        vim.wo[mwinid].sidescrolloff = 0
        vim.wo[mwinid].winblend = 0
        log.notify("Window " .. tostring(mwinid) .. "is created for window " .. tostring(winid), vim.log.levels.INFO)
        return mwinid
    end)()
    return ret
end

--- Refresh the minimap attached to the given window
--- First, closing the existing minimap window
--- Next, if a minimap shoud be shown for this window, create it and attach buffer to it.
--- Finally, scroll the window to the right position.
---@param winid integer
---@return integer?
M.refresh_minimap_window = function(winid)
    log.notify("Refresing minimap for window " .. tostring(winid), vim.log.levels.INFO)
    if M.get_minimap_winid(winid) then
        M.close_minimap_window(winid)
    end
    if not should_show_minimap(winid) then
        log.notify("Minimap Shouldn't be shown for window " .. tostring(winid), vim.log.levels.INFO)
        return nil
    end
    local mwinid = create_minimap_window(winid)
    if not mwinid then
        return nil
    end

    -- TODO: Scroll the window
    --
    return mwinid
end

--- Close the minimap attached to the given window
---@param winid integer
---@return integer? mwinid winid of the minimap window if successfully removed, nil otherwise
M.close_minimap_window = function(winid)
    local mwinid = M.get_minimap_winid(winid)
    -- local mwinid = winid_to_mwinid[winid]
    M.set_minimap_winid(winid, nil)
    log.notify("Closing minimap for window " .. tostring(winid), vim.log.levels.INFO)
    if mwinid and api.nvim_win_is_valid(mwinid) then
        local util = require("neominimap.util")
        log.notify("Window " .. tostring(mwinid) .. " is to be deleted", vim.log.levels.INFO)
        util.noautocmd(api.nvim_win_close)(mwinid, true)
        return mwinid
    end
    return nil
end

-- --- Create all minimaps in the given tab if they should be shown
-- ---@param tabid integer
-- M.create_minimaps_in_tab = function(tabid)
--     local win_list = api.nvim_tabpage_list_wins(tabid)
--     for _, winid in ipairs(win_list) do
--         M.create_minimap_window(winid)
--     end
-- end

--- Refresh all minimaps in the given tab
---@param tabid integer
M.refresh_minimaps_in_tab = function(tabid)
    local win_list = api.nvim_tabpage_list_wins(tabid)
    for _, winid in ipairs(win_list) do
        M.refresh_minimap_window(winid)
    end
end

--- Close all minimaps in the given tab
---@param tabid integer
M.close_minimap_in_tab = function(tabid)
    local win_list = api.nvim_tabpage_list_wins(tabid)
    for _, winid in ipairs(win_list) do
        M.close_minimap_window(winid)
    end
end

-- --- Create all minimaps across tabs
-- M.create_all_minimap_windows = function()
--     local windows = api.nvim_list_wins()
--     for _, winid in ipairs(windows) do
--         M.create_minimap_window(winid)
--     end
-- end

--- Refresh all minimaps across tabs
M.refresh_all_minimap_windows = function()
    for _, winid in ipairs(M.list_windows()) do
        M.refresh_minimap_window(winid)
    end
end

--- Create all minimaps across tabs
M.close_all_minimap_windows = function()
    for _, winid in ipairs(M.list_windows()) do
        M.close_minimap_window(winid)
    end
end

return M
