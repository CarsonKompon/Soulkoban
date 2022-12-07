pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
--sOULKOBAN bY cARSON kOMPON

function _init()
	music(8)
	
	mainmenu = true
	
	--mouse/touch stuff
	init_swipes()
	poke(0x5f2d,1)
	click=false
	lastclick=false
end

function _update60()
	
	click=stat(34)
	
	if mainmenu then
		if btn() > 0
		or (click > 0 and lastclick==0) then
			game_init()
		end
	else
		game_update()
	end
	
	lastclick=click
	
end

function _draw()
	
	if mainmenu then
		cls()
		
		rectfill(0,0,128,7,7)
		rectfill(0,0,7,128,7)
		rectfill(120,0,128,128,7)
		rectfill(0,120,128,128,7)
		
		spr(28,60+flr(2*sin(time()/2)+0.5),
		64+flr(5*sin(time()/4)+0.5))
		
		sspr(32,37,76,13,26,18)
		
		if flr(time())%2==0 then
			local _txt = "cLICK OR tAP TO pLAY"
			print(_txt,63-#_txt*2,100)
		end
		
	else
		game_draw()
	end
	
end
-->8
--game logic

function game_init()
	music(0)
	
	mainmenu=false
	
	o={}
	init_player()
	init_objects()
	init_npcs()
	init_particles()
	
	init_dialogue()
	
	timer=0
	
	--position objects from map
	local _all = get_all_objs()
	for i=0,127 do
		for j=0,63 do
			for _o in all(_all) do
				local _mm = mget(i,j)
				if _mm == _o.spw or _mm == _o.sp then
					if _o.template==1 then
						add(o,{
							template=2,
							caninteract=_o.caninteract or false,
							rx=i*8,ry=j*8,x=i*8,y=j*8,
							sp=_o.sp,
							update=_o.update,
							interact=_o.interact,
							draw=_o.draw
						})
						add(o,_newo)
					elseif _o.template==0 then
						_o.rx = i*8
						_o.ry = j*8
						_o.x = i*8
						_o.y = j*8
					end
					if(_mm ~= _o.spw) mset(i,j,0)
					--_o.template=2
				end
			end
		end
	end
	
	
end

function game_update()
	
	check_swipes()
	
	local _all = get_all_objs()
	for _o in all(_all) do
		_o:update()
		--lerp to position
		_o.x = lerp(_o.x,_o.rx,0.325)
		_o.y = lerp(_o.y,_o.ry,0.325)
	end
	
	for _p in all(parts) do
		_p:update()
	end
	
	timer+=1
	
	
end

function game_draw()
	
	if coins >= 10 and ply.ry < -8 then
		camera(0,0)
		cls()
		
		for i=1,1000 do
			line(63,63,rnd(200)-30,rnd(200)-30,
			rnd({13,5,1}))
		end
		
		spr(28,60+timer/3,60)
		spr(1,60-timer/3,60)
		
		fade1(flr(timer/7))
		
		
		if timer > 240 then
			load("index.p8")
		end
		
	else
		cls()
		map(0,0,0,0,128,128,15)
		
		ply:draw()
		for _n in all(npcs) do
			spr(_n.sp,round(_n.x),round(_n.y),
			1,1,_n.flp)
		end
		for _o in all(o) do
			_o:draw()
		end
		
		
		for _p in all(parts) do
			_p:draw()
		end
		
		draw_dialogue()
		draw_gui()
	end
end

function get_all_objs()
	local _all = {ply}
	for _v in all(o) do add(_all,_v) end
	for _v in all(npcs) do add(_all,_v) end
	return _all
end
-->8
--player

function init_player()
	camx=0
	camy=0
	
	win=false
	
	ply={
		template=0,
		rx=64,ry=64,x=64,y=64,
		flp=false,
		sp=1,
		
		--player update
		update=function(self)
			
			if coins >= 10 then
				
				if(not win) win = 0
				
				win -= 0.0025
				local _lry = ply.ry
				ply.ry+=win
				
				if _lry > -8 and ply.ry <= -8 then
					timer=0
				end
				
			else
				
				if not istalking then
					--get input
					local _in = get_input()
					if _in ~= -1 then
						local _tox = 0
						local _toy = 0
						--get direction
						if _in == 0 then
							_tox = 8
							self.flp = false
						elseif _in == 1 then
							_toy = 8
						elseif _in == 2 then
							_tox = -8
							self.flp = true
						else
							_toy = -8
						end
						--check for collision
						if fget(mget(
						(self.rx+_tox)/8,
						(self.ry+_toy)/8),0) then
							bump(self,_tox,_toy)
						else
							self._hasmoved = true
							self.rx += _tox
							self.ry += _toy
							--loop thru all objs
							for _b in all(get_all_objs()) do
								--if obj is at goto pos
								if _b.sp~=17 and _b.sp~=1
								and self.rx == _b.rx
								and self.ry == _b.ry then
									_hasmoved=false
									if _b.caninteract then
										self.rx -= _tox
										self.ry -= _toy
										_b:interact()
										bump(self,_tox,_toy,false)
									end
								--if box is at goto pos
								elseif _b.sp==17 and self.rx == _b.rx
								and self.ry == _b.ry then
									--if there's a wall behind the box
									if fget(mget(
									(self.rx+_tox)/8,
									(self.ry+_toy)/8),1) then
										self.rx -= _tox
										self.ry -= _toy
										bump(self,_tox,_toy)
									else
										local _canmove = true
										--check for obj behind box
										for _bb in all(get_all_objs()) do
											if _b.rx+_tox==_bb.rx
											and _b.ry+_toy==_bb.ry
											and not fget(_bb.sp,2) then
												_canmove=false
											end
										end
										if _canmove then
											_b.rx += _tox
											_b.ry += _toy
											sfx(11)
										else
											self.rx -= _tox
											self.ry -= _toy
											bump(self,_tox,_toy)
										end
									end
								end
							end
							--play sound if moved
							if self._hasmoved then
								if _in==1 or _in==3 then sfx(9)
								else sfx(8) end
							end
						end
					end
				else
					update_dialogue()
				end
				
				camx=flr(self.rx/128)*128
				camy=flr(self.ry/128)*128
				camera(camx,camy,128,128)
				
			end
			
		end,
		
		
		--player draw
		draw=function(self)
			local _sp = 1
			if round(self.x) ~= self.rx
			or round(self.y) ~= self.ry then
				_sp=2+((timer/6)%2)
			end
			
			spr(_sp,round(self.x),round(self.y),
			1,1,self.flp)
		end
	}
	--add(o,ply)
	
	guioff=-32
	guix=-32
	guitimer=0
	coins=0
	maxcoins=3
	
end

function draw_gui()
	--gui timer
	if guitimer > 0 then
		guitimer -= 1
		if guitimer == 0 then
			guioff = -32
		end
	end
	--draw gui
	if round(guix) ~= -32 then
		rectfill(camx+guix+3,camy+2,
		camx+guix+32,camy+8,0)
		spr(34+(flr(timer/4)%2),camx+guix+3,camy+2)
		local _str1 = tostr(coins)
		local _str2 = tostr(maxcoins)
		if coins < 10 then
			_str1 = "0" .. _str1
		end
		if maxcoins < 10 then
			_str2 = "0" .. _str2
		end
		print(_str1.."/".._str2,
		camx+guix+12,camy+3,7)
	end
	--lerp gui
	guix = lerp(guix,guioff,0.125)
end

function give_coin(_x,_y)
	coins+=1
	guioff=0
	guitimer=240
	p_burst(_x+4,_y+4,20,4,0.3,20,9)
end

function bump(self,_tox,_toy,_snd)
	local _snd = _snd or true
	if(_snd) sfx(10)
	self.x += _tox/4
	self.y += _toy/4
	self._hasmoved = false
end
-->8
--input methods

function init_swipes()
	swiping=false
	swipedir=-1
	swipex=0
	swipey=0
	input=-1
end

function check_swipes()
	if not swiping and lastclick==0 then
		if click > 0 then
			swiping = true
			swipex = stat(32)
			swipey = stat(33)
		end
	elseif swiping and lastclick>0 then
		local _xx = stat(32)
		local _yy = stat(33)
		if click == 0
		or dist(swipex-_xx,swipey-_yy) > 20 then
			local _d = atan2(_xx - swipex,
			_yy - swipey)
			swipe_dir(_d)
			swiping = false
		end
	end
end

function swipe_dir(_d)
	
	local _dir = -1
	if _d > 7/8 or _d <= 1/8 then
		_dir = 0
	elseif _d > 1/8 and _d <= 3/8 then
		_dir = 3
	elseif _d > 3/8 and _d <= 5/8 then
		_dir = 2
	elseif _d > 5/8 and _d <= 7/8 then
		_dir = 1
	end
	
	input = _dir
	
end

function get_input()
	
	if btnp(➡️) then
		return 0
	elseif btnp(⬇️) then
		return 1
	elseif btnp(⬅️) then
		return 2
	elseif btnp(⬆️) then
		return 3
	else
		local _i = input
		input = -1
		return _i
	end
	
end

function dist(dx,dy)
 local maskx,masky=dx>>31,dy>>31
 local a0=(dx+maskx)^^maskx
 local b0=(dy+masky)^^masky
 if a0>b0 then
  return a0*0.9609+b0*0.3984
 end
 return b0*0.9609+a0*0.3984
end


--useful functions

function lerp(a,b,t)
	return a+t*(b-a)
end

function round(a)
	return flr(a+0.5)
end

-- fade to white
local fadetable1={
{0,0,1,1,5,5,5,13,13,13,6,6,6,6,7},
{1,1,5,5,13,13,13,13,13,6,6,6,6,6,7},
{2,2,2,13,13,13,13,13,6,6,6,6,6,7,7},
{3,3,3,3,13,13,13,13,6,6,6,6,6,7,7},
{4,4,4,4,4,14,14,14,15,15,15,15,15,7,7},
{5,5,13,13,13,13,13,6,6,6,6,6,6,7,7},
{6,6,6,6,6,6,6,6,7,7,7,7,7,7,7},
{7,7,7,7,7,7,7,7,7,7,7,7,7,7,7},
{8,8,8,8,14,14,14,14,14,14,15,15,15,7,7},
{9,9,9,10,10,10,15,15,15,15,15,15,15,7,7},
{10,10,10,10,10,15,15,15,15,15,15,15,7,7,7},
{11,11,11,11,11,11,6,6,6,6,6,6,6,7,7},
{12,12,12,12,12,12,6,6,6,6,6,6,7,7,7},
{13,13,13,13,6,6,6,6,6,6,6,6,7,7,7},
{14,14,14,14,14,15,15,15,15,15,15,7,7,7,7},
{15,15,15,15,15,15,15,7,7,7,7,7,7,7,7}
}

function fade1(i)
 for c=0,15 do
  if flr(i+1)>=16 then
   pal(c,7,1)
  else
      pal(c,fadetable1[c+1][flr(i+1)],1)
     end
 end
end
-->8
--world objects

function init_objects()
	
	--pushable box
	pushbox={
		template=1,
		x=-32,y=-32,rx=-32,ry=-32,
		sp=17,spw=20,
		update=function(self)
			local _activate=true
			for _o in all(o) do
				if _o.sp==17
				and _o.rx >= camx
				and _o.rx < camx+128
				and _o.ry >= camy
				and _o.ry < camy+128 then
					if not fget(mget(_o.rx/8,_o.ry/8),2) then
						_activate=false
						break
					end
				end
			end
			if _activate then
				local _cx = flr(camx/128)
				local _cy = flr(camy/128)
				--room 1,1
				if _cx == 1 and _cy == 1 then
					if mget(23,10) ~= 19 then
						sfx(19)
						destroy(23,10,19)
						destroy(2,10)
						if npc_catboy.state == 1 then
							npc_catboy.state = 3
						else
							npc_catboy.state = 2
						end
					end
				--room 2,0
				elseif _cx == 2 and _cy == 0 then
					if mget(34,12) ~= 0 then
						sfx(19)
						destroy(34,12)
					end
				--room 0,1
				elseif _cx == 0 and _cy == 1 then
					if not secret1 then
						sfx(19)
						destroy(5,17)
						destroy(6,17)
						destroy(10,17)
						destroy(11,17)
						p_dust(34*8,12*8,6)
						secret1=true
					end
				--room 2,2
				elseif _cx == 2 and _cy == 2 then
					if mget(32,39) ~= 0 then
						sfx(19)
						destroy(32,39)
						destroy(32,40)
						if npc_defaultman.state == 1 then
							npc_defaultman.state = 3
						else
							npc_defaultman.state = 2
						end
					end
				--room 5,1
				elseif _cx == 5 and _cy == 1 then
					if mget(87,20) ~= 0 then
						sfx(19)
						destroy(87,20)
						destroy(88,20)
					end
				--room 5,0
				elseif _cx == 5 and _cy == 0 then
					if mget(95,11) ~= 0 then
						sfx(19)
						destroy(95,11)
						destroy(95,12)
						npc_skeleman.state = 1
					end
				end
				--lock them in place
				for _hh in all (o) do
					if _hh.sp==17
					and _hh.rx>=camx
					and _hh.rx<camx+128
					and _hh.ry>=camy
					and _hh.ry<camy+128 then
						_hh.sp=23
					end
				end
			end
		end,
		draw = function(self)
			spr(self.sp,round(self.x),round(self.y))
		end,
	}
	add(o,pushbox)
	
	--coin
	coinobj={
		template=1,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,
		sp=34,iii=0,
		update=function(self)
			if(not self.iii) self.iii=0
			if self.iii == 0 then
				maxcoins+=1
				self.iii = 1
			end
		end,
		interact=function(self, final)
			final = final or false
			if final then music(16)
			else sfx(24) end
			ply.rx=self.rx
			ply.ry=self.ry
			give_coin(self.rx,self.ry)
			del(o,self)
		end,
		draw = function(self)
			local _dist = abs(ply.rx-self.rx)+
			abs(ply.ry-self.ry)
			if _dist<=24 then
				local _col = 4
				if _dist/24<=0.5 then
					_col=9
				elseif _dist >=24 then
					fillp(▤|0.25)
				end
				pal(9,_col)
				spr(self.sp+(flr(timer/4)%2),
				round(self.x),round(self.y))
				pal(9,9)
				fillp()
			end
		end,
	}
	finalcoinobj = {
		template=1,caninteract=false,
		x=864,y=40,rx=864,ry=40,
		sp=26,iii=1,
		update=function(self)
			coinobj.update(self)
			if coins >= 9 then
				self.caninteract=true
			end
		end,
		interact=function(self)
			if(coins >= 9) coinobj.interact(self,true)
		end,
		draw=function(self)
			if(coins >= 9) coinobj.draw(self)
		end
	}
	add(o,coinobj)
	add(o,finalcoinobj)
	
	--hidden nook
	nook={
		template=1,
		x=-32,y=-32,rx=-32,ry=-32,
		sp=22,found=false,
		update=function(self)
			if not self.found then
				if ply.rx == self.rx
				and ply.ry == self.ry then
					local _ncount = 0
					for _o in all(o) do
						if _o.sp==22
						and _o.rx >= camx
						and _o.rx < camx+128
						and _o.ry >= camy
						and _o.ry < camy+128 then
							if(_o.found) _ncount+=1
						end
					end
					sfx(20+_ncount)
					if _ncount == 4 then
						give_coin(self.rx,self.ry)
					end
					p_text(self.rx+4,self.ry,
					tostr(1+_ncount),2,0.1,9)
					self.found=true
				end
			end
		end,
		draw = function(self)
			if(not self.found) pal(1,0)
			spr(self.sp,self.rx,self.ry)
			pal(1,1)
		end,
	}
	add(o,nook)
	
	--reset buttons 
	local _rstbtn1 = {
		template=1,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,
		sp=48,
		update=function(self)
			if(not self.tim) self.tim=0
			if self.tim > 0 then
				self.tim -= 1
				if self.tim == 0 then
					self.sp -= 2
				end
			end
		end,
		interact=function(self)
			--reset all the boxes on screen
			if ply.ry > self.ry then
				if(self.sp <= 49) self.sp+=2
				self.tim=8
				sfx(18)
				for _o in all(o) do
					if _o.sp>=48 and _o.sp <=51 then
						if (_o.rx==self.rx-8 and _o.ry==self.ry)
						or (_o.rx==self.rx+8 and _o.ry==self.ry)
						then
							if(_o.sp <= 49) _o.sp+=2
							_o.tim=8
						end
					end
				end
				for _o in all(o) do
					if _o.sp==23
					and _o.rx>=camx
					and _o.rx<camx+128
					and _o.ry>=camy
					and _o.ry<camy+128 then
						return 0
					end
				end
				local _ii = flr(camx/8)
				local _jj = flr(camy/8)
				for _o in all(o) do
					if _o.sp==17
					and _o.rx >= camx
					and _o.rx < camx+128
					and _o.ry >= camy
					and _o.ry < camy+128 then
						if mget(_o.rx/8,_o.ry/8)~=20 then
							p_dust(_o.rx+4,_o.ry+4,6)
						end
						del(o,_o)
					end
				end
				for i=_ii,_ii+15 do
					for j=_jj,_jj+15 do
						if mget(i,j)==20 then
							add(o,{
								template=2,
								rx=i*8,ry=j*8,x=i*8,y=j*8,
								sp=17,spw=20,
								update=pushbox.update,
								draw=pushbox.draw
							})
						end
					end
				end
			end
		end,
		draw = function(self)
			spr(self.sp,self.rx,self.ry)
		end
	}
	local _rstbtn2 = {
		template=1,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,
		sp=49,
		update=_rstbtn1.update,
		interact=_rstbtn1.interact,
		draw=_rstbtn1.draw
	}
	add(o,_rstbtn1)
	add(o,_rstbtn2)
	
end

function destroy(_x,_y,_s)
	_s = _s or 0
	mset(_x,_y,_s)
	p_dust(_x*8,_y*8,6)
end
-->8
--npcs

function init_npcs()
	npcs={}
	
	--old man
	npc_oldman = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=4,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"old man: hEY THERE KIDDO, YOU SEEM LOST... i HOPE YOUR PARENTS ARE AROUND HERE SOMEWHERE...",
				"you: (...)",
				"old man: oH? yOU'RE LOOKING FOR YOUR SOUL? i DON'T THINK i CAN BE MUCH HELP WITH THAT. (KIDS AND THEIR IMAGINATION)"
				})
			elseif self.state==1 then
				start_dialogue({
				"old man: sTILL LOST?",
				"you: (...)",
				"old man: i DON'T HAVE A KID...",
				"you: (???)",
				"old man: dOESN'T MATTER WHAT ANYONE TELLS YA. i'M NOT YOUR GUY.",
				"old man: i WAS JUST HAPPY HERE, UNTIL YOU FOUND YOUR WAY IN AND SNOOPED AROUND MY LIFE."
				})
				self.state=2
				npc_sadboi.state=5
			elseif self.state==2 then
				start_dialogue({
				"THE OLD MAN IS STARING INTO NOTHING, AVOIDING CONVERSATION."
				})
			end
		end,
	}
	add(npcs,npc_oldman)
	
	--cat boy
	npc_catboy = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=5,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state == 0 then
				start_dialogue({
				"cat: i THINK THAT'S A PUZZLE OF SOME SORT, BUT I COULDN'T FIGURE IT OUT...",
				"cat: mAYBE YOU CAN GIVE IT A TRY?"
				})
				self.state = 1
			elseif self.state == 1 then
				start_dialogue({
				"cat: iF THE BOXES ARE STUCK, TRY PRESSING THE RETRY BUTTON!"
				})
			elseif self.state == 2 then
				start_dialogue({
				"cat: wHOA, DID YOU DO THAT PUZZLE BY YOURSELF?",
				"you: (...)",
				"cat: wOW... I WISH I COULD BE LIKE YOU, YOU HAVE A NICE SOUL."
				})
				self.state = 4
			elseif self.state == 3 then
				start_dialogue({
				"cat: wow! yOU'RE REALLY GOOD AT THIS! mAYBE YOU CAN TEACH ME ONE DAY?"
				})
				self.state = 4
			elseif self.state == 4 then
				start_dialogue({
				"you: (...)",
				"cat: wHAT..? yOU ARE LOOKING FOR A SOUL?",
				"cat: hA! yOU'RE REAL FUNNY, WE SHOULD BE FRIENDS!"
				})
				self.state = 5
			elseif self.state == 5 then
				start_dialogue({
				"cat: hEY WE MIGHT BE FRIENDS NOW BUT I'M STILL GOING TO SIT HERE ♥"
				})
				if(npc_dog.state == 0) npc_dog.state = 1
			elseif self.state == 6 then
				start_dialogue({
					"you: (...)",
					"cat: wHA..? wILSON SENT YOU!?",
					"cat: wELL I GUESS I CAN TELL YOU A BIT ABOUT THIS PLACE.",
					"cat: tHOSE WHO ENTER THE DEPTHS DO NOT ENTER WITH THEIR SOUL.",
					"you: (?!?)",
					"cat: tHE ONLY WAY TO GET IT BACK...",
					"cat: iS TO LEAVE..."
				})
				self.state = 7
				if npc_defaultman.state==3 then
					npc_defaultman.state=4
				end
			elseif self.state == 7 then
				start_dialogue({
				"cat: i KNOW THERE'S A WAY TO LEAVE THIS PLACE...",
				"cat: bUT I DON'T KNOW WHAT IT IS..."
				})
			end
		end
	}
	add(npcs,npc_catboy)
	
	--bouncer/gate lady
	npc_gatelady = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=6,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"bouncer: hEY THERE PUMPKIN, NOBODY'S ALLOWED PAST THIS GATE RIGHT NOW"
				})
				self.state=1
			elseif self.state==1 then
				start_dialogue({
				"bouncer: sUGAR I REALLY CAN'T LET YOU IN..."
				})
				self.state=2
			elseif self.state==2 then
				start_dialogue({
				"bouncer: .................... ............................. ............................."
				})
				self.state=3
			elseif self.state==3 then
				start_dialogue({
				"bouncer: aLRIGHT, COME ON THROUGH, BUT DON'T TELL ANYONE I DID THIS..."
				})
				self.rx-=8
				self.ry-=8
				self.state=4
				npc_angryguy.state=2
				npc_caveman.state=2
				npc_boredguy.state=2
			elseif self.state==4 then
				start_dialogue({
				"bouncer: i GUESS IT'S REAL OBVIOUS SINCE I'M STANDING OFF TO THE SIDE NOW"
				})
				self.state=5
			elseif self.state==5 then
				start_dialogue({
				"you: (...)",
				"bouncer: sOULS? i DON'T KNOW MUCH ABOUT THAT STUFF...",
				"bouncer: mAYBE THE MEDALIONS SCATTERED AROUND THE DEPTH HAVE THE ANSWERS YOU'RE LOOKING FOR..?"
				})
			end
		end
	}
	add(npcs,npc_gatelady)
	
	--angry guy
	npc_angryguy = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=7,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"angry guy: i have been at the front of this line for my entire life!!",
				"angry guy: let me the #%$@ in!!!"
				})
				self.state=1
			elseif self.state==1 then
				start_dialogue({
				"angry guy: i live for the downfall of my enemies!!!"
				})
			elseif self.state==2 then
				start_dialogue({
				"angry guy: i hate you!!!!!!!"
				})
			end
		end
	}
	add(npcs,npc_angryguy)
	
	--cave man
	npc_caveman = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=8,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"caveman: ME NO KNOW WHAT LINE MEAN...",
				"caveman: BUT ME LIKE STANDING IN PLACE!"
				})
				self.state=1
			elseif self.state==1 then
				start_dialogue({
				"caveman: ME UNDERSTAND THAT BIG LINE MEAN BIG WAIT"
				})
			elseif self.state==2 then
				self.sp=9
				start_dialogue({
				"caveman: I AM ACTUALLY A HARVARD GRADUATE AND AM VERY ARTICULATE WITH MY SPEECH."
				})
				self.state=3
			elseif self.state==3 then
				start_dialogue({
				"harvard graduate: YUNKY DUNK"
				})
			end
		end
	}
	add(npcs,npc_caveman)
	
	--bored guy
	npc_boredguy = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=10,state=0,
		update=function(self)
			if self.phase then
				if self.rx < 528 then
						self.rx+=0.2
				else
					self.rx = 528
				end
			end
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"bored guy: i'M NOT STANDING IN LINE, I JUST WANTED SOMETHING TO DO."
				})
				self.state=1
			elseif self.state==1 then
				start_dialogue({
				"bored guy: i'M NOT DISAPPOINTED OR ANYTHING, MY EYEBROWS JUST LOOK LIKE THAT."
				})
			elseif self.state==2 then
				start_dialogue({
				"bored guy: i WILL NOW PHASE THROUGH REALITY AS WE KNOW IT BECAUSE I FEEL LIKE IT."
				})
				if(not self.phase) self.phase = true
				self.state=3
				self.flp=true
			elseif self.state==3 then
				start_dialogue({
				"guy who phased through reality: i WILL NOT HESITATE TO DO IT AGAIN."
				})
			end
		end
	}
	add(npcs,npc_boredguy)
	
	--dog
	npc_dog = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=11,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"dog: wHO ARE YOU? hOW DID YOU GET IN HERE?",
				"you: (...)",
				"dog: yOUR SOUL? i DON'T KNOW WHAT THAT IS."
				})
				self.state=2
			elseif self.state==1 then
				start_dialogue({
				"dog: wHO ARE YOU? hOW DID YOU GET IN HERE?",
				"you: (...)",
				"dog: oH? yOU'RE FRIENDS WITH THE CAT..?",
				"dog: wELL THEN WHY DIDN'T YOU SAY SO?? wELCOME TO THE DEPTHS!!"
				})
				self.state=3
			elseif self.state==2 then
				start_dialogue({
				"dog: iT'S CHRISTMAS FOR DOG'S SAKE. sTOP TRYING TO MESS WITH FOLKS LIKE ME."
				})
			elseif self.state==3 then
				start_dialogue({
				"dog: i'M NOT SURE WHAT YOU MEAN BY NEEDING A SOUL...",
				"you: (...)",
				"dog: hM... yOU SEEM LIKE A GOOD KID. tELL THE CAT THAT wILSON SENT YA. hE'LL BE ABLE TO TELL YOU MORE."
				})
				self.state=4
				npc_catboy.state=6
			elseif self.state==4 then
				start_dialogue({
					"wilson: tHE DEPTHS AREN'T WHAT THEY SEEM KID. gET OUT WHILE YOU STILL CAN."
				})
			elseif self.state==5 then
				start_dialogue({
					"wilson: tHE MEDALLIONS? i'VE HEARD VERY LITTLE ABOUT THEM.",
					"you: (...)",
					"wilson: iS THAT SO? i HOPE YOU CHOOSE YOUR WISH WISELY KID."
				})
				self.state=6
			elseif self.state==6 then
				start_dialogue({
					"wilson: fIND ALL 10 MEDALLIONS YET?"
				})
			end
		end
	}
	add(npcs,npc_dog)
	
	--default man
	npc_defaultman = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=12,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"guy: hUH.. WHY DO YOU LOOK JUST LIKE ME?",
				"you: (...)",
				"guy: i DON'T KNOW $#!* ABOUT SOULS, I JUST PUSH THE BOXES."
				})
				self.state=1
			elseif self.state==1 then
				start_dialogue({
				"guy: lIKE I SAID MAN, I DON'T GOT WHAT YOU'RE LOOKING FOR..."
				})
			elseif self.state==2 then
				start_dialogue({
				"guy: i WAS JUST ABOUT TO DO THAT, BUT I DIDN'T FEEL LIKE IT."
				})
			elseif self.state==3 then
				start_dialogue({
				"guy: lET ME KNOW IF YOU FIGURE OUT THAT WHOLE SOUL THING..."
				})
			elseif self.state==4 then
				start_dialogue({
					"you: (...)",
					"guy: i DON'T CARE ABOUT SOULS KID.",
					"you: (...)",
					"guy: i... i DON'T THINK I EVER HAD ONE.",
					"you: (...)",
					"guy: wE ALL HAD SOULS? hOW AM I EVEN SURE OF WHO I AM?"
				})
				self.state = 5
			elseif self.state==5 then
				start_dialogue({
					"guy: gET OUT OF HERE KID, YOU'VE CAUSED ME ENOUGH EXISTENTIAL DREAD TODAY..."
				})
			end
		end
	}
	add(npcs,npc_defaultman)
	
	--sadboi
	npc_sadboi = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=13,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"sad boy: i MISS MY DAD... hE HAD SUCH A NICE SOUL..."
				})
				self.state=1
				npc_oldman.state=1
				npc_pringles.state=1
			elseif self.state==1 then
				start_dialogue({
				"sad boy: i COME HERE EVERY DAY TO PAY MY RESPECTS."
				})
				self.state=2
			elseif self.state==2 then
				start_dialogue({
				"sad boy: i'M NOT SURE WHY THIS IS THE ONLY GRAVE HERE...",
				"sad boy: bUT OUR FAMILY COULD NEVER REALLY AFFORD MUCH..."
				})
				self.state=3
			elseif self.state==3 then
				start_dialogue({
				"you: (...)",
				"sad boy: mY DAD? hE LOOKED KINDA LIKE YOU, BUT WITH A BIG BUSHY MUSTACHE."
				})
				self.state=4
			elseif self.state==4 then
				start_dialogue({
				"sad boy: i'LL SEE YOU AGAIN SOMEDAY DAD..."
				})
			elseif self.state==5 then
				start_dialogue({
					"you: (...)",
					"sad boy: wHAT? mY DAD IS ALIVE?",
					"you: (...)",
					"sad boy: oH... tHAT DOESN'T SOUND LIKE MY DAD TO ME...",
					"sad boy: i APPRECIATE YOU TRYING BUT I THINK I JUST NEED TO LEARN TO MOVE ON.",
				})
				self.state=6
			elseif self.state==6 then
				start_dialogue({
					"you: (...)",
					"sad boy: tHANKS AGAIN FOR TRYING, BUT WE BOTH NEED TO LEARN TO MOVE ON."
				})
			elseif self.state==7 then
				start_dialogue({
					"happy boy: tHANK YOU SO MUCH FOR FINDING MY DAD!",
					"happy boy: nOW I CRY TEARS OF JOY!",
				})
			end
		end
	}
	add(npcs,npc_sadboi)
	
	--goldkeeper
	npc_goldkeep = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=14,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"goldkeeper: wHOA, SOMEONE FINALLY CAME!",
				"you: (...)",
				"goldkeeper: i'VE BEEN THE KEEPER OF THIS MEDALLION FOR YEARS... wAITING FOR IT'S RIGHTFUL OWNER."
				})
				self.state=1
			elseif self.state==1 then
				start_dialogue({
				"goldkeeper: i'VE HEARD THAT HE WHO FINDS ALL 10 MEDALLIONS IS GRANTED A WISH...",
				"goldkeeper: iF I WERE YOU... I'D WISH MY WAY OUT OF THIS PLACE! hahaha!"
				})
				npc_dog.state=5
			end
		end
	}
	add(npcs,npc_goldkeep)
	
	--skeleman
	npc_skeleman = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=15,state=0,
		update=function(self)
			
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"skeleton: yOU'RE LOOKING TO SOLVE THE PUZZLE?",
				"you: (...)",
				"skeleton: tHE SOLUTION EXISTS OUTSIDE THE vip lOUNGE."
				})
			elseif self.state==1 then
				start_dialogue({
				"skeleton: hEY YOU FOUND THE SOLUTION! hOPEFULLY WHATEVER YOU GOT OUT OF IT WAS WORTH IT",
				})
			end
		end
	}
	add(npcs,npc_skeleman)
	
	--pringles
	npc_pringles = {
		template=0,caninteract=true,
		x=-32,y=-32,rx=-32,ry=-32,flp=false,
		sp=31,state=0,
		update=function(self)
			if coins >= 9 then
				del(npcs,self)
			end
			if self.state == 2 and ply.x<96*8 then
				self.rx=72*8
				self.ry=26*8
				self.x=72*8
				self.y=26*8
			end
		end,
		interact=function(self)
			if self.state==0 then
				start_dialogue({
				"wise man: tHE FINAL MEDALLION WILL BE REVEALED HERE WHEN THE TIME IS RIGHT...",
				"you: (...)",
				"wise man: cOME BACK WHEN YOU HAVE THE OTHER 9 MEDALLIONS."
				})
			elseif self.state==1 then
				start_dialogue({
				"you: (...)",
				"wise man: mY SON? hE'S IN THE DEPTHS???",
				"you: (!!!)",
				"wise man: oH MY. tHANK YOU MY CHILD, i MUST GO NOW.",
				"wise man: dO NOT FORGET TO RETURN HERE WHEN YOU HAVE COLLECTED 9 MEDALLIONS."
				})
				npc_sadboi.state=7
				npc_oldman.state=2
				npc_pringles.state=2
			elseif self.state == 2 and ply.x<96*8 then
				start_dialogue({
				"wise man: tHANK YOU FOR RE-UNITING ME WITH MY SON. gLAD I'M NO LONGER ALONE IN THE DEPTHS.",
				"happy boy: sO... wHO'S GRAVESTONE IS THIS THEN?",
				"wise man: yOU HAVE MUCH TO LEARN MY SON...",
				"wise man: (wE MIGHT HAVE TO START WITH READING AND WRITING...)"
				})
				self.state=3
			elseif self.state == 3 then
				start_dialogue({
				"wise man: dON'T FORGET TO GO BACK TO THE NORTHEAST HALLWAY WHEN YOU HAVE 9 MEDALLIONS.",
				"wise man: aND DO YOURSELF A FAVOUR BY WISHING YOUR WAY OUT OF HERE."
				})
			end
		end
	}
	add(npcs,npc_pringles)
	
