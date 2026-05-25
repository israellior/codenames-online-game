const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.onPlayerLeaveDuringGame =
functions.firestore
  .document("rooms/{roomId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only care about in-game rooms
    if (before.state !== "in_game" || after.state !== "in_game") {
      return null;
    }

    const beforePlayers = before.players || [];
    const afterPlayers = after.players || [];

    // Find removed players
    const removed = beforePlayers.filter(
      bp => !afterPlayers.some(ap => ap.id === bp.id)
    );

    // Ignore bots
    const removedHumans = removed.filter(
      p => !p.id.startsWith("bot_")
    );

    if (removedHumans.length === 0) {
      return null;
    }

    // ⚠️ Only process once
    if (after.state === "game_over") {
      return null;
    }

    const leaver = removedHumans[0];
    const losingTeam = leaver.team;

    if (!losingTeam || losingTeam === "none") {
      return null;
    }

    const winningTeam = losingTeam === "red" ? "blue" : "red";

    console.log(
      `Player ${leaver.id} left during game. ${losingTeam} loses.`
    );

    await change.after.ref.update({
      state: "game_over",
      winner: winningTeam,
      forcedEnd: true,
      endReason: "player_left",
      endedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });
