#define WHOLE_MESSAGE 1
#define WITH_FOUND_REMOVED 2

/datum/component/ai/hearing
	var/hear_signal
	var/list/required_messages = list()
	var/list/hear_args
	var/pass_speech = FALSE
	var/response_delay = 10

/datum/component/ai/hearing/initialize()
	parent.register_event(/event/hear, src, src::on_hear())
	return TRUE

/datum/component/ai/hearing/Destroy()
	parent.unregister_event(/event/hear, src, src::on_hear())
	..()

/datum/component/ai/hearing/proc/on_hear(datum/speech/speech)
	set waitfor = FALSE
	var/filtered_message = speech.message
	filtered_message = replacetext(filtered_message , "?" , "") //Ignores punctuation.
	filtered_message = replacetext(filtered_message , "!" , "") //Ignores punctuation.
	filtered_message = replacetext(filtered_message , "." , "") //Ignores punctuation.
	filtered_message = replacetext(filtered_message , "," , "") //Ignores punctuation.
	if(speech.speaker != parent)
		if(!required_messages.len)
			sleep(response_delay)
			INVOKE_EVENT(parent, hear_signal, hear_args)
		else
			for(var/message in required_messages)
				if(findtext(filtered_message,message))
					sleep(response_delay)
					if(pass_speech)
						if(pass_speech == WITH_FOUND_REMOVED)
							filtered_message = replacetext(filtered_message,message,"")
						hear_args = filtered_message
					INVOKE_EVENT(parent, hear_signal, hear_args)
					return

/datum/component/ai/hearing/say
	hear_signal = /event/comp_ai_cmd_say

/datum/component/ai/hearing/say_response
	hear_signal = /event/comp_ai_cmd_specific_say

/datum/component/ai/hearing/say_response/time
	required_messages = list("what time is it","whats the time","do you have the time")

/datum/component/ai/hearing/say_response/time/on_hear(var/datum/speech/speech)
	hear_args = list("The current time is [worldtime2text()].")
	..()

/datum/component/ai/hearing/order
	hear_signal = /event/comp_ai_cmd_order
	required_messages = list("can i get","do you have","can i have","id like","i want","give me","get me","i would like")
	pass_speech = WITH_FOUND_REMOVED
	var/list/blacklist_items = list()
	var/list/whitelist_items = list()
	var/notfoundmessage
	var/freemessage = "Coming right up!"
	var/toomuchmessage = "Too much stuff in your order, come collect it before ordering again."
	var/baseprice = 0
	var/currentprice
	var/inbag = FALSE
	var/list/items2deliver = list()

/datum/component/ai/hearing/order/initialize()
	..()
	parent.register_event(/event/comp_ai_cmd_order, src, .proc/on_order)
	if(!notfoundmessage)
		notfoundmessage = "ERROR-[Gibberish(rand(1000,9999),50)]: Item not found. Please try again."
	return TRUE

/datum/component/ai/hearing/order/Destroy()
	parent.unregister_event(/event/comp_ai_cmd_order, src, .proc/on_order)
	..()

/datum/component/ai/hearing/order/proc/build_whitelist()
	return

/datum/component/ai/hearing/order/proc/on_order(var/message)
	if(isliving(parent))
		var/mob/living/M=parent
		if(!M.isDead())
			if(items2deliver.len > 5)
				M.say(toomuchmessage)
			if(!whitelist_items.len)
				M.say("ERROR-[Gibberish(rand(10000,99999),50)]: No items found. Please contact manufacturer for specifications.")
				CRASH("Someone forgot to put whitelist items on this ordering AI component.")
			var/list/found_items = list()
			for(var/item in whitelist_items)
				var/list/items2workwith = subtypesof(item)
				if(!items2workwith.len)
					items2workwith = list(item)
				for(var/subitem in items2workwith)
					var/isbad = FALSE
					for(var/baditem in blacklist_items)
						if(ispath(subitem,baditem))
							isbad = TRUE
							break
					if(isbad)
						continue
					if(ispath(subitem,/obj/item))
						var/obj/item/I = subitem
						if(findtext(message,initial(I.name)))
							found_items[subitem] = initial(I.name)
					if(ispath(subitem,/datum/reagent))
						var/datum/reagent/R = subitem
						if(findtext(message,initial(R.name)))
							found_items[subitem] = initial(R.name)
			for(var/founditem in found_items)
				for(var/itemcheck in found_items)
					if(findtext(found_items[itemcheck],found_items[founditem]) && !ispath(founditem,itemcheck))
						found_items -= founditem
						break
			items2deliver += found_items
			currentprice += rand(baseprice-(baseprice/5),baseprice+(baseprice/5)) * found_items.len
			if(!found_items.len)
				M.say(notfoundmessage)
			else if(!baseprice || !currentprice)
				M.say(freemessage)
				spawn_items()
			else
				M.say("That will be [currentprice] credit\s.")
				if(!(src in active_components))
					active_components += src

/datum/component/ai/hearing/order/process()
	if(currentprice && isliving(parent))
		var/mob/living/M=parent
		if(!M.isDead())
			var/amount = 0
			var/list/bills = list()
			for(var/obj/item/weapon/spacecash/C in get_step(M,M.dir))
				amount += C.get_total()
				bills += C
				if(amount > currentprice)
					break
			if(amount)
				playsound(M.loc, pick('sound/items/polaroid1.ogg','sound/items/polaroid2.ogg'), 70, 1)
				for(var/obj/O in bills)
					qdel(O)
				currentprice -= amount
				if(currentprice <= 0)
					if(currentprice < 0)
						dispense_cash(abs(currentprice),get_step(M,M.dir))
						currentprice = 0
					spawn_items()
					active_components -= src
				else
					M.say("[currentprice] credit\s left to pay.")

/datum/component/ai/hearing/order/proc/spawn_items()
	if(!items2deliver.len)
		return
	if(isliving(parent))
		var/mob/living/M=parent
		if(!M.isDead())
			M.emote("me", 1, "begins processing an order...")
			var/atom/place2deliver = get_step(M,M.dir)
			sleep(rand(5,10) SECONDS)
			if(inbag)
				place2deliver = new /obj/item/weapon/storage/bag/food(place2deliver)
			for(var/item2deliver in items2deliver)
				if(ispath(item2deliver,/atom/movable))
					new item2deliver(place2deliver)
				else if(ispath(item2deliver,/datum/reagent))
					var/datum/reagent/R = item2deliver
					var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/D = new(place2deliver)
					D.reagents.add_reagent(initial(R.id),D.reagents.maximum_volume)
			M.say("[counted_english_list(items2deliver)] served!")
			place2deliver.update_icon()
			items2deliver.Cut()

/datum/component/ai/hearing/order/foodndrinks
	whitelist_items = list(/obj/item/weapon/reagent_containers/food/snacks,/datum/reagent/drink,/obj/item/weapon/reagent_containers/food/drinks/soda_cans)

/datum/component/ai/hearing/order/foodndrinks/select_menu/build_whitelist()
	var/list/new_whitelist = list()
	for(var/item in whitelist_items)
		var/list/stufftochoose = subtypesof(whitelist_items)
		for(var/i in 1 to rand(5,10))
			new_whitelist += pick_n_take(stufftochoose)
	whitelist_items.Cut()
	whitelist_items += new_whitelist
