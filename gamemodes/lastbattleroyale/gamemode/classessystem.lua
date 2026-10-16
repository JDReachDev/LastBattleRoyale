
function PlayersReward()
	local num = #player.GetAll()
	if num < 5 then
		return 15
	elseif num >= 5 and num < 10 then
		return 25
	elseif num >= 10 and num < 20 then
		return 40
	elseif num >= 20 and num < 32 then
		return 60
	elseif num >= 32 then
		return 100
	else
		return 20
	end
end

function ScoreReward(ply)
	local k = ply:Frags()
	if k < 4 then
		return 5
	elseif k >= 4 and k < 8 then
		return 10
	elseif k >= 8 and k < 16 then
		return 15
	elseif k >= 16 and k < 32 then
		return 20
	elseif k >= 32 then
		return 25
	end
end
