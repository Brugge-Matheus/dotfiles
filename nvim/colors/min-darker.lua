-- Port fiel do tema VSCode "Min Darker Theme" (gmsgarcia.min-darker-theme)
-- Fonte: https://github.com/GmsGarcia/min-darker/blob/master/themes/min-darker-theme.json
-- Valores copiados 1:1 do JSON (colors + tokenColors), sem inventar tons novos.

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.o.termguicolors = true
vim.g.colors_name = "min-darker"

-- 1:1 com o JSON original ------------------------------------------------
local c = {
  -- backgrounds
  bg          = "#0C0C0C", -- editor.background
  bg_dark     = "#070707", -- sideBar/activityBar/statusBar/tabs.background
  bg_float    = "#070707", -- editorSuggestWidget.background (popups, hover, picker/explorer) — igual à sidebar
  bg_dropdown = "#252525", -- dropdown.background (raramente usado no Neovim)
  bg_select   = "#303030", -- list.activeSelectionBackground / editor.lineHighlightBorder
  bg_hover    = "#262626", -- list.hoverBackground
  bg_focus    = "#292929", -- list.focusBackground
  bg_input    = "#2A2A2A", -- input.background / editorIndentGuide.background
  bg_guide    = "#383838", -- editorIndentGuide.activeBackground / badge.background
  bg_inactive = "#212121", -- list.inactiveSelectionBackground
  bg_peek     = "#242424", -- peekViewEditor.background

  -- foregrounds
  fg          = "#888888", -- foreground (UI padrão)
  fg_editor   = "#D4D4D4", -- editor.foreground (herdado do vs-dark base, tema não sobrescreve)
  fg_bright   = "#FAFAFA", -- tab.activeForeground / progressBar
  fg_dim      = "#727272", -- editorLineNumber.foreground / tab.inactiveForeground
  fg_hover    = "#9E9E9E", -- list.hoverForeground
  fg_select   = "#F5F5F5", -- list.activeSelectionForeground
  fg_input    = "#E0E0E0", -- input.foreground
  fg_muted    = "#484848", -- panelTitle.inactiveForeground
  fg_ignored  = "#444444", -- gitDecoration.ignoredResourceForeground
  border      = "#444444", -- focusBorder / peekView.border
  badge_fg    = "#C1C1C1", -- badge.foreground

  -- token colors (sintaxe) — saturação/brilho aumentados sobre o valor literal do
  -- JSON (que fica meio lavado no terminal); mesma família de matiz do tema original
  purple    = "#c792ea", -- functions, types, constructors, support.function
  keyword   = "#ff5c7a", -- keyword, storage.modifier/type
  blue      = "#5cb3ff", -- constant.language, variable.other.class/constant, support
  number_fg = "#ffffff", -- constant.numeric, property-value, attribute-name, json keys
  param     = "#ffb340", -- variable.parameter.function
  tag       = "#ffa657", -- entity.name.tag, string.quoted/regexp/interpolated/template
  str_muted = "#9db1c5", -- string (genérica/markup/markdown)
  comment   = "#7d8590", -- comment (levemente mais claro para não ficar ilegível)
  punct     = "#d4d4d4", -- punctuation.definition.arguments/dict/separator
  md_bold   = "#ff6b81", -- strong / markdown heading / bold
  link      = "#4fa8ff", -- meta.link.inline.markdown
  link_fg   = "#5cb3ff", -- string.other.link.title.markdown

  -- extras (não definidos no tema, usando defaults neutros do VSCode dark+ para não destoar)
  error   = "#ff5555",
  warn    = "#e5b567",
  info    = "#5cb3ff",
  hint    = "#c792ea",
  git_add = "#8fd76b",
  git_mod = "#e5b567",
  git_del = "#ff5c5c",
}

