obs           = obslua
source_name   = ""
total_seconds = 0

cur_seconds   = 0
last_text     = ""
stop_text     = ""
activated     = false

text_format = ""
use_a_reset = false
clock_on = false
switch_clock = false
show_seconds = false
class_num = 0
show_class_timer = false
show_class_clock = false
show_24h = false

hotkey_id     = obs.OBS_INVALID_HOTKEY_ID

-- Function to set the time text
function set_time_text()
	local seconds       = math.floor(cur_seconds % 60)
	local total_minutes = math.floor(cur_seconds / 60)
	local minutes       = math.floor(total_minutes % 60)
	local hours         = math.floor(total_minutes / 60)
	local text
	local c_hour

	--選択されたフォーマットに合わせて表示を変更する
	if clock_on or switch_clock then
		if show_24h then
			c_hour = tonumber(os.date("%H"))
		else 
			c_hour = tonumber(os.date("%I"))
		end

		if show_seconds then
			text = string.format("%02d:%02d:%02d", c_hour, tonumber(os.date("%M")), tonumber(os.date("%S")))
		else
			text = string.format("%02d:%02d", c_hour, tonumber(os.date("%M")))
		end
	else
		if text_format == "hh:mm:ss" then
			text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
		elseif text_format == "hh:mm" then
			text = string.format("%02d:%02d", hours, minutes)
		elseif text_format == "mm:ss" then
			text = string.format("%02d:%02d", total_minutes, seconds)
		elseif text_format == "mm" then
			text = string.format("%02d", total_minutes)
		else 
			text = "Select a Display Format"
		end
	end

	if class_num % math.floor(class_num) == 0 then	--現在のコマ数を表示
		if show_class_clock and (clock_on or switch_clock) then
			text = text .. string.format(" *%d*", class_num)
		elseif show_class_timer and not(clock_on or switch_clock) then
			text = text .. string.format(" *%d*", class_num)
		end
	end

	--AutoReset不使用時，時計非表示時にFinalTextを表示する
	if cur_seconds < 1 and use_a_reset == false and clock_on == false and switch_clock == false and (class_num % math.floor(class_num) == 0) then
		text = stop_text
	end

	if text ~= last_text then
		local source = obs.obs_get_source_by_name(source_name)
		if source ~= nil then
			local settings = obs.obs_data_create()
			obs.obs_data_set_string(settings, "text", text)
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end
	end

	last_text = text
end

function timer_callback()
	cur_seconds = cur_seconds - 1
	if cur_seconds < 0 then
		obs.remove_current_callback()
		cur_seconds = 0
		--Auto Reset使用時または時計表示時，休憩時間終了時にタイマーを更新
		if use_a_reset or clock_on or switch_clock or (class_num % math.floor(class_num) ~= 0) then	
			activated = false
			activate(true)
		end
	end

	set_time_text()
end

function activate(activating)
	if activated == activating then
		return
	end

	activated = activating

	if activating then
		obs.timer_remove(timer_callback)
		total_seconds = set_duration()	--残り時間をセット

		cur_seconds = total_seconds
		set_time_text()
		obs.timer_add(timer_callback, 1000)
	else
		obs.timer_remove(timer_callback)
	end
end

-- Called when a source is activated/deactivated
function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function source_activated(cd)
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, false)
end

function reset(pressed)
	if not pressed then
		return
	end

	activate(false)
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local active = obs.obs_source_active(source)
		obs.obs_source_release(source)
		activate(active)
	end
end

function reset_button_clicked(props, p)
	reset(true)
	return false
end


