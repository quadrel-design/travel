/**
 * Analyzes text using the Google Gemini API to identify potential invoices and
 * extract structured data like total amount, currency, date, merchant name, etc.
 * Provides a helper `analyzeDetectedText` and a callable `analyzeImage` function.
 */
// Load environment variables from .env file
import * as dotenv from "dotenv";
dotenv.config();

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { app } from "../init";
import { GoogleGenerativeAI } from "@google/generative-ai";

// Firestore database reference
const db = getFirestore(app);

// Restore Gemini API key and client setup
const geminiApiKey = process.env.FUNCTIONS_CONFIG ? 
  JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.api_key || 
  JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.key : 
  process.env.GEMINI_API_KEY || "";

console.log("Gemini API Key configured:", !!geminiApiKey);

const genAI = new GoogleGenerativeAI(geminiApiKey);

/**
 * Analyzes detected text using the Gemini API to extract invoice information.
 * Attempts to parse the response as JSON, cleans it if necessary, and determines
 * if the text represents an invoice based on extracted fields.
 * 
 * @param {string} extractedText The raw text extracted from an image.
 * @returns {Promise<object>} A promise resolving to an object containing:
 *  - success: boolean
 *  - status: string ("Invoice", "Text", "Error")
 *  - isInvoice: boolean
 *  - invoiceAnalysis?: object (Extracted invoice data if successful)
 *  - error?: string (If an error occurred)
 */
export async function analyzeDetectedText(extractedText: string) {
  try {
    if (!geminiApiKey) {
      console.warn("No Gemini API key available. Skipping analysis and returning Text status.");
      return {
        success: true,
        isInvoice: false,
        status: "Text",
        error: "No API key available for analysis"
      };
    }
    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash-lite",
      generationConfig: {
        temperature: 0.1,
        topK: 1,
        topP: 1,
      },
    });
    const prompt = `Analyze this text from an image and extract the following information in JSON format:
      - totalAmount: the total amount as a number (required)
      - currency: the currency code (e.g., USD, EUR) (required)
      - date: the date in ISO format (YYYY-MM-DD)
      - merchantName: the name of the merchant/business
      - location: the location or address
      
      Text to analyze:
      ${extractedText}
      
      Respond ONLY with the JSON object, no additional text.`;
    console.log("Sending text to Gemini for analysis, length:", extractedText.length);
    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const analysisText = response.text();
      console.log("Received response from Gemini, length:", analysisText.length);
      let invoiceAnalysis;
      try {
        const jsonText = analysisText.replace(/```json\n?|\n?```/g, "").trim();
        console.log("Cleaned JSON text:", jsonText.substring(0, 200) + (jsonText.length > 200 ? "..." : ""));
        try {
          invoiceAnalysis = JSON.parse(jsonText);
          console.log("Successfully parsed JSON response");
        } catch (parseError) {
          console.error("JSON parse error:", parseError);
          console.log("Attempting to fix malformed JSON response");
          const cleanedJson = jsonText
            .replace(/[\u0000-\u001F\u007F-\u009F]/gu, "")
            .replace(/[^\x20-\x7E]/g, "")
            .trim();
          try {
            invoiceAnalysis = JSON.parse(cleanedJson);
            console.log("Success after JSON cleanup");
          } catch (e) {
            throw new Error(`Failed to parse JSON after cleanup: ${e.message}`);
          }
        }
        if (typeof invoiceAnalysis.totalAmount === "string") {
          const parsed = parseFloat(invoiceAnalysis.totalAmount);
          if (!isNaN(parsed)) {
            invoiceAnalysis.totalAmount = parsed;
          }
        }
        const isInvoice = !!(invoiceAnalysis.totalAmount && invoiceAnalysis.currency);
        invoiceAnalysis.isInvoice = isInvoice;
        console.log("Analysis result determined invoice status:", isInvoice);
        return {
          success: true,
          invoiceAnalysis,
          status: isInvoice ? "Invoice" : "Text",
          isInvoice
        };
      } catch (e) {
        console.error("Failed to parse Gemini response:", e);
        console.error("Raw response:", analysisText);
        return {
          success: true,
          status: "Text",
          isInvoice: false,
          error: "Failed to parse analysis results"
        };
      }
    } catch (error) {
      console.error("Error analyzing text with Gemini:", error);
      return {
        success: false,
        status: "Text",
        isInvoice: false,
        error: "Failed to analyze text"
      };
    }
  } catch (error) {
    console.error("Error in text analysis:", error);
    return {
      success: false,
      status: "Error",
      isInvoice: false,
      error: error instanceof Error ? error.message : "Unknown error occurred",
    };
  }
}

