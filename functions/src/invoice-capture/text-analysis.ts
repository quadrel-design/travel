/**
 * Analyzes text using the Google Gemini API to identify potential invoices and
 * extract structured data like total amount, currency, date, merchant name, etc.
 * Provides a helper `analyzeDetectedText` and a callable `analyzeImage` function.
 */
// Load environment variables from .env file
import * as dotenv from 'dotenv';
dotenv.config();

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { app } from '../init';

// Firestore database reference
const db = getFirestore(app);

// Initialize Gemini with config
// Retrieve API key from Runtime Config or Environment Variables
const geminiApiKey = process.env.FUNCTIONS_CONFIG ? 
  JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.api_key || 
  JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.key : 
  process.env.GEMINI_API_KEY || "";

console.log("Gemini API Key configured:", !!geminiApiKey);

// Gemini Generative AI client instance
const genAI = new GoogleGenerativeAI(geminiApiKey);

/**
 * Analyzes detected text using the Gemini API to extract invoice information.
 * Attempts to parse the response as JSON, cleans it if necessary, and determines
 * if the text represents an invoice based on extracted fields.
 * 
 * @param {string} detectedText The raw text detected from an image.
 * @returns {Promise<object>} A promise resolving to an object containing:
 *  - success: boolean
 *  - status: string ("Invoice", "Text", "Error")
 *  - isInvoice: boolean
 *  - invoiceAnalysis?: object (Extracted invoice data if successful)
 *  - error?: string (If an error occurred)
 */
export async function analyzeDetectedText(detectedText: string) {
  try {
    // Check if Gemini API key is available
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
      ${detectedText}
      
      Respond ONLY with the JSON object, no additional text.`;

    console.log("Sending text to Gemini for analysis, length:", detectedText.length);
    
    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const analysisText = response.text();
      console.log("Received response from Gemini, length:", analysisText.length);
      
      let invoiceAnalysis;
      try {
        // Remove markdown formatting if present
        const jsonText = analysisText.replace(/```json\n?|\n?```/g, "").trim();
        console.log("Cleaned JSON text:", jsonText.substring(0, 200) + (jsonText.length > 200 ? '...' : ''));
        
        try {
          invoiceAnalysis = JSON.parse(jsonText);
          console.log("Successfully parsed JSON response");
        } catch (parseError) {
          console.error("JSON parse error:", parseError);
          console.log("Attempting to fix malformed JSON response");
          
          // Try to clean the response further and make a best attempt to parse
          const cleanedJson = jsonText
            .replace(/[\u0000-\u001F\u007F-\u009F]/g, "") // Remove control characters
            .replace(/[^\x20-\x7E]/g, "") // Keep only basic ASCII
            .trim();
            
          try {
            invoiceAnalysis = JSON.parse(cleanedJson);
            console.log("Success after JSON cleanup");
          } catch (e) {
            throw new Error(`Failed to parse JSON after cleanup: ${e.message}`);
          }
        }
        
        // Ensure required fields have appropriate types
        if (invoiceAnalysis.totalAmount !== undefined) {
          // Convert totalAmount to a number if it's a string with a numeric value
          if (typeof invoiceAnalysis.totalAmount === 'string') {
            const parsed = parseFloat(invoiceAnalysis.totalAmount);
            if (!isNaN(parsed)) {
              invoiceAnalysis.totalAmount = parsed;
            }
          }
        }
        
        // Determine if it's an invoice based on presence of amount and currency
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
 * - Validates input `detectedText`.
 * - Calls `analyzeDetectedText` to perform the analysis.
 * - If `invoiceId` and `imageId` are provided, updates the corresponding Firestore
 *   document with the analysis results (status, isInvoice, extracted fields).
 * 
 * @param {CallableRequest} request The request object.
 * @param {object} request.data The data passed to the function:
 * @param {string} request.data.detectedText The text to analyze.
 * @param {string} [request.data.invoiceId] Optional: The ID of the parent invoice document.
 * @param {string} [request.data.imageId] Optional: The ID of the image document to update.
 * @param {object} request.auth Authentication information for the calling user.
 * @param {string} request.auth.uid The UID of the authenticated user.
 * 
 * @returns {Promise<object>} A promise resolving to the result object from `analyzeDetectedText`.
 * @throws {HttpsError} Throws HttpsError on authentication, validation, or processing errors.
 */
export const analyzeImage = onCall({
  enforceAppCheck: false, // Consider enabling App Check for production
  timeoutSeconds: 120,
}, async (request) => {
  console.log("analyzeImage function called");

  // Check if the user is authenticated
  if (!request.auth) {
    console.error("Authentication error: User not authenticated");
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  // Validate input
  const { detectedText, invoiceId, imageId } = request.data;
  if (!detectedText) {
    console.error("Invalid request: No detected text provided");
    throw new HttpsError("invalid-argument", "Must provide detected text for analysis");
  }

  try {
    // Analyze the text
    const analysisResult = await analyzeDetectedText(detectedText);
    console.log("Text analysis result:", analysisResult);

    // Update Firestore if invoiceId and imageId are provided
    if (invoiceId && imageId) {
      try {
        const docRef = db.collection('users')
          .doc(request.auth.uid)
          .collection('invoices')
          .doc(invoiceId)
          .collection('images')
          .doc(imageId);
        
        const updateData: any = {
          status: analysisResult.status,
          isInvoice: analysisResult.isInvoice,
          lastProcessedAt: FieldValue.serverTimestamp() // Use server timestamp
        };
        
        // Add invoice analysis data if available
        if (analysisResult.invoiceAnalysis) {
          updateData.totalAmount = analysisResult.invoiceAnalysis.totalAmount;
          updateData.currency = analysisResult.invoiceAnalysis.currency;
          updateData.merchantName = analysisResult.invoiceAnalysis.merchantName;
          updateData.merchantLocation = analysisResult.invoiceAnalysis.location;
          updateData.invoiceDate = analysisResult.invoiceAnalysis.date;
          updateData.invoiceAnalysis = analysisResult.invoiceAnalysis;
        }
        
        await docRef.update(updateData);
        console.log(`Updated invoice analysis in Firestore. Status: ${analysisResult.status}`);
      } catch (dbError) {
        console.error("Error updating Firestore in analyzeImage function:", dbError);
        // Continue and return results even if DB update fails
      }
    }
    
    return analysisResult;
  } catch (error) {
    console.error("Error in analyzeImage function:", error);
    throw new HttpsError("internal", "Error analyzing text: " + (error instanceof Error ? error.message : "Unknown error"));
  }
}); 