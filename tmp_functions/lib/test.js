"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const functions = require("firebase-functions-test");
const index_1 = require("./index");
const fs = require("fs");
// Set up environment variables for testing
process.env.GOOGLE_APPLICATION_CREDENTIALS = "./splitbase-7ec0f-9618a4571647.json";
// Check for Gemini API key
if (!process.env.GEMINI_API_KEY) {
    console.warn("⚠️ Warning: GEMINI_API_KEY environment variable is not set. Text analysis will be skipped.");
}
const testEnv = functions();
// Mock the DecodedIdToken
const mockToken = {
    aud: "test-project",
    auth_time: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 3600,
    iat: Math.floor(Date.now() / 1000),
    iss: "https://securetoken.google.com/test-project",
    sub: "test-user",
    uid: "test-user",
    firebase: {
        identities: {},
        sign_in_provider: "custom"
    }
};
// Mock the Request object
const mockRequest = {
    rawBody: Buffer.from(""),
    body: {},
    query: {},
    params: {},
    headers: {},
    get: () => "",
    header: () => "",
    accepts: () => false,
};
async function testScanImage() {
    var _a;
    const imagePath = "/Users/christian/Desktop/Projects/travel/assets/test/invoice-test.png";
    // Verify the image exists
    if (!fs.existsSync(imagePath)) {
        throw new Error(`Test image not found at path: ${imagePath}`);
    }
    try {
        console.log("Testing scanImage function with local test image...");
        console.log("Image path:", imagePath);
        console.log("Environment setup:");
        console.log("- GOOGLE_APPLICATION_CREDENTIALS:", process.env.GOOGLE_APPLICATION_CREDENTIALS);
        console.log("- GEMINI_API_KEY:", process.env.GEMINI_API_KEY ? "Set" : "Not set");
        // Create a wrapped version of the function
        const wrapped = testEnv.wrap(index_1.scanImage);
        // First test without Gemini analysis to verify text extraction
        console.log("\nTesting text extraction only...");
        const textResult = await wrapped({
            data: {
                imageUrl: imagePath,
                journeyId: "test-journey",
                imageId: "test-image",
                skipAnalysis: true
            },
            auth: {
                uid: "test-user",
                token: mockToken
            },
            rawRequest: mockRequest,
            acceptsStreaming: false
        });
        if (textResult.success && textResult.hasText) {
            console.log("✅ Text extraction successful");
            console.log("Extracted text:", textResult.text);
            console.log("Confidence:", textResult.confidence);
            console.log("Number of text blocks:", (_a = textResult.textBlocks) === null || _a === void 0 ? void 0 : _a.length);
        }
        else {
            console.log("❌ Text extraction failed");
            if (textResult.error) {
                console.log("Error:", textResult.error);
            }
            return;
        }
        // Now test with full analysis
        console.log("\nTesting full analysis with Gemini...");
        const result = await wrapped({
            data: {
                imageUrl: imagePath,
                journeyId: "test-journey",
                imageId: "test-image"
            },
            auth: {
                uid: "test-user",
                token: mockToken
            },
            rawRequest: mockRequest,
            acceptsStreaming: false
        });
        if (result.success) {
            console.log("\n✅ Analysis completed successfully");
            if (result.invoiceAnalysis) {
                console.log("\nInvoice Analysis Results:");
                console.log("- Is Invoice:", result.invoiceAnalysis.isInvoice);
                console.log("- Total Amount:", result.invoiceAnalysis.totalAmount);
                console.log("- Currency:", result.invoiceAnalysis.currency);
                console.log("- Date:", result.invoiceAnalysis.date);
                console.log("- Merchant:", result.invoiceAnalysis.merchantName);
                console.log("- Location:", result.invoiceAnalysis.location);
                if (result.invoiceAnalysis.error) {
                    console.log("- Analysis Error:", result.invoiceAnalysis.error);
                }
            }
            else {
                console.log("❌ No invoice analysis available");
            }
        }
        else {
            console.log("\n❌ Analysis failed");
            if (result.error) {
                console.log("Error:", result.error);
            }
        }
    }
    catch (error) {
        console.error("\n❌ Test failed with error:", error);
    }
    finally {
        testEnv.cleanup();
    }
}
// Run the test
testScanImage().then(() => {
    console.log("\nTest completed");
    process.exit(0);
}).catch((error) => {
    console.error("\nTest failed:", error);
    process.exit(1);
});
//# sourceMappingURL=test.js.map