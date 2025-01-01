/mob/eye/camera/imaginary_friend
	name = "imaginary friend"
	real_name = "imaginary friend"
	desc = "A wonderful yet fake friend."
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	see_invisible = SEE_INVISIBLE_OBSERVER
	stat = DEAD // Keep hearing ghosts and other IFs
	invisibility = INVISIBILITY_MAXIMUM
	sight = SEE_MOBS|SEE_TURFS|SEE_OBJS
	see_in_dark = 8
	move_on_shuttle = TRUE

	var/aghosted_original_mob

	var/icon/friend_image
	var/image/current_image
	var/hidden = FALSE
	var/mob/living/owner

	var/datum/action/innate/imaginary_orbit/orbit
	var/datum/action/innate/imaginary_hide/hide

	var/list/current_huds = list()

/mob/eye/camera/imaginary_friend/Login()
	. = ..()
	setup_friend()
	update_image()

/mob/eye/camera/imaginary_friend/Logout()
	. = ..()
	if(!QDELETED(src))
		deactivate()

/mob/eye/camera/imaginary_friend/Initialize(mapload, mob/_owner)
	. = ..()

	if(!owner || !owner.client)
		return INITIALIZE_HINT_QDEL

	owner = _owner
	// TODO: find out if Iris has screentext in any form
//	owner.play_screen_text("An imaginary friend has appeared to help you! <br> The imaginary friend is an out of character aid for mentors to assist you. If someone asks you about it in character you can explain it as remembering something from the past, etc, but you are not insane.")

	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

	orbit = new
	orbit.Grant(src)
	hide = new
	hide.Grant(src)

/// gives the friend the correct name, gender and sets up their appearance
/mob/eye/camera/imaginary_friend/proc/setup_friend()
	name = client.prefs.read_preference(/datum/preference/name)
	real_name = name
	gender = client.prefs.read_preference(/datum/preference/choiced/gender)

	friend_image = get_flat_human_icon(null, client.prefs, outfit_override = /datum/outfit/job/assistant)

/// makes the friend update their icon and appear to themselves and, if not hidden, the owner
/mob/eye/camera/imaginary_friend/proc/update_image()
	if(!client)
		return

	owner.client?.images.Remove(current_image)

	client.images.Remove(current_image)

	current_image = image(friend_image, src, layer = MOB_LAYER, dir = dir)
	current_image.override = TRUE
	current_image.name = name
	if(hidden)
		current_image.alpha = 150

	if(!hidden && owner.client)
		owner.client.images |= current_image

	client.images |= current_image

/mob/eye/camera/imaginary_friend/Destroy()
	if(owner)
		owner.client?.images.Remove(friend_image)

	client?.images.Remove(friend_image)

	owner = null
	current_image = null
	friend_image = null

	return ..()

/mob/eye/camera/imaginary_friend/verb/toggle_darkness()
	set category = "Imaginary Friend"
	set name = "Toggle Darkness"

	switch(lighting_cutoff)
		if (LIGHTING_CUTOFF_VISIBLE)
			lighting_cutoff = LIGHTING_CUTOFF_MEDIUM
		if (LIGHTING_CUTOFF_MEDIUM)
			lighting_cutoff = LIGHTING_CUTOFF_HIGH
		if (LIGHTING_CUTOFF_HIGH)
			lighting_cutoff = LIGHTING_CUTOFF_FULLBRIGHT
		else
			lighting_cutoff = LIGHTING_CUTOFF_VISIBLE

	update_sight()

/mob/eye/camera/imaginary_friend/verb/toggle_hud()
	set category = "Imaginary Friend"
	set name = "Toggle HUD"

	var/hud_choice = tgui_input_list(usr, "Choose a HUD to toggle", "Toggle HUD prefs", list("Medical HUD", "Security HUD", "Squad HUD", "Xeno Status HUD", "Faction UPP HUD", "Faction Wey-Yu HUD", "Faction RESS HUD", "Faction CLF HUD"))
	var/datum/atom_hud/hud
	switch(hud_choice)
		if("Medical HUD")
			hud = GLOB.huds[DATA_HUD_MEDICAL_BASIC]
		if("Security HUD")
			hud = GLOB.huds[DATA_HUD_SECURITY_BASIC]

	if(hud_choice in current_huds)
		hud.show_to(src)
		current_huds -= hud_choice
	else
		hud.hide_from(src)
		current_huds += hud_choice

/mob/eye/camera/imaginary_friend/say(message, bubble_type, list/spans = list(), sanitize = TRUE, datum/language/language, ignore_spam = FALSE, forced)
	if(!message)
		return

	if(client)
		if(client.prefs.muted & MUTE_IC)
			to_chat(src, span_danger("You cannot send IC messages (muted)."))
			return

		if(client.handle_spam_prevention(message, MUTE_IC))
			return

	message = capitalize(trim(copytext_char(sanitize(message), 1, MAX_MESSAGE_LEN)))

	if(!message)
		return

	var/rendered = "<span class='game say'><span class='name'>[name]</span> <span class='message'>[say_quote(message)] \"[message]\"</span></span>"
	// TODO: idk do something with dchat
