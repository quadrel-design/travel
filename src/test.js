// Load environment variables from .env file
require('dotenv').config();

const functions = require("firebase-functions-test")();
const { scanImage } = require("../lib/index");
const fs = require("fs");

// Set up environment variables for testing
process.env.GOOGLE_APPLICATION_CREDENTIALS = "./splitbase-7ec0f-9618a4571647.json";

// Rest of the file remains unchanged 