end
-->8
--dialogue system
function init_dialogue()
	istalking=false
	dialogue={}
	currentdialogue=1
	currenttext=""
end

function start_dialogue(_dia)
	istalking = true
	dialogue = _dia
	currentdialogue = 1
	currenttext = ""
end

function advance_dialogue()
	if istalking then
		if #currenttext <
		#dialogue[currentdialogue] then
			currenttext = dialogue[currentdialogue]
		else
			currenttext = ""
			currentdialogue += 1
			--end dialogue
			if currentdialogue > #dialogue then
				dialogue={}
				istalking=false
			end
		end
		sfx(13)
	end
end

function update_dialogue()
	if istalking then
		if #currenttext <
		#dialogue[currentdialogue] then
			currenttext = currenttext ..
			sub(dialogue[currentdialogue],
			#currenttext+1,#currenttext+1)
			sfx(12)
		end
		if get_input() ~= -1
		or btnp(🅾️) or btnp(❎) then
			advance_dialogue()
		end
	end
end

function draw_dialogue()
	if istalking then
		local _yy=1
		if ply.ry < camy+64 then
			_yy=128-27-1
		end
		
		local _strs = split(currenttext.." "," ")
		local _lines = {""}
		local _curline = 1
		for i=1,#_strs do
			if #(_lines[_curline].._strs[i].." ")*4
			> 122 then
				_curline+=1
			end
			if(_curline>#_lines) add(_lines,"")
			_lines[_curline] = _lines[_curline]..
			_strs[i].." "
		end
		
		rectfill(camx+1,camy+_yy,
		camx+126,camy+_yy+26,1)
		rect(camx+1,camy+_yy,
		camx+126,camy+_yy+26,13)
		
		local _bigstr = ""
		for i=1,#_lines do
			_bigstr = _bigstr .. _lines[i] .. "\n"
		end
		
		print(_bigstr,camx+3,camy+_yy+2,7)
		
	end
end
-->8
--particles

function init_particles()
	parts={}
	
end

function p_burst(_x,_y,_am,_spd,
_fric,_time,_col)
	for i=1,_am do
		add(parts,{
			x=_x,y=_y,
			hs=rnd(_spd*2)-_spd,
			vs=rnd(_spd*2)-_spd,
			col=_col,
			fric=_fric,life=4,
			update=function(self)
				self.x+=self.hs
				self.y+=self.vs
				self.hs-=sgn(self.hs)*self.fric
				self.vs-=sgn(self.vs)*self.fric
				if abs(self.hs)<self.fric
				and abs(self.vs)<self.fric then
					del(parts,self)
				end
			end,
			draw=function(self)
				circfill(self.x,self.y,1,self.col)
			end
		})
	end
end

function p_dust(_x,_y,_am)
	for i=1,_am do
		add(parts,{
			x=_x,y=_y,
			hs=rnd()-0.5,
			vs=rnd()-0.5,
			col=6,
			fric=0.01,life=flr(rnd(10))+25,
			update=function(self)
				self.x+=self.hs
				self.y+=self.vs
				self.hs-=sgn(self.hs)*self.fric
				self.vs-=sgn(self.vs)*self.fric
				if abs(self.hs)<self.fric
				and abs(self.vs)<self.fric then
					del(parts,self)
				end
			end,
			draw=function(self)
				circfill(self.x,self.y,1,self.col)
			end
		})
	end
end

function p_text(_x,_y,_str,_vel,_grav,_col)
	add(parts,{
		x=_x,y=_y,str=_str,tim=120,
		spd=_vel,grav=_grav,col=_col,
		update=function(self)
			if self.tim > 0 then
				self.tim-=1
				if self.tim == 0 then
					del(parts,self)
				end
			end
			self.y -= self.spd
			self.spd -= self.grav
		end,
		draw=function(self)
			print(self.str,
			self.x-#self.str*2,
			self.y-2,self.col)
		end
	})
end
__gfx__
000000000777777007777770077777700677776009900770094444400440440000ffff000fffff00000000000766667007777770000000000000000000777700
00000000077171700771717007717170076767700e9977e0994d7d70074447700ffffff0017f17f0444744447616166707717170007777000044440007717170
007007000771717007717170077171700717177007191770047171700174717001fff1f00fffff10017771700616166007717170077777700714174007717170
0007700007777770077777700777777004444470077977900477777007777770099999f011111171077777700777766007777770017771700444444007777770
0007700007777770077777700777777004222470071117900447777007111770091119f0171717100711777007117660077777700c111c700411114000077700
007007000066660000676600006676000066660000466400006666000066660000999d0001111100006666004477750000666600006666000044440000666600
00000000007777000077770000777700007777000099770000777700007777000024420000244200007777004066660000777700007777000022220000066000
00000000077007700000770000770000077007700090090000700700077007700ff22ff00ff22ff0077007704060060007700770007007000442244000600600
77777777666666666666666660006000660660662202202211111111555555550007700000000000000000000000000006666660000000000000000000777700
77777777677777766677776600060006677777762000000211111111566666650077770000666600000000000000000006616160000000000000000007777770
77777777677777766767767600600060077777700000000011111111566666650077770006666660000990000090090006616160000000000000000001777170
77777777677777766776677606000600677777762000000211111111566666657777777706555660009999000009900006666660000000000000000047444740
77777777677777766776677660006000677777762000000211111111566666657777777706666660009999000009900006666660000000000000000004444470
77777777677777766767767600060006077777700000000011111111566666650077770006565560000990000090090000555500000000000000000000777700
77777777677777766677776600600060677777762000000211111111566666650077770006666660000000000000000000066000000000000000000000dddd00
777777776666666666666666060006006606606622022022111111115555555500777700066666600000000000000000006000000000000000000000077dd770
77777771177777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777771117777770000000000000000000000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777711111777770009900000900900000000000060000000000000000000000066606000000000006006000000000000000000000000000000000000000000
77777171117777770099990000099000000000000000006000000066000666600000000006600000000660000000000000000000000000000000000000000000
77771771177777770099990000099000000000060000060006000600000000000000000000000660000660000000000000000000000000000000000000000000
77717777777717770009900000900900066000600000000000600000066000000000660000006000006006000000000000000000000000000000000000000000
77717777777717770000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77717777777717770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77717777777717777771777777771777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77771777777177777777177777717777000000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777177771777777777717777177777000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777711117777777777771111777777000000000000006000000066000000000000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777000000060000060006000600000000000000000000000000000000000000000000000000000000000000000000000000
77222222222222777722222222222277066000600000000000600000000000000000000000000000000000000000000000000000000000000000000000000000
77788888888887777778888888888777000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddddddddddddddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1111111111111111111111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1111111111111111111111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1111111111111111111111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1111111111111111111111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1111111111111111111111d00000000077777000077777000777077700777000777007770077777000777777000077777000777007700000000000000000000
d1111111111111111111111d00000000777777700777777700777077700777000777007770777777700777777700077777000777007700000000000000000000
d1111111111111111111111d00000000777077700777077700777077700777000777077700777077700777077700077777000777007700000000000000000000
d1111111111111111111111d00000000777077700777077700777077700777000777077700777077700777077700077077000777707700000000000000000000
d1111111111111111111111d00000000777000000777077700777077700777000777777000777077700777077700777077700777707700000000000000000000
d1111111111111111111111d00000000777770000777077700777077700777000777777000777077700777770000777077700777707700000000000000000000
d1111111111111111111111d00000000077777000777077700777077700777000777777000777077700777777700777077700777777700000000000000000000
d1111111111111111111111d00000000000777700777077700777077700777000777777000777077700777077700770007700770777700000000000000000000
d1111111111111111111111d00000000000077700777077700777077700777000777777000777077700777077700770007700770777700000000000000000000
d1111111111111111111111d00000000777077700777077700777077700777000777077700777077700777077700777777700770777700000000000000000000
d1111111111111111111111d00000000777077700777077700777077700777000777077700777077700777077707777777770770077700000000000000000000
d1111111111111111111111d00000000777777700777777700777777700777770777007770777777700777777707770007770770077700000000000000000000
d1111111111111111111111d00000000077777000077777000077777000777770777007770077777000777777007770007770770077700000000000000000000
d1111111111111111111111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1111111111111111111111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1111111111111111111111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1111111111111111111111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1111111111111111111111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddddddddddddddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010100010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000010101010101010101021201010000610101010101010101010101010101010101
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000010101010101010101031301010000000101010101010101010101010101010101
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
010100000000000000000000000000000100000000000000000000000000000101610000000000000000000000000000000000000000000000000000a200a201
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000010100000000000000000000000000000000000000000000000000000000a20001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
010100000000000000000000000000000100000000000000000000000000000101000000010101013101010101010101010000000000000000000000a200a201
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000010100000001010000000001010101010101000000000000000000000000000001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000002100000001014101010001010101010101000000000000000000000000000001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000002100000001010001010000000001010101000000000000000000000000000001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000010100000001010001010101004101010101000000000000000000000000000001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000010100000001010001010101000001010101000000000000000000000000000001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000010100000001010001010101000001010101000000000000000000000000000001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000010100000001010001010101000051010101000000000000000000000000000001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000000010100c00001000000410000000000510101000000000000000000000000000001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010000000000000000000000000022010100610001610000510101016100010101010101010101010101010101010101
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
__label__
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000077777000077777000777077700777000777007770077777000777777000077777000777007700000000000000000077777777
77777777000000000000000000777777700777777700777077700777000777007770777777700777777700077777000777007700000000000000000077777777
77777777000000000000000000777077700777077700777077700777000777077700777077700777077700077777000777007700000000000000000077777777
77777777000000000000000000777077700777077700777077700777000777077700777077700777077700077077000777707700000000000000000077777777
77777777000000000000000000777000000777077700777077700777000777777000777077700777077700777077700777707700000000000000000077777777
77777777000000000000000000777770000777077700777077700777000777777000777077700777770000777077700777707700000000000000000077777777
77777777000000000000000000077777000777077700777077700777000777777000777077700777777700777077700777777700000000000000000077777777
77777777000000000000000000000777700777077700777077700777000777777000777077700777077700770007700770777700000000000000000077777777
77777777000000000000000000000077700777077700777077700777000777777000777077700777077700770007700770777700000000000000000077777777
77777777000000000000000000777077700777077700777077700777000777077700777077700777077700777777700770777700000000000000000077777777
77777777000000000000000000777077700777077700777077700777000777077700777077700777077707777777770770077700000000000000000077777777
77777777000000000000000000777777700777777700777777700777770777007770777777700777777707770007770770077700000000000000000077777777
77777777000000000000000000077777000077777000077777000777770777007770077777000777777007770007770770077700000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000666666000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000661616000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000661616000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000666666000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000666666000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000055550000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000006600000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000077000000000000000000000000000000000777000000000000000000000000077700000000000000000000000000000077777777
77777777000000000000000700070007770077070700000077077000000070007700770000077700770000070707000077070700000000000000000077777777
77777777000000000000000700070000700700077000000707070700000070070707070000007007070000077707000707077700000000000000000077777777
77777777000000000000000700070000700700070700000707077000000070077707770000007007070000070007000777000700000000000000000077777777
77777777000000000000000077007707770077070700000770070700000070070707000000007007700000070000770707077000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777

__gff__
0000000000000000000000000000000003000302000c04000303000000000000030300000808080808080800000000000303030304040404000000000000000008080800000000000000000000000000080808000000000000000000000000000808080000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010102021101010101010101010101010101010101010000000101010101010101010101010101010101010
1010000000000000000000000000001010001600100010161016101010101010101010101010101010001500000000101022000000000000000028000000001010000000000000000000000000000010101010101010103031101010101010101010101010101010101000001f00001000000000000000000000000000001010
1010001010101010101010101010001010000400101610001000101010101010101020211010101010100000001400101000000000000000000000000000001010000000000000000000000000000010100000000000000000000000370037101010101010101010101000000000001000000000000000000000000000001010
101000101010101010101010101000101000000010140000100010101010101010103031101010101010100015101010100000270000000000000000002900000000000025000000000000000b000010100000000000000000000000003700101010101010101010101000404142001000000000000000000000000000001010
1010001000000000000000000010001010000000100010141000101010101010100000000013000000000000101010101000000000000000260000000000001010000000000000000000000000000010100000000000000000000000000037101010101010101010101000505152001000000000000000000000000000001010
1010001000240000000000000010001010250000100010000014001020211010100000000013001400001000101010101018181818181818181818061818181010000000000000000000000000000010100000000000000000000000000000101010101010101010101000606162001000001a00000000000000000000001010
1010001000000000010000000010001010000000100010001000101030311010100000000010101010140000101010101000000000000000000000000000001010000000000000000000000000000010100000000000000000000000000000101010101010101010101000000000001000000000000000000000000000001010
1010001000000000000000250010001010000000000010001000000000001610100000000010101010000015101010101000000000250000000000000007001010000000000000000000002800000010100000140000140000140000140000101010101010101010101000000000001000000000000000000000000000001010
1010001000000000000000000010000000000000000010001000000000000000000000000010101010101010101010101000290000000000000000000000001010000000000000000000000000000010100000000000000000000000000000101010101010101010100000000000001000000000000000000000000000001010
1010121010101010141010101010101010101010101010121010101010101010101010101010101010101010101010101000000000000000002500000008001010000000270000000000000000000010100000000000000000000000000000101000000000000000000000000000001000000000000000000000000000001010
1010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000260000001010000000000000000000000000000010100000000000000000000000000000120000000000000000000000000000001000000000000000000000000000001010
101000101010101000101010101000101000000000000000000000000024001010101210101010101010101010101010100000000000240000000000000a00101000000000000000000000000000001010000f000000000000000000000000120000000000000000000000000000001000000000000000000000000000001010
1010001010000010101000001010001010000000000000000000000000000010101000101010101010101010101010101000000000000000000000000000001010000000000000000000290000000010100000000000000000000000000000101000000000000000000000000000101000000000000000000000000000001010
1010001010000000000000001010001010000000002500101000000000000010101000101010101010101010101010101010101010101010101010101010101010000000000000000000000000000010101010101010101010101010000010101010101010101010101010101010101000000000000000000000000000001010
1010001010000000220000001010001010000000000000101000000000000010101000101010101010101010101010101010101010101010101010101010101010101010101000000000101010101010101010101010101010101010000010101010101010101010101010101010101000000000000000000000000000001010
1010001010000010101000001010001010000000000000101000000000000010101000101010101010101010101010101010101010101010101010101010101010101010101000000000101010101010101010101010101010101010000010100000000000000000000000000000000000000000000000000000000000001010
1010001010121210101012121010001010000000000000202100000000000010101000101000000000000000000000101016000000000000000000000000161010000000000000000000000000000010101010101010101010101010000010100000000000000000000000000000000000000000000000000000000000001010
10100010100000000000000010100010100000000000003031000000000000101010001010000000101010101000001010000000000000000000000000000010100000000000000000000000000000101000000000102200000e1000000000100000000000000000000000000000000000000000000000000000000000001010
1010002021131313131313131010001010000000000000000000260000000010100000001000000000000000101000101000000000000000000000000000001010000000000000000000000000000010100000000010000000001000000000100000000000000000000000000000000000000000000000000000000000001010
1010003031000000000000001010001010000000000000000000000000000010100000001010101000100000001000101000000000000000000000000000001010000000000000000000000000000010100000000010101212101000000000100000000000000000000000000000000000000000000000000000000000001010
1010000000000000000000000000001010000025000000000000000500000010101010000000001000101610001000101000000000000000000000000000001010002500000000000000000000000010100000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001010
1010000000001414141414000000001010000000000000000000000000000010101610101010001000101010001000101000000000000000000000000000001010000000000000000000000026000010100000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001010
1010000000000000000000000000001010000000000000000000000000240010100000002210001000100000001000101000000000000000000000000000001010000000000000000000000000000010100000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001010
1010000000000000000000003400001010101010101010131010101010101010100010101010001000101610001000000000000000000000000000000000161010000024000000000000000000000000000000000010101010101010131310100000000000000000000000000000000000000000000000000000000000001010
1010003400000000000000000000001010101010101010000000100000101010100010000000001000101010001010101000000000000000000000000000001010000000000000000000000000000000000000000010101020211010001510100000000000000000000000000000000000000000000000000000000000001010
101000000000000000350000000000101010101010101000101500000010101010001000101010100000161000000010100000000000000000000000000000101000000000000000000019000d000010101010101010101030311010141510100000000000000000000000000000000000000000000000000000000000001010
1010000000000000000000000000001010101000000010001400100000101010100010000000000000101010101000101000000000000000000000000000001010000000000025000000280000000010101010101010100000000010000010100000000000000000000000000000000000000000000000000000000000001010
1010000000360000000000000000001010101000000000001400101000101010100010100010101000100000000000101000000000000000000000000000001010000000000000000000000029000010101000000014000000140000000010100000000000000000000000000000000000000000000000000000000000001010
1010000000000000000000360000001010101000000015101010001415101010100010100010000000100010100010101000000000000000000000000000001010000000000000000000000000000010101015000000000000000010000010100000000000000000000000000000000000000000000000000000000000001010
1010000000000000000000000000001010101000000000101010000000101010100000000010000000100016100010101016000000000000000000000000161010000000000000000000000000000010101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000001010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010100010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000001010
__sfx__
010100000061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400000c0500c055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400001105011055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400000005000055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900001d63305610056100561005600056000560005600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100001805000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400001803018035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011600000c053000000000000000186000000000000000000c053000000000000000186000000000000186000c053000000000000000186000000000000000000c05300000000000000018600186001860018600
011600000504105041050310503105021050210501105011050000000000000000000000000000000000000002041020410203102031020210202102011020110500007000070000900009000090000900000000
011600000704107041070310703107021070210701107011050000000000000000000000000000000000000004041040410403104031040210402104011040110500007000070000900009000090000900000000
011600000c05300800188201a8201c8201d8201f820218200c04300800218201f8201d8201c8201a820188200c05300800188201a8201c8201d8201f820218200c04300800218201f8201d8201c8201a82018820
010100001865024050240500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0105000024053186530c6500c63029055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01090000181501c1501f1550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900001a1501d150211550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900001c1501f150231550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900001d15021150241550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001f15023150261501f14023140261401f12023120261201f11023110261100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000e0500e05015050150501a0501a050243102431024310243102331023310243102431023310233100e0500e05015050150501a0501a05024310243102431024310233102331021310213102131021310
011000000c0500c050130501305018050180501f3101f3101f3101f3102131021310233102331024310243100c0500c0501305013050180501805024310243102431024310233102331021310213102131021310
051000000205002050020500205002040020400204002040020300203002030020300202002020020200202002050020500205002050020400204002040020400203002030020300203002020020200202002020
051000000005000050000500005000040000400004000040000300003000030000300002000020000200002000050000500005000050000400004000040000400003000030000300003000020000200002000020
011000000465500000000000000004655000000c60004655000000000004655000000000000000046550000004655000000000000000046550000000000046550000000000046550000000000000000465500000
011000000465500000000000000004655000000c60004655000000000004655000000000000000046550000004655000000000000000046550000000000046550000000000046550000010653000000000000000
011000000465504615046250461510653046250461504655046250461504655046251065304625046550462504655046150462504615106530461504625046550461504625046550462510653046250465504615
010600001f15023150261501f15023150261501f14023140261401f14023140261401f13023130261301f13023130261301f12023120261201f12023120261201f11023110261101f1102311026110231101f110
010600002b1102f110321102b1102f110321102b1202f120321202b1202f120321202b1302f130321302b1302f130321302b1402f140321402b1402f140321402b1502f150321502b1502f150321502f1502b150
010600001815323650266501f65023650266501f65023650266501f65023640266401f64023640266401f64023640266401f64023630266301f63023630266301f63023630266301f63023620266201f62023620
01060000266201f62023620266201f62023610266101f61023610266101f61023610266101f610136100c6101f60023600266001f60023600266001f600236000000000000000000000000000000000000000000
__music__
01 0e0f4344
00 0e0f4344
00 0e0f4344
00 0e0f4344
00 110f4344
00 110f4344
00 110f4344
02 110f4344
00 191b4344
00 191b4344
00 1a1c4344
00 1a1c4344
01 191b1d44
00 191b1e44
00 1a1c1f44
02 1a1c1f44
00 20424344
00 21424344
00 22424344
00 23424344