//	var/dead_rendered = "<span class='game say'><span class='name'>[name] (imaginary friend of [owner])</span> <span class='message'>[say_quote(message)] \"[message]\"</span></span>"

	to_chat(owner, "[rendered]")
	to_chat(src, "[rendered]")
	create_chat_message(owner, language, message, spans)

/*
/// shows langchat and speech text to the owner and friend, and sends speech text to dchat
/mob/eye/camera/imaginary_friend/proc/friend_talk(message)
	message = capitalize(trim(copytext_char(sanitize(message), 1, MAX_MESSAGE_LEN)))

	if(!message)
		return

	var/rendered = "<span class='game say'><span class='name'>[name]</span> <span class='message'>[say_quote(message)] \"[message]\"</span></span>"
	var/dead_rendered = "<span class='game say'><span class='name'>[name] (imaginary friend of [owner])</span> <span class='message'>[say_quote(message)] \"[message]\"</span></span>"

	to_chat(owner, "[rendered]")
	to_chat(src, "[rendered]")
	log_say("Imaginary Friend: [dead_rendered]")
	if(!hidden)
		var/list/send_to = list()
		if(!owner.client?.prefs.lang_chat_disabled)
			send_to += owner
		if(!client?.prefs.lang_chat_disabled)
			send_to += src
		if(length(send_to))
			langchat_speech(message, send_to, GLOB.all_languages, skip_language_check = TRUE)

	//speech bubble
	var/mutable_appearance/MA = mutable_appearance('icons/mob/effects/talk.dmi', src, "default[say_test(message)]", FLY_LAYER)
	MA.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(flick_overlay_to_clients), MA, owner.client ? list(client, owner.client) : list(client), 3 SECONDS)

	for(var/mob/ghost as anything in GLOB.dead_mob_list)
		if(isnewplayer(ghost) || src == ghost)
			continue
		var/link = "<a href='byond://?src=\ref[ghost];track=\ref[src]'>F</a>"
		to_chat(ghost, "[dead_rendered] ([link])")

/mob/eye/camera/imaginary_friend/Move(newloc, Dir = 0)
	if(world.time < move_delay)
		return FALSE

	if(get_dist(src, owner) > 9)
		recall()
		move_delay = world.time + 10
		return FALSE

	forceMove(newloc)
	move_delay = world.time + 1
*/
/mob/eye/camera/imaginary_friend/forceMove(atom/destination)
	dir = get_dir(get_turf(src), destination)
	loc = destination
	update_image()
	orbiting?.end_orbit(src)

/mob/eye/camera/imaginary_friend/stop_orbit(datum/component/orbiter/orbits)
	. = ..()
	// pixel_y = -2
	animate(src, pixel_y = 0, time = 10, loop = -1)

/// returns the friend to the owner
/mob/eye/camera/imaginary_friend/proc/recall()
	if(QDELETED(owner))
		deactivate()
		return FALSE
	if(orbit_target == owner)
		orbiting?.end_orbit(src)
		return FALSE
	if(!hidden)
		hide.Trigger()
	dir = SOUTH
	update_image()
	orbit(owner)

/// logs the imaginary friend's removal, ghosts them and cleans up the friend
/mob/eye/camera/imaginary_friend/proc/deactivate()
	log_admin("[key_name(src)] stopped being imaginary friend of [key_name(owner)].")
	message_admins("[key_name_admin(src)] stopped being imaginary friend of [key_name_admin(owner)].")
	ghostize(TRUE, TRUE)
	qdel(src)

/mob/eye/camera/imaginary_friend/ghostize(can_reenter_corpse = FALSE, aghosted = FALSE)
	if(QDELING(src))
		return

	icon = friend_image
	mouse_opacity = MOUSE_OPACITY_ICON
	var/mob/ghost = ..()
	if(ghost?.mind)
		ghost.mind.original_character = aghosted_original_mob
	return ghost

/datum/action/innate/imaginary_orbit
	name = "Orbit"
	button_icon_state = "joinmob"

/datum/action/innate/imaginary_orbit/Trigger(trigger_flags)
	. = ..()
	var/mob/eye/camera/imaginary_friend/friend = owner
	friend.recall()

/datum/action/innate/imaginary_hide
	name = "Hide"
	button_icon_state = "hidemob"

/datum/action/innate/imaginary_hide/Trigger(trigger_flags)
	. = ..()
	var/mob/eye/camera/imaginary_friend/friend = owner
	if(friend.hidden)
		friend.hidden = FALSE
		friend.update_image()
		name = "Hide"
		button_icon_state = "hidemob"
	else
		friend.hidden = TRUE
		friend.update_image()
		name = "Show"
		button_icon_state = "unhidemob"

	build_button_icon()