/**
 * Callable Cloud Function to analyze detected text and optionally update Firestore.
 * - Authenticates the user.
 * - Validates input `extractedText`.
 * - Calls `analyzeDetectedText` to perform the analysis.
 * - If `invoiceId` and `imageId` are provided, updates the corresponding Firestore
 *   document with the analysis results (status, isInvoice, extracted fields).
 * 
 * @param {CallableRequest} request The request object.
 * @param {object} request.data The data passed to the function:
 * @param {string} request.data.extractedText The text to analyze.
 * @param {string} [request.data.invoiceId] Optional: The ID of the parent invoice document.
 * @param {string} [request.data.imageId] Optional: The ID of the image document to update.
 * @param {object} request.auth Authentication information for the calling user.
 * @param {string} request.auth.uid The UID of the authenticated user.
 * 
 * @returns {Promise<object>} A promise resolving to the result object from `analyzeDetectedText`.
 * @throws {HttpsError} Throws HttpsError on authentication, validation, or processing errors.
 */
export const analyzeImage = onCall({
  enforceAppCheck: false,
  timeoutSeconds: 120,
}, async (request) => {
  console.log("analyzeImage function called with data:", request.data);
  if (!request.data.invoiceId || !request.data.imageId) {
    console.error("Missing invoiceId or imageId in request:", request.data);
    throw new HttpsError("invalid-argument", "invoiceId and imageId are required");
  }
  if (!request.auth) {
    console.error("Authentication error: User not authenticated");
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const { extractedText, invoiceId, imageId } = request.data;
  if (!extractedText) {
    console.error("Invalid request: No extracted text provided");
    throw new HttpsError("invalid-argument", "Must provide extracted text for analysis");
  }
  let docRef: FirebaseFirestore.DocumentReference | null = null;
  if (invoiceId && imageId && request.auth?.uid) {
      docRef = db.collection("users")
          .doc(request.auth.uid)
          .collection("invoices")
          .doc(invoiceId)
          .collection("images")
          .doc(imageId);
  }
  try {
    if (docRef) {
      try {
        await docRef.update({ status: "analysis_running" });
        console.log("Set status to analysis_running");
      } catch (preUpdateError) {
        console.error("Error setting status to analysis_running:", preUpdateError);
      }
    }
    const analysisResult = await analyzeDetectedText(extractedText);
    console.log("Text analysis result:", analysisResult);
    if (docRef) {
      try {
        let finalStatus = "analysis_failed";
        if (analysisResult.success) {
          if (analysisResult.status === "Invoice") {
            finalStatus = "analysis_complete";
          } else if (analysisResult.status === "Text") {
            finalStatus = "analysis_failed";
          }
        }
        const updateData: any = {
          status: finalStatus,
          isInvoice: analysisResult.isInvoice,
          lastProcessedAt: FieldValue.serverTimestamp()
        };
        if (analysisResult.success && analysisResult.invoiceAnalysis) {
          updateData.totalAmount = analysisResult.invoiceAnalysis.totalAmount;
          updateData.currency = analysisResult.invoiceAnalysis.currency;
          updateData.merchantName = analysisResult.invoiceAnalysis.merchantName;
          updateData.merchantLocation = analysisResult.invoiceAnalysis.location;
          updateData.invoiceDate = analysisResult.invoiceAnalysis.date;
          updateData.invoiceAnalysis = analysisResult.invoiceAnalysis;
        }
        await docRef.update(updateData);
        console.log(`Updated invoice analysis in Firestore. Final Status: ${finalStatus}`);
      } catch (dbError) {
        console.error("Error updating Firestore in analyzeImage function:", dbError);
      }
    }
    return analysisResult;
  } catch (error) {
    console.error("Error in analyzeImage function:", error);
    if (docRef) {
      try {
        await docRef.update({ status: "analysis_failed" });
        console.log("Set status to analysis_failed due to function error");
      } catch (finalErrorUpdate) {
          console.error("Failed to update status to analysis_failed on error:", finalErrorUpdate);
      }
    }
    throw new HttpsError("internal", "Error analyzing text: " + (error instanceof Error ? error.message : "Unknown error"));
  }
}); 