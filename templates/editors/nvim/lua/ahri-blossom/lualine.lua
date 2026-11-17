-- {{ meta.name }} -- lualine theme
-- Generated from dotfiles/palette.json by render.py.
-- Usage:  require("lualine").setup({ options = { theme = require("ahri-blossom.lualine") } })
-- (or theme = "auto" / "ahri-blossom": lua/lualine/themes/ahri-blossom.lua re-exports this table)

local c = {
  crust    = "{{ crust }}",
  mantle   = "{{ mantle }}",
  base     = "{{ base }}",
  surface0 = "{{ surface0 }}",
  surface1 = "{{ surface1 }}",
  overlay  = "{{ overlay }}",
  subtext  = "{{ subtext }}",
  text     = "{{ text }}",
  sakura   = "{{ sakura }}",
  rose     = "{{ rose }}",
  gold     = "{{ gold }}",
  mint     = "{{ mint }}",
  spirit   = "{{ spirit }}",
  lavender = "{{ lavender }}",
}

local function mode(accent)
  return {
    a = { fg = c.crust, bg = accent, gui = "bold" },
    b = { fg = accent, bg = c.surface0 },
    c = { fg = c.subtext, bg = c.crust },
  }
end

return {
  normal   = mode(c.sakura),
  insert   = mode(c.mint),
  visual   = mode(c.lavender),
  replace  = mode(c.rose),
  command  = mode(c.gold),
  terminal = mode(c.spirit),
  inactive = {
    a = { fg = c.overlay, bg = c.crust, gui = "bold" },
    b = { fg = c.overlay, bg = c.crust },
    c = { fg = c.overlay, bg = c.crust },
  },
}
