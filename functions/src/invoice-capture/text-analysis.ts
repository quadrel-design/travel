/**
 * Invoice Text Analysis Cloud Functions
 * ------------------------------------
 * This module provides invoice text analysis using the Google Gemini API.
 * - Exports a callable function `analyzeInvoice` for text analysis and Firestore updates.
 * - Exports a helper `analyzeDetectedText` for direct Gemini analysis logic.
 *
 * Optimized for modularity, error handling, and clear documentation.
 */

/**
 * Analyzes text using the Google Gemini API to identify potential invoices and
 * extract structured data like total amount, currency, date, merchant name, etc.
 * Provides a helper `analyzeDetectedText` and a callable `analyzeImage` function.
 */
// Load environment variables from .env file
import * as dotenv from "dotenv";
dotenv.config();

import * as functions from "firebase-functions/v1";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { app } from "../init";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { config } from "firebase-functions";

// Firestore database reference
const db = getFirestore(app);

// Use Firebase Functions config or .env for Gemini API key
const geminiApiKey = config().gemini?.api_key || process.env.GEMINI_API_KEY || "";

console.log("Gemini API Key configured:", !!geminiApiKey);
console.log("Gemini API Key value:", geminiApiKey);

const genAI = new GoogleGenerativeAI(geminiApiKey);

// Define a type for the Firestore update data
type InvoiceUpdateData = {
  status: string;
  isInvoice: boolean;
  lastProcessedAt: FirebaseFirestore.FieldValue;
  ocrText: string;
  totalAmount?: number;
  currency?: string;
  merchantName?: string;
  merchantLocation?: string;
  invoiceDate?: string;
  invoiceAnalysis?: object;
};

/**
 * Invoice analysis structure for Gemini results.
 */
export interface InvoiceAnalysis {
  totalAmount?: number;
  currency?: string;
  merchantName?: string;
  location?: string;
  date?: string;
  [key: string]: any;
}

/**
 * Analysis result structure for invoice text analysis.
 */
export interface AnalysisResult {
  success: boolean;
  status: string;
  isInvoice: boolean;
  invoiceAnalysis?: InvoiceAnalysis;
  error?: string;
}

/**
 * Performs invoice text analysis using the Gemini API.
 * @param ocrText The raw text extracted from an image.
 * @returns Analysis result object.
 */
export async function analyzeDetectedText(ocrText: string): Promise<AnalysisResult> {
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
      ${ocrText}
      
      Respond ONLY with the JSON object, no additional text.`;
    console.log("Sending text to Gemini for analysis, length:", ocrText.length);
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
            .replace(/[\u0000-\u001F\u007F-\u009F]/gu, "") // eslint-disable-line no-control-regex
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
 * Updates the invoice image document in Firestore with analysis results.
 * @param userId User ID
 * @param projectId Project ID
 * @param invoiceId Invoice ID
 * @param imageId Image ID
 * @param updateData Data to update
 */
async function updateInvoiceImageAnalysisFirestore(userId: string, projectId: string, invoiceId: string, imageId: string, updateData: Record<string, any>) {
  const docRef = db.collection("users")
    .doc(userId)
    .collection("projects")
    .doc(projectId)
    .collection("invoices")
    .doc(invoiceId)
    .collection("invoice_images")
    .doc(imageId);
  await docRef.update(updateData);
}

/**
 * Callable Cloud Function to analyze detected text and optionally update Firestore.
 * - Authenticates the user.
 * - Validates input `ocrText`.
 * - Calls `analyzeDetectedText` to perform the analysis.
 * - Updates Firestore with the analysis results.
 * @param data Request data: { ocrText, projectId, invoiceId, imageId }
 * @param context Callable context (must be authenticated)
 * @returns Analysis result object (see AnalysisResult)
 * @throws HttpsError on authentication, validation, or processing errors.
 */
export const analyzeInvoice = functions.region("us-central1").https.onCall(async (data: any, context: any) => {
  console.log("[DEBUG] data:", data);
  const { projectId, invoiceId, imageId, ocrText } = data;
  console.log("[DEBUG] projectId:", projectId);
  console.log("[DEBUG] invoiceId:", invoiceId);
  console.log("[DEBUG] imageId:", imageId);
  console.log("[DEBUG] ocrText:", ocrText);
  if (!projectId || !invoiceId || !imageId) {
    console.error("Missing projectId, invoiceId or imageId in data:", data);
    throw new functions.https.HttpsError("invalid-argument", "projectId, invoiceId and imageId are required");
  }
  if (!context.auth) {
    console.error("Authentication error: User not authenticated");
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  let docRef: FirebaseFirestore.DocumentReference | null = null;
  if (projectId && invoiceId && imageId && context.auth?.uid) {
      docRef = db.collection("users")
          .doc(context.auth.uid)
          .collection("projects")
          .doc(projectId)
          .collection("invoices")
          .doc(invoiceId)
          .collection("invoice_images")
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
    const analysisResult = await analyzeDetectedText(ocrText);
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
        const updateData: InvoiceUpdateData = {
          status: finalStatus,
          isInvoice: analysisResult.isInvoice,
          lastProcessedAt: FieldValue.serverTimestamp(),
          ocrText
        };
        if (analysisResult.success && analysisResult.invoiceAnalysis) {
          const ia = analysisResult.invoiceAnalysis as InvoiceAnalysis;
          updateData.totalAmount = ia.totalAmount;
          updateData.currency = ia.currency;
          updateData.merchantName = ia.merchantName;
          updateData.merchantLocation = ia.location;
          updateData.invoiceDate = ia.date;
          // Do NOT add invoiceAnalysis to updateData
          // Write analysis to subcollection instead:
          const analysisDocRef = docRef.collection("analyses").doc("latest");
          await analysisDocRef.set({
            invoiceAnalysis: ia,
            updatedAt: FieldValue.serverTimestamp(),
          });
          console.log("[DEBUG] Wrote latest Gemini analysis to analyses/latest");
        } else {
          console.warn("[DEBUG] Skipping Firestore update for invoiceAnalysis. Reason:", {
            success: analysisResult.success,
            invoiceAnalysis: analysisResult.invoiceAnalysis
          });
        }
        console.log("Firestore updateData:", updateData, "Doc path:", docRef.path);
        await updateInvoiceImageAnalysisFirestore(context.auth.uid, projectId, invoiceId, imageId, updateData);
        console.log(`Updated invoice analysis in Firestore. Final Status: ${finalStatus}`);
      } catch (dbError) {
        console.error("Error updating Firestore with analysis results:", dbError);
      }
    }
    return analysisResult;
  } catch (error) {
    console.error("Error in analyzeInvoice function:", error);
    throw new functions.https.HttpsError("internal", "Error analyzing invoice text: " + (error instanceof Error ? error.message : "Unknown error"));
  }
});