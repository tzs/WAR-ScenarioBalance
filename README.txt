ScenarioBalance v1.3

Puts up a small window that shows how many people are in your scenario or
city instance, and how many of them are healers, RDPS, MDPS, and tanks,
for each side. Green numbers are your side, red numbers are the enemy.

For each side, the display is formatted like this:

    12 = 4 + 2 + 1 + 5

The first number is the total number of players. That's followed
by the counts of healers, RDPS, MDPS, and tanks in that order.

There are two display modes, "all" and "active". In "all" mode it shows
all players that are listed on the scenario scoreboard. The game does not
remove players when they bail on a scenario, so the count in "all" mode
can be higher than the number of players actually playing the scenario
or city instance.

In "active" mode, ScenarioBalance tries to filter out the inactive player.
A player is marked as inactive if none of their score items have changed
in the last 120 seconds. As soon as any score changes, an inactive player
will be marked active and rejoin the count.

You can toggle between "all" mode and "active" mode by right-clicking on
the ScenarioBalance window. The current mode is shown in the first line
of the display.

Usage is simple:

    /scbal on
        Turn it on. When you enter a scenario, the window will show and the
        counts will be updated. When you leave the scenario, the window will
        go away.

    /scbal off
        Turn it off. The window will not be shown.

    /scbal
        Same as "/scbal on"

    /scbal test
        Toggles test mode. In test mode, the window is shown even if you
        are not in a scenario. You can use this to move the window around
        so you don't have to waste time in your next scenario screwing
        around with the window position. There will be sample numbers
        shown.

    /scbal mode
        Changes the filter more, cycling between "all" and "active".
        
The window is initially placed just to the left of the map filters button.
You can drag it elsewhere if you wish, and the position will be saved.

You can also use the layout editor to change its position, or to change
the opacity.
