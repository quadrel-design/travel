const dotenv = require("dotenv"); dotenv.config(); console.log("GEMINI_API_KEY:", process.env.GEMINI_API_KEY ? "exists" : "missing");
