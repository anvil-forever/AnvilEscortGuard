-- Anvil Escort Guard
-- Copyright (C) 2026 Anvil Forever
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Quest IDs of escort quests (an NPC starts walking when the quest is accepted).
-- The guard also recognises escorts by the game's quest tag (84, "Escort"), so this
-- list only has to cover quests whose tag is missing or wrong.
-- Sources and permissions: see THIRD_PARTY.md. To add a quest: open a pull request
-- with the quest ID, its name and how you checked it (Forever only).

local _, ns = ...

ns.EscortIDs = {
    -- Classic-era escorts that also exist in WoW Forever
    [155] = true,  -- The Defias Brotherhood (The Defias Traitor)
    [219] = true,  -- Missing In Action (Corporal Keeshan)
    [309] = true,  -- Protecting the Shipment (Miran)
    [434] = true,  -- The Attack! (Tyrion)
    [435] = true,  -- Escorting Erland
    [648] = true,  -- Rescue OOX-17/TN!
    [660] = true,  -- Hints of a New Plague? (Kinelory)
    [665] = true,  -- Sunken Treasure (Professor Phizzlethorpe)
    [667] = true,  -- Death From Below (Shakes O'Breen)
    [731] = true,  -- The Absent Minded Prospector (Prospector Remtravel)
    [836] = true,  -- Rescue OOX-09/HL!
    [863] = true,  -- The Escape (Wizzlecrank's Shredder)
    [898] = true,  -- Free From the Hold (Gilthares Firebough)
    [938] = true,  -- Mist
    [945] = true,  -- Therylune's Escape
    [976] = true,  -- Supplies to Auberdine (Feero Ironhand)
    [994] = true,  -- Escape Through Force (Volcor)
    [995] = true,  -- Escape Through Stealth (Volcor)
    [1144] = true, -- Willix the Importer
    [1222] = true, -- Stinky's Escape (Alliance)
    [1270] = true, -- Stinky's Escape (Horde)
    [1273] = true, -- Questioning Reethe (Ogron)
    [1324] = true, -- The Missing Diplomat (Private Hendel)
    [1393] = true, -- Galen's Escape
    [1440] = true, -- Return to Vahlarriel (Dalinda Malem)
    [1560] = true, -- Tooga's Quest
    [2742] = true, -- Rin'ji is Trapped!
    [2767] = true, -- Rescue OOX-22/FE!
    [2845] = true, -- Wandering Shay
    [2904] = true, -- A Fine Mess (Kernobee)
    [3367] = true, -- Suntara Stones (Dorius Stonetender)
    [3382] = true, -- A Crew Under Fire (Captain Vanessa Beltis)
    [3525] = true, -- Extinguishing the Idol (Belnistrasz)
    [3982] = true, -- What Is Going On? (Commander Gor'shak)
    [4121] = true, -- Precarious Predicament (Grark Lorkrub)
    [4245] = true, -- Chasing A-Me 01
    [4261] = true, -- Ancient Spirit (Arei)
    [4322] = true, -- Jail Break! (Marshal Windsor)
    [4491] = true, -- A Little Help From My Friends (Ringo)
    [4492] = true, -- Lost! (Ringo)
    [4770] = true, -- Homeward Bound (Pao'ka Swiftmountain)
    [4901] = true, -- Guardians of the Altar (Ranshalla)
    [4904] = true, -- Free at Last (Lakota Windsong)
    [4966] = true, -- Protect Kanati Greycloud
    [5203] = true, -- Rescue From Jaedenar (Captured Arko'narin)
    [5321] = true, -- The Sleeper Has Awakened (Kerlonian Evershade)
    [5713] = true, -- One Shot. One Kill. (Sentinel Aynasha)
    [5821] = true, -- Bodyguard for Hire (Cork Gizelton)
    [5943] = true, -- Gizelton Caravan (Rigger Gizelton)
    [5944] = true, -- In Dreams (Highlord Taelan Fordring)
    [6132] = true, -- Get Me Out of Here! (Melizza Brimbuzzle)
    [6403] = true, -- The Great Masquerade (Reginald Windsor)
    [6482] = true, -- Freedom to Ruul
    [6523] = true, -- Protect Kaya
    [6544] = true, -- Torek's Assault
    [6641] = true, -- Vorsha the Lasher (Muglash)
    [7046] = true, -- The Scepter of Celebras

    -- New in WoW Forever
    [87491] = true, -- Spark of Freedom
    [88857] = true, -- Saving a Sentinel
    [91696] = true, -- Open Season
    [93125] = true, -- Going Home
    [93585] = true, -- This Light of Mine
    [94556] = true, -- Jom-jom's Escape
    [94927] = true, -- Dunston Checks Out
    [94969] = true, -- Krol'dok No More!
    [96204] = true, -- The Windshaper's Wrath
    [96811] = true, -- Escaping the Shadows
    [97331] = true, -- Zimmix's Great Escape
    [98430] = true, -- The Longwalkers
    [99053] = true, -- Escaping Ban'ethil
    [99123] = true, -- Lost in the Shadows
    [99144] = true, -- Seeking Refuge
}
