local M = {}

---@class Neominimap.Variables.Window
local w_default = {}

---@param window integer
---@param name string
---@param value any
M.win_set_var = function(window, name, value)
    if not vim.w[window].neominimap_var then
        vim.w[window].neominimap_var = {}
    end
    vim.w[window].neominimap_var[name] = value
end

---@param window integer
---@param name string
---@return any
M.win_get_var = function(window, name)
    if not vim.w[window].neominimap_var then
        vim.w[window].neominimap_var = {}
    end
    return vim.w[window].neominimap_var[name]
end

---@param window integer
---@return Neominimap.Variables.Window
local get_w = function(window)
    return setmetatable({}, {
        __index = function(_, k)
            return M.win_get_var(window, k)
        end,
        __newindex = function(_, k, v)
            M.win_set_var(window, k, v)
        end,
    })
end

---@type table<integer, Neominimap.Variables.Window> | Neominimap.Variables.Window
M.w = setmetatable({}, {
    __index = function(_, k)
        if type(k) == "number" then
            return get_w(k)
        else
            return M.win_get_var(0, k)
        end
    end,
    __newindex = function(_, k, v)
        M.win_set_var(0, k, v)
    end,
})

return M
