"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generative_ai_1 = require("@google/generative-ai");
const admin = require("firebase-admin");
async function testGemini() {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
        console.error("❌ GEMINI_API_KEY environment variable is not set");
        process.exit(1);
    }
    // Initialize Firebase Admin to check project details
    try {
        admin.initializeApp({
            credential: admin.credential.applicationDefault(),
        });
        const projectId = admin.app().options.projectId;
        console.log("\nProject Information:");
        console.log("- Project ID:", projectId);
        console.log("- Service Account:", process.env.GOOGLE_APPLICATION_CREDENTIALS);
    }
    catch (error) {
        console.warn("Could not initialize Firebase Admin:", error);
    }
    console.log("\nTesting Gemini API connectivity...");
    console.log("API Key:", apiKey.substring(0, 8) + "..." + apiKey.substring(apiKey.length - 4));
    try {
        const genAI = new generative_ai_1.GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({
            model: "gemini-pro",
            generationConfig: {
                temperature: 0.1,
            },
        });
        console.log("\nAttempting to generate content...");
        const result = await model.generateContent("Say hello and tell me which API project you're running in!");
        const response = await result.response;
        const text = response.text();
        console.log("\n✅ Success! Gemini API is working");
        console.log("Response:", text);
    }
    catch (error) {
        console.error("\n❌ Error testing Gemini API:");
        if (error.message) {
            console.error("Error message:", error.message);
        }
        if (error.status) {
            console.error("Status:", error.status);
        }
        if (error.statusText) {
            console.error("Status text:", error.statusText);
        }
        if (error.errorDetails) {
            console.error("Error details:", JSON.stringify(error.errorDetails, null, 2));
        }
        process.exit(1);
    }
}
// Run the test
testGemini().catch(error => {
    console.error("Unhandled error:", error);
    process.exit(1);
});
//# sourceMappingURL=test-gemini.js.map