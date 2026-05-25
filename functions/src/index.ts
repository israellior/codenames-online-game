import {onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {GoogleGenerativeAI} from "@google/generative-ai";

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

/* ============================================================
   SPYMASTER BOT
   ============================================================ */

export const generateSpymasterHint = onCall(
  {secrets: [GEMINI_API_KEY]},
  async (request) => {
    if (!request.auth) {
      throw new Error("Unauthenticated");
    }

    const {team, board} = request.data as {
      team: string;
      board: Array<{ word: string; team: string; revealed: boolean }>;
    };

    if (typeof team !== "string" || !Array.isArray(board)) {
      throw new Error("Invalid input");
    }

    const unrevealed = board.filter((c) => c.revealed === false);

    const own = unrevealed.filter((c) => c.team === team).map((c) => c.word);
    const opponent = unrevealed
      .filter((c) => c.team !== team && c.team !== "neutral" && c.team !== "assassin")
      .map((c) => c.word);
    const neutral = unrevealed.filter((c) => c.team === "neutral").map((c) => c.word);
    const assassin = unrevealed.filter((c) => c.team === "assassin").map((c) => c.word);

    const prompt = `
You are the SPYMASTER in CODENAMES for team "${team}".

Your goal is to help your team guess THEIR words safely.

Board information:
- Your team's words: ${own.join(", ") || "(none)"}
- Opponent words: ${opponent.join(", ") || "(none)"}
- Neutral words: ${neutral.join(", ") || "(none)"}
- Assassin word: ${assassin.join(", ") || "(none)"}

Rules:
- Give EXACTLY ONE clue word (not on the board)
- Give a number, based on how many of your team's words are strongly and safely connected to the clue
- NEVER relate to assassin or opponent words
- Prefer SAFE clues even if fewer words
- Avoid ambiguous or risky clues
- Do NOT default to the number 2 
- Use 3 or more when a strong safe cluster exists

Respond EXACTLY in JSON:
{"word":"...", "number":N}
`;

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash",
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 48,
      },
    });

    const result = await model.generateContent(prompt);
    const raw = result.response.text() ?? "";

    const start = raw.indexOf("{");
    const end = raw.lastIndexOf("}");

    if (start === -1 || end === -1) {
      throw new Error("Invalid Gemini response");
    }

    const parsed = JSON.parse(raw.slice(start, end + 1));

    if (
      typeof parsed.word !== "string" ||
      typeof parsed.number !== "number" ||
      parsed.number < 1 ||
      parsed.number > 7
    ) {
      throw new Error("Malformed Gemini response");
    }

    return {
      word: parsed.word,
      number: parsed.number,
    };
  }
);

/* ============================================================
   OPERATIVE BOT (NO COLOR KNOWLEDGE)
   ============================================================ */

export const pickOperativeMove = onCall(
  {secrets: [GEMINI_API_KEY]},
  async (request) => {
    if (!request.auth) {
      throw new Error("Unauthenticated");
    }

    const {
      hintWord,
      hintNumber,
      remainingGuesses,
      board,
    } = request.data as {
      hintWord: string;
      hintNumber: number;
      remainingGuesses: number;
      board: Array<{ word: string; revealed: boolean }>;
    };

    if (
      typeof hintWord !== "string" ||
      typeof hintNumber !== "number" ||
      typeof remainingGuesses !== "number" ||
      !Array.isArray(board)
    ) {
      throw new Error("Invalid input");
    }

    const unrevealed = board
      .map((c, i) => (!c.revealed ? {index: i, word: c.word} : null))
      .filter(Boolean) as Array<{ index: number; word: string }>;

    if (unrevealed.length === 0) {
      return {index: -1};
    }

    const boardText = unrevealed
      .map((c) => `(${c.index}) "${c.word}"`)
      .join(", ");

    const prompt = `
You are an OPERATIVE in CODENAMES.

IMPORTANT RULES:
- You do NOT know card colors
- You do NOT know which word is assassin
- You ONLY see unrevealed words
- You may choose to STOP guessing if unsure

Unrevealed words:
${boardText}

Clue:
- Word: "${hintWord}"
- Number: ${hintNumber}
- Remaining guesses: ${remainingGuesses}

Task:
- Choose the BEST matching word index
- If NO word clearly matches the clue, respond with -1

Respond with ONE INTEGER ONLY.
Do not explain.
`;

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash",
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 16,
      },
    });

    const result = await model.generateContent(prompt);
    const raw = result.response.text() ?? "";

    const match = raw.match(/-?\d+/);
    if (match) {
      const idx = Number(match[0]);
      if (
        idx === -1 ||
        unrevealed.some((c) => c.index === idx)
      ) {
        return {index: idx};
      }
    }

    // SAFE fallback: random unrevealed (rare)
    const fallback =
      unrevealed[Math.floor(Math.random() * unrevealed.length)].index;

    return {index: fallback};
  }
);

