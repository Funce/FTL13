GLOBAL_LIST_EMPTY(allfaxes)
GLOBAL_LIST_INIT(admin_departments, list("Central Command"))
GLOBAL_LIST_INIT(hidden_admin_departments, list("Syndicate"))
GLOBAL_LIST_EMPTY(alldepartments)

/obj/machinery/photocopier/faxmachine
	name = "fax machine"
	icon = 'icons/obj/library.dmi'
	icon_state = "fax"
	insert_anim = "faxsend"
	var/fax_network = "Local Fax Network"

	var/long_range_enabled = FALSE // Can we send messages off the station?
	req_one_access = list(ACCESS_LAWYER, ACCESS_HEADS, ACCESS_ARMORY)

	use_power = TRUE
	idle_power_usage = 30
	active_power_usage = 200

	var/obj/item/weapon/card/id/scan = null // identification

	var/authenticated = FALSE
	var/sendcooldown = 0 // to avoid spamming fax messages
	var/cooldown_time = 1800

	var/department = "Unknown" // our department

	var/destination = "Not Selected" // the department we're sending to

/obj/machinery/photocopier/faxmachine/Initialize()
	GLOB.allfaxes += src

	if( !(("[department]" in GLOB.alldepartments) || ("[department]" in GLOB.admin_departments)) )
		GLOB.alldepartments |= department

/obj/machinery/photocopier/faxmachine/longrange
	name = "long range fax machine"
	fax_network = "Central Command Quantum Entanglement Network"
	long_range_enabled = TRUE

/obj/machinery/photocopier/faxmachine/attack_hand(mob/user)
	ui_interact(user)

/obj/machinery/photocopier/faxmachine/attack_ghost(mob/user)
	ui_interact(user)	
	
/obj/machinery/photocopier/faxmachine/attackby(obj/item/weapon/item, mob/user, params)
	if(istype(item,/obj/item/weapon/card/id) && !scan)
		scan(item)
	else if(istype(item, /obj/item/weapon/paper)) // Only paper can go in this one
		return ..()
	else
		return

/obj/machinery/photocopier/faxmachine/emag_act(mob/user)
	if(!emagged)
		emagged = TRUE
		to_chat(user, "<span class='notice'>The transmitters realign to an unknown source!</span>")
	else
		to_chat(user, "<span class='warning'>You swipe the card through [src], but nothing happens.</span>")

/obj/machinery/photocopier/faxmachine/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = 0, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state)
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "faxmachine", "Fax Machine UI", 540, 450, master_ui, state)
		ui.open()

/obj/machinery/photocopier/faxmachine/ui_data(mob/user)
	var/list/data = list()
	var/is_authenticated = is_authenticated(user)

	if(scan)
		data["scan_name"] = scan.name
	else
		data["scan_name"] = "-----"
	data["authenticated"] = is_authenticated
	if(!is_authenticated)
		data["network"] = "Disconnected"
		data["network_class"] = "bad"
	else if(!emagged)
		data["network"] = fax_network
		data["network_class"] = "good"
	else
		data["network"] = "ERR*?*%!*"
		data["network_class"] = "average"
	if(copy)
		data["paper"] = copy.name
		data["paperinserted"] = TRUE
	else if (photocopy)
		data["paper"] = photocopy.name
		data["paperinserted"] = TRUE
	else
		data["paper"] = "-----"
		data["paperinserted"] = TRUE
	data["destination"] = destination
	data["cooldown"] = sendcooldown
	if((destination in GLOB.admin_departments) || (destination in GLOB.hidden_admin_departments))
		data["respectcooldown"] = TRUE
	else
		data["respectcooldown"] = FALSE

	return data