local hl = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor -------------------------------------------------------------------
hl("Normal",        { fg = c.fg_editor, bg = c.bg })
hl("NormalNC",       { fg = c.fg_editor, bg = c.bg })
hl("NormalFloat",   { fg = c.fg_editor, bg = c.bg_float })
hl("NormalSB",      { fg = c.fg,        bg = c.bg_dark })
hl("FloatBorder",   { fg = c.border,    bg = c.bg_float })
hl("FloatTitle",    { fg = c.fg_bright, bg = c.bg_float })

hl("SignColumn",     { bg = c.bg })
hl("LineNr",         { fg = c.fg_dim, bg = c.bg })
hl("CursorLineNr",   { fg = c.fg_bright, bg = c.bg })
hl("CursorLine",     { bg = c.bg_select })
hl("CursorColumn",   { bg = c.bg_select })
hl("ColorColumn",    { bg = c.bg_input })
hl("Visual",         { bg = c.bg_select })
hl("VisualNOS",      { bg = c.bg_select })
hl("EndOfBuffer",    { fg = c.bg, bg = c.bg })
hl("FoldColumn",     { fg = c.fg_dim, bg = c.bg })
hl("Folded",         { fg = c.fg_dim, bg = c.bg_input })
hl("NonText",        { fg = c.fg_muted })
hl("Whitespace",     { fg = c.fg_muted })
hl("SpecialKey",     { fg = c.fg_muted })
hl("Conceal",        { fg = c.fg_dim })

hl("MatchParen",     { fg = c.fg_bright, bg = c.bg_select, bold = true })
hl("Cursor",         { fg = c.bg, bg = c.fg_editor })
hl("TermCursor",     { link = "Cursor" })

hl("Search",         { fg = c.fg_bright, bg = c.bg_hover })
hl("IncSearch",      { fg = c.bg, bg = c.tag })
hl("CurSearch",      { link = "IncSearch" })

hl("WinSeparator",   { fg = c.bg_dark, bg = c.bg })
hl("VertSplit",      { link = "WinSeparator" })

hl("Pmenu",          { fg = c.fg_editor, bg = c.bg_dark })
hl("PmenuSel",       { fg = c.fg_select, bg = c.bg_select })
hl("PmenuSbar",      { bg = c.bg_input })
hl("PmenuThumb",     { bg = c.fg_dim })
hl("PmenuKind",      { fg = c.purple, bg = c.bg_dark })
hl("PmenuKindSel",   { fg = c.purple, bg = c.bg_select })

hl("TabLine",        { fg = c.fg_dim,    bg = c.bg_dark })
hl("TabLineFill",    { bg = c.bg_dark })
hl("TabLineSel",     { fg = c.fg_bright, bg = c.bg })

hl("StatusLine",     { fg = c.fg, bg = c.bg_dark })
hl("StatusLineNC",   { fg = c.fg_dim, bg = c.bg_dark })
hl("WildMenu",       { fg = c.fg_select, bg = c.bg_select })

hl("Directory",      { fg = c.fg_editor })
hl("Title",          { fg = c.fg_bright, bold = true })
hl("ErrorMsg",       { fg = c.error })
hl("WarningMsg",     { fg = c.warn })
hl("MoreMsg",        { fg = c.blue })
hl("Question",       { fg = c.blue })

hl("DiffAdd",        { fg = c.git_add, bg = "NONE" })
hl("DiffChange",     { fg = c.git_mod, bg = "NONE" })
hl("DiffDelete",     { fg = c.git_del, bg = "NONE" })
hl("DiffText",       { fg = c.fg_bright, bg = c.bg_select })

hl("SpellBad",       { sp = c.error, undercurl = true })
hl("SpellCap",       { sp = c.warn, undercurl = true })

