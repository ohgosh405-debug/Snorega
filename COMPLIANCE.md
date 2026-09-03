# Snorega HorizonXI compliance review

**Build reviewed:** 1.0.1  
**Review date:** 2026-09-03  
**Creator:** Afoofa  
**Public source:** <https://github.com/ohgosh405-debug/Snorega>

## Approval status

Pending HorizonXI staff review. Snorega must not be loaded or used on HorizonXI
unless and until it appears on HorizonXI's approved addon list.

HorizonXI's current rules state that unlisted addons are prohibited, custom
addons must be publicly available before they can be approved, and approval is
at staff discretion:

- <https://horizonxi.com/rules>
- <https://horizonxi.com/addons>

## Behavior audit

| Area | Snorega behavior |
| --- | --- |
| Player actions | None. The addon never casts, targets, moves, equips, trades, claims, or interacts. |
| Commands | `/sn` commands only change Snorega's timer/display configuration and are initiated by the player. |
| Packets | Reads incoming `0x028` action packets; never injects, modifies, blocks, or sends packets. |
| Chat | Prints status messages locally; never sends party, linkshell, tell, shout, or yell messages. |
| Automation | None. All game actions require direct player input. |
| Game-state reads | Reads the player's Haste buff and party/alliance member identity/job data. |
| Timing | Starts a display timer after the player's Sleepga completes and adjusts visual guidance when a party/alliance BLM begins a qualifying elemental spell. |
| Targeting | Does not read, select, or change targets. The highest-HP-target line is only a static reminder. |
| Persistence | Saves only addon settings such as enabled state, timing values, manually entered BLM names, and panel position. |

## Source-level safeguards

- No outgoing-packet event or injection API.
- No queued game commands or command-manager calls.
- No simulated keyboard/controller input.
- No automatic equipment changes.
- No automatic party communication.
- No unattended loop that performs character activity.

## Policy mapping

### Rule V — Addons and Third-Party Tools

The source is publicly hosted as required for a custom-addon review. Public
hosting does not authorize use; Snorega remains prohibited until staff list it
as approved.

### Rule VII — Botting and Automation

Snorega only observes events and displays guidance. It does not cause any game
action. The player must decide whether and when to press a macro or enter a
command. This is intended to preserve the rule that actions must originate from
player input.

## Reviewer notes

The most review-sensitive feature is the automatic display adjustment after a
party/alliance BLM begins an elemental spell. It is informational only, but
HorizonXI staff should explicitly confirm whether that event-driven timing
display is acceptable. If staff objects, the feature can be removed and the
addon reduced to a fully manual countdown.

This document is a good-faith technical assessment, not an approval or legal
guarantee. HorizonXI staff make the final ruling.
