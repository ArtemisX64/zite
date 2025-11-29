pub const Cfg = struct {
    version: []const u8 = "0.1",
    script: [:0]const u8 =
        \\local core
        \\xpcall(function()
        \\  SCALE = tonumber(os.getenv("LITE_SCALE")) or SCALE
        \\  PATHSEP = package.config:sub(1, 1)
        \\  EXEDIR = EXEFILE:match("^(.+)[/\\\\].*$")
        \\  package.path = EXEDIR .. '/data/?.lua;' .. package.path
        \\  package.path = EXEDIR .. '/data/?/init.lua;' .. package.path
        \\  core = require('core')
        \\  core.init()
        \\  core.run()
        \\end, function(err)
        \\  print('Error: ' .. tostring(err))
        \\  print(debug.traceback(nil, 2))
        \\  if core and core.on_error then
        \\    pcall(core.on_error, err)
        \\  end
        \\  os.exit(1)
        \\end)
    ,
    api_type_font: [:0]const u8 = "Font",
    max_glyphset: usize = 256,
    cells_x: usize = 80,
    cells_y: usize = 50,
    cell_size: usize = 96,
    command_buf_size: usize = 1024 * 512,
};