-- Sintaxe (legado, sem treesitter) ------------------------------------------
hl("Comment",        { fg = c.comment, italic = true })
hl("Constant",       { fg = c.blue })
hl("String",         { fg = c.tag })
hl("Character",      { fg = c.tag })
hl("Number",         { fg = c.number_fg })
hl("Boolean",        { fg = c.number_fg })
hl("Float",          { fg = c.number_fg })
hl("Identifier",     { fg = c.fg_editor })
hl("Function",       { fg = c.purple })
hl("Statement",      { fg = c.keyword })
hl("Conditional",    { fg = c.keyword })
hl("Repeat",         { fg = c.keyword })
hl("Label",          { fg = c.keyword })
hl("Operator",       { fg = c.punct })
hl("Keyword",        { fg = c.keyword })
hl("Exception",      { fg = c.keyword })
hl("PreProc",        { fg = c.keyword })
hl("Include",        { fg = c.keyword })
hl("Define",         { fg = c.keyword })
hl("Macro",          { fg = c.keyword })
hl("PreCondit",      { fg = c.keyword })
hl("Type",           { fg = c.purple })
hl("StorageClass",   { fg = c.keyword })
hl("Structure",      { fg = c.purple })
hl("Typedef",        { fg = c.purple })
hl("Special",        { fg = c.tag })
hl("SpecialChar",    { fg = c.tag })
hl("Tag",            { fg = c.tag })
hl("Delimiter",      { fg = c.punct })
hl("SpecialComment", { fg = c.comment, italic = true })
hl("Underlined",     { underline = true })
hl("Ignore",         { fg = c.fg_muted })
hl("Todo",           { fg = c.bg, bg = c.number_fg, bold = true })

-- Treesitter -----------------------------------------------------------------
hl("@variable",              { fg = c.fg_editor })
hl("@variable.builtin",      { fg = c.blue })
hl("@variable.parameter",    { fg = c.param })
hl("@variable.member",       { fg = c.blue })
hl("@property",              { fg = c.blue })
hl("@field",                 { fg = c.blue })
hl("@constant",              { fg = c.blue })
hl("@constant.builtin",      { fg = c.blue })
hl("@constant.macro",        { fg = c.blue })
hl("@namespace",             { fg = c.blue })
hl("@symbol",                { fg = c.blue })

hl("@string",                { fg = c.tag })
hl("@string.regexp",         { fg = c.tag })
hl("@string.escape",         { fg = c.number_fg })
hl("@string.special",        { fg = c.tag })
hl("@character",             { fg = c.tag })
hl("@number",                { fg = c.number_fg })
hl("@number.float",          { fg = c.number_fg })
hl("@boolean",                { fg = c.number_fg })

hl("@function",               { fg = c.purple })
hl("@function.call",          { fg = c.purple })
hl("@function.builtin",       { fg = c.purple })
hl("@function.macro",         { fg = c.purple })
hl("@method",                 { fg = c.purple })
hl("@method.call",            { fg = c.purple })
hl("@constructor",            { fg = c.purple })

hl("@keyword",                { fg = c.keyword })
hl("@keyword.function",       { fg = c.keyword })
hl("@keyword.return",         { fg = c.keyword })
hl("@keyword.operator",       { fg = c.keyword })
hl("@keyword.import",         { fg = c.keyword })
hl("@keyword.repeat",         { fg = c.keyword })
hl("@keyword.conditional",    { fg = c.keyword })
hl("@keyword.exception",      { fg = c.keyword })
hl("@keyword.modifier",       { fg = c.keyword })
hl("@conditional",            { fg = c.keyword })
hl("@repeat",                 { fg = c.keyword })
hl("@exception",              { fg = c.keyword })
hl("@storageclass",           { fg = c.keyword })
hl("@type.qualifier",         { fg = c.keyword })
hl("@include",                { fg = c.keyword })

hl("@type",                   { fg = c.purple })
hl("@type.builtin",           { fg = c.purple })
hl("@type.definition",        { fg = c.purple })
hl("@attribute",              { fg = c.tag })
hl("@tag",                    { fg = c.tag })
hl("@tag.attribute",          { fg = c.number_fg })
hl("@tag.delimiter",          { fg = c.punct })

hl("@punctuation.bracket",    { fg = c.punct })
hl("@punctuation.delimiter",  { fg = c.punct })
hl("@punctuation.special",    { fg = c.punct })
hl("@operator",               { fg = c.punct })

