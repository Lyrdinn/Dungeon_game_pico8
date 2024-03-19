--gen

/*
    THIS CODE WAS INSPIRED BY BOTH :
    - https://www.youtube.com/@LazyDevs
    - http://rogueliketutorials.com

    Credit belongs to them for the inspiration, I analysed both of their code
    to then write my own for what I wanted for my game in terms of dungeons.

    I wanted to have dungeons similar to Rogue and Pokemon Mystery Dungeons
*/

function move_floor()
	floor+=1

    --If we reached the fifth floor we change our dungeon type
	if floor==5 then
		dj_typ+=1
	end
	
    --Fadeout effect whenever we're moving to another floor
	fadeout()

    --We generate a new dungeon floor
	generate_dj(dj_typ)
end


function generate_dj(dj_typ)
	cur_dj=dj_sp[dj_typ]
	
    --I'm setting my dungeon to be in a 20x20 grid, it's more than enough for 5-6 rooms for a pico8 game
    --first I'm setting all the tiles to be wall tiles
	for x=0,20 do
		for y=1,20 do
			--40% chance of having a nice tile between 3 nice tiles type
			if rnd(100) < 40 then
				local rdn_t=flr(rnd(3))
				mset(x,y,cur_dj+rdn_t)
			else
				mset(x,y,cur_dj)
			end
		end
	end
	
	mobs={}
	add(mobs,p)
	
    --Then I actually generate the rooms
	genrooms()

    --I reset the fog of war to be clean again
	fog,distmap=blankmap(1),blankmap(-1)
	unfog()
end

function genrooms()
    --I'm setting the number of rooms to be between 5 and 6
	local fmax,rmax=5,6
	rooms={}
	
	repeat
		local r=rdnroom(6,6)
		
		if placeroom(r) then
		
			-- We create our first room and we place the player in it
			if #rooms==0 then
				p.x,p.y=r.x+2,r.y+2
				
			--We dig tunnels between room
			else
				local prevx,prevy=r.x+2,r.y+2
				local r2=rooms[#rooms]
				local newx,newy=r2.x+2,r2.y+2
				if rnd(1) <= 0.5 then
					create_hor_tun(prevx,newx,prevy)
					create_ver_tun(prevy,newy,newx)
				else
					create_ver_tun(prevy,newy,newx)
					create_hor_tun(prevx,newx,prevy)
				end
				
				--We add elements to the room
				add_elements(r)
			end
			
			rmax-=1
			add(rooms,r)
		else
			fmax-=1
		end
	until fmax<=0 or rmax<=0
	
	--We place the stairs
	local tle=rnd_tile(rooms[#rooms],true)
	mset(tle.x,tle.y,3)
	
	spawn_mobs()
end

--We generate a room of a random size between 4 and 6
function rdnroom(mw,mh)
	local _w=4+flr(rnd(mw-2))
	mh=mid(35/_w,3,mh)
	local _h=4+flr(rnd(mh-2))
	return
	{
		x=0,
		y=0,
		w=_w,
		h=_h
	}
end

--We try to place the room in our grid and see if it doesn't collide with the other ones
function placeroom(r)
	local cand,c={}
	for _x=1,20-r.w do
		for _y=1,20-r.h do
			if doesroomfit(r,_x,_y) then
				add(cand,{x=_x,y=_y})
			end
		end
	end
	
	if #cand==0 then 
		return false 
	end
	
	c=rnd(cand)
	r.x,r.y=c.x,c.y
	
	for _x=0,r.w-1 do
		for _y=0,r.h-1 do
			set_empty_t(_x+r.x,_y+r.y)
		end
	end
	
	return true
end

--We verify if the room can fit in our space by checking all the coordinates of it
function doesroomfit(r,x,y)	
	for _x=-1,r.w do
		for _y=-1,r.h do
			--as soon as walkable tile
			--we know we cant place
			if is_walkable(_x+x,_y+y) then
				return false
			end
		end
	end
	return true
end

--Adds a random special tile or pot to the space
function add_elements(r)
	--20% chance of special tile
	if rnd(100) < 70 then
		local tle=rnd_tile(r,true)
		local r_tle=rnd({18,19,20})
		mset(tle.x,tle.y,r_tle)
	end

	--add breaking pot
	for i=1,3 do
		if rnd(100) < 100 then
			local tle=rnd_tile(r,false)
			mset(tle.x,tle.y,1)
		end
	end
end

--Spawn a number of mobs in the current dungeon
function spawn_mobs()
	local nb_mobs=3+flr(rnd(1))
	local placed,rpot=0,{}
	
	for r in all(rooms) do
		add(rpot,r)
	end
	
	repeat
		local r=rnd(rpot)
		placed+=infest_room(r)
		del(rpot,r)
	
	until #rpot==0 or placed>=nb_mobs
end

--Infest a room of enemies between 1 and 2
function infest_room(r)
	local target=1+flr(rnd(1))
	
	for i=1,target do
		local tle=rnd_tile(r)
		local mb_rdn=2+flr(rnd(3))
		add_mob(mb_rdn,tle.x,tle.y)
	end

	return target
end

--Returns a random tile inside of our room, inner defines if we want the tile to be 
--1 tile out of our walls (use it so that certain traps don't block tunnels and we get softlocked)
function rnd_tile(r,inner)
	local _x,_y=0,0
	repeat
		--if we want the tile to be
		--inside room borders
		if inner then
			_x=r.x+1+flr(rnd(r.w-2))
			_y=r.y+1+flr(rnd(r.h-2))
		else
			_x=r.x+flr(rnd(r.w))
			_y=r.y+flr(rnd(r.h))
		end
	until is_walkable(_x,_y,"checkmobs")
	and not check_flag(5,_x,_y)
	return {x=_x,y=_y}
end

function create_hor_tun(x1,x2,_y)
	for _x=min(x1,x2),max(x1,x2)+1 do
			set_empty_t(_x,_y)
	end
end

function create_ver_tun(y1,y2,_x)
	for _y=min(y1,y2),max(y1,y2)+1 do
			set_empty_t(_x,_y)
	end
end

--Sets our empty floor tile
function set_empty_t(_x,_y)
	--25% chance of having nice looking tile
	if rnd(100) < 25 then
		local rdn_t=flr(rnd(2))
		mset(_x,_y,cur_dj+4+rdn_t)
	else
		mset(_x,_y,32)
	end
end