/obj/machinery/photocopier/faxmachine/ui_act(action, params)
	if (..())
		return

	var/is_authenticated = is_authenticated(usr)
	switch(action)
		if("send")
			if(copy && is_authenticated)
				if((destination in GLOB.admin_departments) || (destination in GLOB.hidden_admin_departments))
					send_admin_fax(usr, destination)
				else
					sendfax(destination,usr)

				if(sendcooldown)
					spawn(sendcooldown) // cooldown time
						sendcooldown = 0
		if("paper")
			if(copy)
				copy.forceMove(get_turf(src))
				if(ishuman(usr))
					if(!usr.get_active_held_item() && Adjacent(usr))
						usr.put_in_hands(copy)
				to_chat(usr, "<span class='notice'>You eject \the [copy] from \the [src].</span>")
				copy = null
			else if (photocopy)
				photocopy.forceMove(get_turf(src))
				if(ishuman(usr))
					if(!usr.get_active_held_item() && Adjacent(usr))
						usr.put_in_hands(photocopy)
				to_chat(usr, "<span class='notice'>You eject \the [photocopy] from \the [src].</span>")
				photocopy = null
			else
				var/obj/item/I = usr.get_active_held_item()
				if(istype(I, /obj/item/weapon/paper))
					usr.drop_item()
					copy = I
					do_insertion(I, usr)
				else if (istype(I, /obj/item/weapon/photo))
					usr.drop_item()
					photocopy = I
					do_insertion(I, usr)
		if("scan")
			scan()
		if("dept")
			if(is_authenticated)
				var/lastdestination = destination
				var/list/combineddepartments = GLOB.alldepartments.Copy()
				if(long_range_enabled)
					combineddepartments += GLOB.admin_departments.Copy()

				if(emagged)
					combineddepartments += GLOB.hidden_admin_departments.Copy()

				destination = input(usr, "To which department?", "Choose a department", "") as null|anything in combineddepartments
				if(!destination)
					destination = lastdestination
		if("auth")
			if(!is_authenticated && scan)
				if(check_access(scan))
					authenticated = TRUE
			else if(is_authenticated)
				authenticated = FALSE
		if("rename")
			if(copy || photocopy)
				var/n_name = sanitize(copytext(input(usr, "What would you like to label the fax?", "Fax Labelling", copy.name)  as text, 1, MAX_MESSAGE_LEN))
				if(usr.stat == 0)
					if(copy && copy.loc == src)
						copy.name = "[(n_name ? text("[n_name]") : initial(copy.name))]"
						copy.desc = "This is a paper titled '" + copy.name + "'."
					else if(photocopy && photocopy.loc == src)
						photocopy.name = "[(n_name ? text("[n_name]") : "photo")]"

/obj/machinery/photocopier/faxmachine/proc/is_authenticated(mob/user)
	if(authenticated)
		return TRUE
	else if(IsAdminGhost(user))
		return TRUE
	return FALSE
	
/obj/machinery/photocopier/faxmachine/proc/scan(var/obj/item/weapon/card/id/card = null)
	if(scan) // Card is in machine
		scan.forceMove(get_turf(src))
		if(!usr.get_active_held_item() && Adjacent(usr))
			usr.put_in_hands(scan)
		scan = null
	else if(Adjacent(usr))
		if(!card)
			var/obj/item/I = usr.get_active_held_item()
			if(istype(I, /obj/item/weapon/card/id))
				if(!usr.drop_item())
					return
				I.forceMove(src)
				scan = I
		else if(istype(card))
			if(!usr.drop_item())
				return
			card.forceMove(src)
			scan = card
	
/obj/machinery/photocopier/faxmachine/verb/eject_id()
	set category = null
	set name = "Eject ID Card"
	set src in oview(1)

	if(usr.restrained())	
		return

	if(scan)
		to_chat(usr, "You remove \the [scan] from \the [src].")
		scan.forceMove(get_turf(src))
		if(!usr.get_active_held_item() && Adjacent(usr))
			usr.put_in_hands(scan)
		scan = null
	else
		to_chat(usr, "There is nothing to remove from \the [src].")