hl("@comment",                { fg = c.comment, italic = true })
hl("@comment.documentation",  { fg = c.comment, italic = true })

hl("@markup.strong",          { fg = c.md_bold, bold = true })
hl("@markup.italic",          { italic = true })
hl("@markup.heading",         { fg = c.md_bold, bold = true })
hl("@markup.link",            { fg = c.link_fg })
hl("@markup.link.url",        { fg = c.link, underline = true })
hl("@markup.raw",             { fg = c.str_muted })

-- LSP semantic tokens (fallback simples) -------------------------------------
hl("@lsp.type.class",         { link = "@type" })
hl("@lsp.type.function",      { link = "@function" })
hl("@lsp.type.method",        { link = "@method" })
hl("@lsp.type.parameter",     { link = "@variable.parameter" })
hl("@lsp.type.property",      { link = "@property" })
hl("@lsp.type.variable",      { link = "@variable" })
hl("LspInlayHint",            { fg = c.fg_dim, bg = c.bg_input })

-- Diagnostics ------------------------------------------------------------
hl("DiagnosticError",           { fg = c.error })
hl("DiagnosticWarn",            { fg = c.warn })
hl("DiagnosticInfo",            { fg = c.info })
hl("DiagnosticHint",            { fg = c.hint })
hl("DiagnosticUnderlineError",  { sp = c.error, undercurl = true })
hl("DiagnosticUnderlineWarn",   { sp = c.warn, undercurl = true })
hl("DiagnosticUnderlineInfo",   { sp = c.info, undercurl = true })
hl("DiagnosticUnderlineHint",   { sp = c.hint, undercurl = true })
hl("DiagnosticVirtualTextError",{ fg = c.error, bg = c.bg })
hl("DiagnosticVirtualTextWarn", { fg = c.warn, bg = c.bg })
hl("DiagnosticVirtualTextInfo", { fg = c.info, bg = c.bg })
hl("DiagnosticVirtualTextHint", { fg = c.hint, bg = c.bg })

-- Gitsigns -----------------------------------------------------------------
hl("GitSignsAdd",     { fg = c.git_add })
hl("GitSignsChange",  { fg = c.git_mod })
hl("GitSignsDelete",  { fg = c.git_del })
hl("GitSignsCurrentLineBlame", { fg = c.fg_dim, italic = true })

-- Neo-tree (monocromático como no VSCode — sem cor especial para pastas) ----
hl("NeoTreeNormal",               { fg = c.fg, bg = c.bg_dark })
hl("NeoTreeNormalNC",             { fg = c.fg, bg = c.bg_dark })
hl("NeoTreeEndOfBuffer",          { fg = c.bg_dark, bg = c.bg_dark })
hl("NeoTreeRootName",             { fg = c.fg_bright, bold = true })
hl("NeoTreeFileName",             { fg = c.fg })
hl("NeoTreeFileNameOpened",       { fg = c.fg_select, bold = true })
hl("NeoTreeDirectoryName",        { fg = c.fg })
hl("NeoTreeDirectoryIcon",        { fg = c.fg_dim })
hl("NeoTreeSymbolicLinkTarget",   { fg = c.fg_dim, italic = true })
hl("NeoTreeIndentMarker",         { fg = c.bg_input })
hl("NeoTreeExpander",             { fg = c.fg_dim })
hl("NeoTreeModified",             { fg = c.param })
hl("NeoTreeDimText",              { fg = c.fg_muted })
hl("NeoTreeFilterTerm",           { fg = c.git_add, bold = true })
hl("NeoTreeCursorLine",           { bg = c.bg_select })
hl("NeoTreeTitleBar",             { fg = c.bg_dark, bg = c.fg_dim })

hl("NeoTreeGitAdded",     { fg = c.git_add })
hl("NeoTreeGitModified",  { fg = c.git_mod })
hl("NeoTreeGitDeleted",   { fg = c.git_del })
hl("NeoTreeGitIgnored",   { fg = c.fg_ignored })
hl("NeoTreeGitUntracked", { fg = c.git_add })
hl("NeoTreeGitUnstaged",  { fg = c.git_mod })
hl("NeoTreeGitStaged",    { fg = c.git_add })
hl("NeoTreeGitConflict",  { fg = c.git_del })

