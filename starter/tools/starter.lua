-- MAME autoboot script: type the commands at the shell, play a note (z), quit (q); snapshots on the way.
-- Frames are MAME's 60 Hz frames; the boot takes ~12 s. The subscription is a global: a local one is collected.
local script = { {720, "chd /dd/STARTER\r"}, {900, "starter\r"}, {1500, "z"}, {1800, "q"} }
local queue, nextkey = {}, 0
frames = 0
sub = emu.add_machine_frame_notifier(function()
  frames = frames + 1
  for _, e in ipairs(script) do
    if frames == e[1] then for c in e[2]:gmatch('.') do table.insert(queue, c) end end
  end
  if #queue > 0 and frames >= nextkey then manager.machine.natkeyboard:post(table.remove(queue, 1)); nextkey = frames + 6 end
  if frames == 1100 or frames == 1400 or frames == 1700 or frames == 1900 then manager.machine.video:snapshot() end
  if frames == 2000 then manager.machine:exit() end
end)
