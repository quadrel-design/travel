import * as dotenv from 'dotenv';
import { GoogleGenerativeAI } from '@google/generative-ai';

async function testGemini() {
  const apiKey = process.env.GEMINI_API_KEY;
  
  if (!apiKey) {
    console.error("❌ GEMINI_API_KEY environment variable is not set");
    process.exit(1);
  }
  
  console.log("✅ GEMINI_API_KEY is set");
  
  try {
    // Initialize Gemini 
    const genAI = new GoogleGenerativeAI(apiKey);
    
    // Get a model
    const model = genAI.getGenerativeModel({
      model: "gemini-2.5-pro-preview-03-25",
      generationConfig: {
        temperature: 0.1,
      },
    });
    
    console.log("\nTesting Gemini API connectivity...");
    
    // Test with a simple prompt
    const result = await model.generateContent("Say hello and confirm that the Gemini API is working correctly.");
    const response = await result.response;
    const text = response.text();
    
    console.log(`\nResponse from Gemini: "${text}"`);
    console.log("\n✅ Success! Gemini API is working");
    
    return true;
  } catch (error) {
    console.error("\n❌ Error testing Gemini API:");
    console.error(error);
    return false;
  }
}

// Load environment variables
dotenv.config();

// Log environment variables
console.log("Environment variables:");
console.log(`- GEMINI_API_KEY: ${process.env.GEMINI_API_KEY ? "Found" : "Not found"}`);
console.log(`- GOOGLE_APPLICATION_CREDENTIALS: ${process.env.GOOGLE_APPLICATION_CREDENTIALS || "Not set"}`);
console.log(`- FUNCTIONS_CONFIG: ${process.env.FUNCTIONS_CONFIG ? "Set" : "Not set"}`);

// Check .runtimeconfig.json if present
try {
  const fs = require('fs');
  if (fs.existsSync('../../.runtimeconfig.json')) {
    const config = JSON.parse(fs.readFileSync('../../.runtimeconfig.json', 'utf8'));
    console.log("Found .runtimeconfig.json with Gemini configuration:");
    console.log(`- gemini.api_key: ${config.gemini?.api_key ? "Present" : "Not present"}`);
  } else {
    console.log("No .runtimeconfig.json file found");
  }
} catch (error) {
  console.warn("Error reading .runtimeconfig.json:", error.message);
}

// Run the test
testGemini().catch(error => {
  console.error("Unexpected error:", error);
  process.exit(1);
}); 