hl("NeoTreeTabActive",             { fg = c.fg_bright, bg = c.bg_dark, bold = true })
hl("NeoTreeTabInactive",           { fg = c.fg_dim,    bg = c.bg_dark })
hl("NeoTreeTabSeparatorActive",    { fg = c.bg_dark,   bg = c.bg_dark })
hl("NeoTreeTabSeparatorInactive",  { fg = c.bg_dark,   bg = c.bg_dark })
hl("NeoTreeWinSeparator",          { fg = c.bg_dark,   bg = c.bg_dark })
hl("NeoTreeVertSplit",             { fg = c.bg_dark,   bg = c.bg_dark })
hl("NeoTreeStatusLine",            { fg = c.fg_dim,    bg = c.bg_dark })
hl("NeoTreeStatusLineNC",          { fg = c.fg_dim,    bg = c.bg_dark })
hl("NeoTreeFloatBorder",           { link = "FloatBorder" })
hl("NeoTreeFloatNormal",           { link = "NormalFloat" })
hl("NeoTreeFloatTitle",            { link = "FloatTitle" })

-- Snacks (Explorer/Picker/Dashboard) — LazyVim usa Snacks Explorer por padrão,
-- não neo-tree. SnacksNormal herda de NormalFloat por padrão (default link),
-- então é preciso definir explicitamente para não pegar tons mais claros.
hl("SnacksNormal",         { fg = c.fg,        bg = c.bg_dark })
hl("SnacksNormalNC",       { fg = c.fg,        bg = c.bg_dark })
hl("SnacksWinBar",         { fg = c.fg_bright, bg = c.bg_dark, bold = true })
hl("SnacksWinBarNC",       { fg = c.fg_dim,    bg = c.bg_dark })
hl("SnacksTitle",          { fg = c.fg_bright, bg = c.bg_dark, bold = true })
hl("SnacksFooter",         { fg = c.fg_dim,    bg = c.bg_dark })
hl("SnacksWinSeparator",   { fg = c.bg_dark,   bg = c.bg_dark })
hl("SnacksBackdrop",       { bg = "#000000" })

hl("SnacksPickerDirectory",   { fg = c.fg })
hl("SnacksPickerFile",        { fg = c.fg })
hl("SnacksPickerDir",         { fg = c.fg_dim })
hl("SnacksPickerPathIgnored", { fg = c.fg_ignored })
hl("SnacksPickerPathHidden",  { fg = c.fg_dim })
hl("SnacksPickerSelected",    { fg = c.fg_select, bold = true })
hl("SnacksPickerIdx",         { fg = c.fg_dim })
hl("SnacksPickerBorder",      { fg = c.bg_dark, bg = c.bg_dark })

hl("WhichKeyFloat",  { bg = c.bg_dark })
hl("WhichKeyBorder",  { fg = c.bg_dark, bg = c.bg_dark })

-- terminal ansi -----------------------------------------------------------
vim.g.terminal_color_0  = c.bg_dark
vim.g.terminal_color_8  = "#5c5c5c"
vim.g.terminal_color_7  = c.fg
vim.g.terminal_color_15 = c.fg_bright
vim.g.terminal_color_1  = c.git_del
vim.g.terminal_color_9  = c.git_del
vim.g.terminal_color_2  = c.git_add
vim.g.terminal_color_10 = c.git_add
vim.g.terminal_color_3  = c.number_fg
vim.g.terminal_color_11 = c.number_fg
vim.g.terminal_color_4  = c.blue
vim.g.terminal_color_12 = c.blue
vim.g.terminal_color_5  = c.purple
vim.g.terminal_color_13 = c.purple
vim.g.terminal_color_6  = c.tag
vim.g.terminal_color_14 = c.tag
