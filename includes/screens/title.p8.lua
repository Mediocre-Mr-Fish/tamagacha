do
 screens.title = {}
 local _ENV, scn = rescope(screens.title, _ENV)

 function init()
 end
 
 function update()
  if btnp(❎) then
   switch_screen()
  end
 end

 function draw()
  asset_loader.draw_map("title", 0, 0)
 end
end