require "ALifeRepEditor/people-rows"
local Rows = ALifeRepEditor.PeopleRows

local function people()
    return {
        { uid = "a", name = "Ann Doe", factionName = "Ashguard", at = 5 },
        { uid = "b", name = "Bob Roe", factionName = "Townsfolk", at = 9 },
        { uid = "c", name = "Cal Poe", factionName = "Ashguard", at = nil },
    }
end

test("filter matches name or faction, ignoring case and spaces", function()
    eq(#Rows.filter(people(), ""), 3)
    eq(#Rows.filter(people(), "  ash "), 2)
    eq(Rows.filter(people(), "BOB")[1].uid, "b")
    eq(#Rows.filter(people(), "zzz"), 0)
    eq(#Rows.filter(people(), "a.e"), 0, "plain text, not a pattern")
end)

test("sort puts the focused person first, then the most recent", function()
    local sorted = Rows.sort(people(), "c")
    eq(sorted[1].uid, "c"); eq(sorted[2].uid, "b"); eq(sorted[3].uid, "a")
    sorted = Rows.sort(people(), nil)
    eq(sorted[1].uid, "b"); eq(sorted[3].uid, "c", "never-met last")
end)

test("subtitle and signed read naturally", function()
    eq(Rows.subtitle({ factionName = "Ashguard", stance = "careful" }), "Ashguard, treats you as wary")
    eq(Rows.subtitle({ factionName = "Ashguard" }), "Ashguard")
    eq(Rows.subtitle({ stance = "hostile" }), "treats you as hostile")
    eq(Rows.signed(28), "+28"); eq(Rows.signed(-5), "-5"); eq(Rows.signed(0), "0")
    eq(Rows.indexOf(people(), "b"), 2); eq(Rows.indexOf(people(), "x"), nil)
end)

test("subtitle says when someone is in a crew", function()
    eq(Rows.subtitle({ factionName = "Ashguard", crew = "yours", stance = "friendly" }),
        "Ashguard, in your crew, treats you as friendly")
    eq(Rows.subtitle({ crew = "other" }), "in someone else's crew")
end)

test("crew refusals name the person and the crew limit", function()
    eq(Rows.crewRefusal("too_far", "Pia Doe"), "Pia Doe is too far away; get closer to them and try again.")
    eq(Rows.crewRefusal("roster_full", "Pia Doe", 5), "Your crew is full at 5; dismiss someone first.")
    eq(Rows.crewRefusal("weird", "Pia Doe"), "Pia Doe couldn't join your crew (weird).")
    eq(Rows.crewRefusal("taken", "100% Al"), "100% Al is already in someone else's crew.", "a percent in a name is kept")
end)
