"use strict";
/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */
var _a, _b;
Object.defineProperty(exports, "__esModule", { value: true });
exports.scanImage = void 0;
const https_1 = require("firebase-functions/v2/https");
const app_1 = require("firebase-admin/app");
const vision_1 = require("@google-cloud/vision");
const generative_ai_1 = require("@google/generative-ai");
// Initialize Firebase Admin
(0, app_1.initializeApp)();
// Initialize Vision API client
const vision = new vision_1.ImageAnnotatorClient({
    keyFilename: "./splitbase-7ec0f-9618a4571647.json"
});
// Initialize Gemini with config
const geminiApiKey = process.env.FUNCTIONS_CONFIG ?
    ((_a = JSON.parse(process.env.FUNCTIONS_CONFIG).gemini) === null || _a === void 0 ? void 0 : _a.api_key) ||
        ((_b = JSON.parse(process.env.FUNCTIONS_CONFIG).gemini) === null || _b === void 0 ? void 0 : _b.key) :
    process.env.GEMINI_API_KEY || "";
console.log("Environment variables:", {
    FUNCTIONS_CONFIG: process.env.FUNCTIONS_CONFIG ? "set" : "undefined",
    GEMINI_API_KEY: geminiApiKey ? "configured" : "not configured"
});
const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey);
// Log the configuration
console.log("Initializing Cloud Function with config:");
console.log("- Gemini API Key configured:", !!geminiApiKey);
exports.scanImage = (0, https_1.onCall)({
    enforceAppCheck: false,
    timeoutSeconds: 300,
    memory: "2GiB",
    maxInstances: 10
}, async (request) => {
    // Check if the user is authenticated
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    // Validate the request data
    if (!request.data.imageUrl) {
        throw new https_1.HttpsError("invalid-argument", "No image URL provided");
    }
    try {
        // Perform OCR on the image
        const [result] = await vision.textDetection(request.data.imageUrl);
        const detections = result.textAnnotations || [];
        if (!detections.length) {
            return {
                success: true,
                hasText: false,
                text: "",
                confidence: 0,
            };
        }
        // Get the full text and confidence score
        const fullText = detections[0].description || "";
        const confidence = detections[0].confidence || 0;
        // Get individual text blocks with their bounding boxes
        const textBlocks = detections.slice(1).map((block) => {
            var _a;
            return ({
                text: block.description || "",
                confidence: block.confidence || 0,
                boundingBox: ((_a = block.boundingPoly) === null || _a === void 0 ? void 0 : _a.vertices)
                    ? {
                        left: Math.min(...block.boundingPoly.vertices.map((v) => v.x || 0)),
                        top: Math.min(...block.boundingPoly.vertices.map((v) => v.y || 0)),
                        right: Math.max(...block.boundingPoly.vertices.map((v) => v.x || 0)),
                        bottom: Math.max(...block.boundingPoly.vertices.map((v) => v.y || 0)),
                    }
                    : undefined,
            });
        });
        if (request.data.skipAnalysis) {
            return {
                success: true,
                hasText: true,
                text: fullText,
                confidence,
                textBlocks,
            };
        }
        // Analyze the text with Gemini
        try {
            const model = genAI.getGenerativeModel({
                model: "gemini-2.5-pro-preview-03-25",
                generationConfig: {
                    temperature: 0.1,
                    topK: 1,
                    topP: 1,
                },
            });
            const prompt = `Analyze this text from an image and determine if it's an invoice or receipt. Extract the following information in JSON format:
        - totalAmount: the total amount as a number (required for invoices/receipts)
        - currency: the currency code (e.g., USD, EUR)
        - date: the date in ISO format (YYYY-MM-DD)
        - merchantName: the name of the merchant/business
        - location: the location or address
        - isInvoice: set to true if this appears to be an invoice or receipt based on these criteria:
          * Contains a total amount or sum
          * Contains a date
          * Contains a business name or merchant
          * Contains itemized list of goods/services with prices OR a single service/product with price
          * May contain tax information, invoice numbers, or receipt numbers
        
        If you're not completely sure if it's an invoice/receipt, still extract any information you can find and set isInvoice based on how many of the above criteria are met.
        
        Text to analyze:
        ${fullText}
        
        Respond ONLY with the JSON object, no additional text.`;
            const result = await model.generateContent(prompt);
            const response = await result.response;
            const analysisText = response.text();
            let invoiceAnalysis;
            try {
                // Remove markdown formatting if present
                const jsonText = analysisText.replace(/```json\n?|\n?```/g, "").trim();
                invoiceAnalysis = JSON.parse(jsonText);
            }
            catch (e) {
                console.error("Failed to parse Gemini response:", e);
                console.error("Raw response:", analysisText);
                invoiceAnalysis = {
                    isInvoice: false,
                    error: "Failed to parse analysis results"
                };
            }
            return {
                success: true,
                hasText: true,
                text: fullText,
                confidence,
                textBlocks,
                invoiceAnalysis,
            };
        }
        catch (error) {
            console.error("Error analyzing text with Gemini:", error);
            return {
                success: true,
                hasText: true,
                text: fullText,
                confidence,
                textBlocks,
                invoiceAnalysis: {
                    isInvoice: false,
                    error: "Failed to analyze text"
                },
            };
        }
    }
    catch (error) {
        console.error("Error processing image:", error);
        return {
            success: false,
            hasText: false,
            text: "",
            confidence: 0,
            error: error instanceof Error ? error.message : "Unknown error occurred",
        };
    }
});
//# sourceMappingURL=index.js.map