-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	local props = obs.obs_properties_create()

	local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)

	obs.obs_properties_add_text(props, "stop_text", "Final Text", obs.OBS_TEXT_DEFAULT)

	--Display Formatプロパティの表示
	local d_f = obs.obs_properties_add_list(props, "format", "Display Format", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	local d_f_array = {"hh:mm:ss","hh:mm","mm:ss", "mm"}
	for i=1 , 4 do
		obs.obs_property_list_add_string(d_f, d_f_array[i], d_f_array[i])
	end

	--Switch to Clock Displayプロパティの表示
	obs.obs_properties_add_bool(props,"switch_clock","Switch to Clock Display")
	--Show Seconds On Clockプロパティの表示
	obs.obs_properties_add_bool(props,"show_seconds","Show Seconds On Clock")
	--24-hour Notation On Clockプロパティの表示
	obs.obs_properties_add_bool(props,"show_24h","24-hour Notation On Clock")
	--Show Class Numberプロパティの表示
	obs.obs_properties_add_bool(props,"show_class_timer","Show Class Number On Timer")
	--Show Class Number On Clockプロパティの表示
	obs.obs_properties_add_bool(props,"show_class_clock","Show Class Number On Clock")
	--Auto Resetプロパティの表示
	obs.obs_properties_add_bool(props,"a_reset","Timer Auto-Reset")

	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "This Script is a remix of 'countdown.lua' made by Jim. \nSets a text source to act as a countdown timer. \n\nYou can see how to use it at the following URL. \n https://bit.ly/3WnVYCa \n\nMade By Yagetchi"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	activate(false)

	source_name = obs.obs_data_get_string(settings, "source")
	stop_text = obs.obs_data_get_string(settings, "stop_text")

	text_format = obs.obs_data_get_string(settings,"format")
	use_a_reset = obs.obs_data_get_bool(settings,"a_reset")
	switch_clock = obs.obs_data_get_bool(settings,"switch_clock")
	show_seconds = obs.obs_data_get_bool(settings,"show_seconds")
	show_class_timer = obs.obs_data_get_bool(settings,"show_class_timer")
	show_class_clock = obs.obs_data_get_bool(settings,"show_class_clock") 
	show_24h = obs.obs_data_get_bool(settings,"show_24h") 

	reset(true)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_string(settings, "format", "mm:ss")
	obs.obs_data_set_default_string(settings, "stop_text", "It's time !")
	obs.obs_data_set_default_bool(settings, "a_reset", true)
	obs.obs_data_set_default_bool(settings, "switch_clock", false)
	obs.obs_data_set_default_bool(settings, "show_seconds", true)
	obs.obs_data_set_default_bool(settings, "show_class_timer", false)
	obs.obs_data_set_default_bool(settings, "show_class_clock", false)
	obs.obs_data_set_default_bool(settings, "show_24h", true)
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
	obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

-- a function named script_load will be called on startup
function script_load(settings)
	-- Connect hotkey and activation/deactivation signal callbacks
	--
	-- NOTE: These particular script callbacks do not necessarily have to
	-- be disconnected, as callbacks will automatically destroy themselves
	-- if the script is unloaded.  So there's no real need to manually
	-- disconnect callbacks that are intended to last until the script is
	-- unloaded.
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

	hotkey_id = obs.obs_hotkey_register_frontend("reset_timer_thingy", "Reset Timer", reset)
	local hotkey_save_array = obs.obs_data_get_array(settings, "reset_hotkey")
	obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end







--曜日を確認し，時間割に沿った残り時間を送信する
function set_duration()
	local set_time_second = 0
	local week_data = tonumber(os.date("%w"))

	if week_data == 0 or week_data == 6 then
		set_time_second = set_timer_holiday()
	elseif 1 <= week_data and week_data <= 5 then
		set_time_second = set_timer_weekday()
	else
		set_time_second = 0
	end

	return set_time_second
end

--休日時間割の残り時間算出関数
function set_timer_holiday()
	local time_data = tonumber(os.date("%H%M%S"))
	local h_data = tonumber(os.date("%H"))
	local m_data = tonumber(os.date("%M"))
	local s_data = tonumber(os.date("%S"))
	local end_second = 0
	local remain_second = 0

	local now_second = h_data*3600 + m_data*60 + s_data

	if time_data < 080000 then
		end_second = 28800
		class_num = 0.5

	elseif 080000 <= time_data and time_data < 093000 then	--～1コマ
		end_second = 34200	--9時半の秒数
		class_num = 0.5
		
	elseif 093000 <= time_data and time_data < 103000 then	--1コマ
		end_second = 37800
		class_num = 1

	elseif 103000 <= time_data and time_data < 105000 then	--1～2休憩
		end_second = 39000
		class_num = 1.5

	elseif 105000 <= time_data and time_data < 115000 then	--2コマ
		end_second = 42600
		class_num = 2

	elseif 115000 <= time_data and time_data < 121000 then	--2～3休憩
		end_second = 43800
		class_num = 2.5

	elseif 121000 <= time_data and time_data < 131000 then	--3コマ
		end_second = 47400
		class_num = 3

	elseif 131000 <= time_data and time_data < 143000 then	--3～4休憩
		end_second = 52200
		class_num = 3.5

	elseif 143000 <= time_data and time_data < 153000 then	--4コマ
		end_second = 55800
		class_num = 4

	elseif 153000 <= time_data and time_data < 155000 then	--4～5休憩
		end_second = 57000
		class_num = 4.5

	elseif 155000 <= time_data and time_data < 165000 then	--5コマ
		end_second = 60600
		class_num = 5

	elseif 165000 <= time_data and time_data < 171000 then	--5～6休憩
		end_second = 61800
		class_num = 5.5

	elseif 171000 <= time_data and time_data < 181000 then	--6コマ
		end_second = 65400
		class_num = 6

	elseif 181000 <= time_data and time_data < 183000 then	--6～7休憩
		end_second = 66600
		class_num = 6.5

	elseif 183000 <= time_data and time_data < 193000 then	--7コマ
		end_second = 70200
		class_num = 7

	elseif 193000 <= time_data and time_data < 195000 then	--7～振り返り休憩
		end_second = 71400
		class_num = 7.5

	else	--振り返り以降
		end_second = 86400	--24時
		class_num = 7.5
	end

	remain_second = end_second - now_second

	--時計表示の切り替え
	if time_data < 080000 or 195000 <= time_data then
		clock_on = true
	else 
		clock_on = false
	end
	
	return remain_second
end



--平日時間割の残り時間自動算出関数
function set_timer_weekday()
	local time_data = tonumber(os.date("%H%M%S"))
	local h_data = tonumber(os.date("%H"))
	local m_data = tonumber(os.date("%M"))
	local s_data = tonumber(os.date("%S"))
	local end_second = 0
	local remain_second = 0

	local now_second = h_data*3600 + m_data*60 + s_data

	if time_data < 130000 then
		end_second = 46800
		class_num = 0.5

	elseif 130000 <= time_data and time_data < 143000 then	--～1コマ
		end_second = 52200	--14時半の秒数
		class_num = 0.5

	elseif 143000 <= time_data and time_data < 153000 then	--1コマ
		end_second = 55800
		class_num = 1

	elseif 153000 <= time_data and time_data < 155000 then	--1～2休憩
		end_second = 57000
		class_num = 1.5

	elseif 155000 <= time_data and time_data < 165000 then	--2コマ
		end_second = 60600
		class_num = 2

	elseif 165000 <= time_data and time_data < 171000 then	--2～3休憩
		end_second = 61800
		class_num = 2.5

	elseif 171000 <= time_data and time_data < 181000 then	--3コマ
		end_second = 65400
		class_num = 3

	elseif 181000 <= time_data and time_data < 183000 then	--3～4休憩
		end_second = 66600
		class_num = 3.5

	elseif 183000 <= time_data and time_data < 193000 then	--4コマ
		end_second = 70200
		class_num = 4

	elseif 193000 <= time_data and time_data < 195000 then	--4～5休憩
		end_second = 71400
		class_num = 4.5

	elseif 195000 <= time_data and time_data < 205000 then	--5コマ
		end_second = 75000
		class_num = 5

	elseif 205000 <= time_data and time_data < 211000 then	--5～振り返り休憩
		end_second = 76200
		class_num = 5.5

	else	--振り返り以降
		end_second = 86400	--24時
		class_num = 5.5
	end

	remain_second = end_second - now_second

	--時計表示の切り替え
	if time_data < 130000 or 211000 <= time_data then
		clock_on = true
	else 
		clock_on = false
	end
	
	return remain_second
end
	