/obj/machinery/photocopier/faxmachine/proc/sendfax(var/destination,var/mob/sender)
	if(stat & (BROKEN|NOPOWER))
		return

	use_power(200)

	var/success = FALSE
	for(var/thing in GLOB.allfaxes)
		var/obj/machinery/photocopier/faxmachine/F = thing
		if( F.department == destination )
			success = F.receivefax(copy)

	if(success)
		var/datum/fax/F = new /datum/fax()
		F.name = copy.name
		F.from_department = department
		F.to_department = destination
		F.origin = src
		F.message = copy
		F.sent_by = sender
		F.sent_at = world.time

		visible_message("[src] beeps, \"Message transmitted successfully.\"")
	else
		visible_message("[src] beeps, \"Error transmitting message.\"")

/obj/machinery/photocopier/faxmachine/proc/receivefax(var/obj/item/incoming)
	if(stat & (BROKEN|NOPOWER))
		return FALSE

	if(department == "Unknown")
		return FALSE	//You can't send faxes to "Unknown"
	
	flick("faxreceive", src)

	playsound(loc, 'sound/goonstation/machines/printer_dotmatrix.ogg', 50, 1)

	//give the sprite some time to flick
	addtimer(CALLBACK(src, .proc/handle_copying, incoming), 20)

/obj/machinery/photocopier/faxmachine/proc/handle_copying(var/obj/item/incoming)
	if(istype(incoming, /obj/item/weapon/paper))
		copy(incoming)
	else if(istype(incoming, /obj/item/weapon/photo))
		photocopy(incoming)
	else
		return FALSE

	use_power(active_power_usage)
	return TRUE

/obj/machinery/photocopier/faxmachine/proc/send_admin_fax(var/mob/sender, var/destination)
	if(stat & (BROKEN|NOPOWER))
		return
		
	if(sendcooldown)
		return

	use_power(200)

	var/obj/item/rcvdcopy
	if(copy)
		rcvdcopy = copy(copy)
	else if(photocopy)
		rcvdcopy = photocopy(photocopy)
	else
		visible_message("[src] beeps, \"Error transmitting message.\"")
		return

	rcvdcopy.loc = null //hopefully this shouldn't cause trouble

	var/datum/fax/admin/A = new /datum/fax/admin()
	A.name = rcvdcopy.name
	A.from_department = department
	A.to_department = destination
	A.origin = src
	A.message = rcvdcopy
	A.sent_by = sender
	A.sent_at = world.time

	//message badmins that a fax has arrived
	switch(destination)
		if("Central Command")
			message_admins(sender, "CENTCOM FAX", destination, rcvdcopy, "#006100")
		if("Syndicate")
			message_admins(sender, "SYNDICATE FAX", destination, rcvdcopy, "#DC143C")
	sendcooldown = cooldown_time
	spawn(50)
		visible_message("[src] beeps, \"Message transmitted successfully.\"")


/obj/machinery/photocopier/faxmachine/proc/message_admins(var/mob/sender, var/faxname, var/faxtype, var/obj/item/sent, font_colour="#9A04D1")
	var/msg = "<span class='boldnotice'><font color='[font_colour]'>[faxname]: </font> [ADMIN_LOOKUP(sender)] | REPLY: [ADMIN_CENTCOM_REPLY(sender)] [ADMIN_FAX(sender, src, faxtype, sent)] [ADMIN_SM(sender)] | REJECT: (<A HREF='?_src_=holder;FaxReplyTemplate=\ref[sender];originfax=\ref[src]'>TEMPLATE</A>) [ADMIN_SMITE(sender)] (<A HREF='?_src_=holder;EvilFax=\ref[sender];originfax=\ref[src]'>EVILFAX</A>) </span>: Receiving '[sent.name]' via secure connection... <a href='?_src_=holder;AdminFaxView=\ref[sent]'>view message</a>"
	to_chat(GLOB.admins, msg)
