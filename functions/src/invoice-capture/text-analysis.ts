// Load environment variables from .env file
import * as dotenv from 'dotenv';
dotenv.config();

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { app } from './init';

// Initialize Firestore
const db = getFirestore(app);

// Initialize Gemini with config
const geminiApiKey = process.env.FUNCTIONS_CONFIG ? 
  JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.api_key || 
  JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.key : 
  process.env.GEMINI_API_KEY || "";

console.log("Gemini API Key configured:", !!geminiApiKey);

const genAI = new GoogleGenerativeAI(geminiApiKey);

// Function to analyze detected text for invoice information
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

// Firebase cloud function for text analysis
export const analyzeImage = onCall({
  enforceAppCheck: false,
  timeoutSeconds: 300,
  memory: "2GiB", 
  maxInstances: 10
}, async (request) => {
  console.log("analyzeImage function called with data:", {
    hasText: !!request.data.detectedText,
    journeyId: request.data.journeyId,
    imageId: request.data.imageId
  });

  // Check if the user is authenticated
  if (!request.auth) {
    console.error("Authentication error: User not authenticated");
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  // Validate the request data
  if (!request.data.detectedText) {
    console.error("Invalid request: No detected text provided");
    throw new HttpsError("invalid-argument", "Detected text is required for analysis");
  }

  if (!request.data.journeyId || !request.data.imageId) {
    console.error("Invalid request: Missing journeyId or imageId");
    throw new HttpsError("invalid-argument", "journeyId and imageId are required");
  }

  // Log that we're starting text analysis
  console.log("Starting text analysis");
  
  try {
    // Analyze the detected text
    const analysisResult = await analyzeDetectedText(request.data.detectedText);
    
    // Update Firestore with the analysis results
    if (analysisResult.success) {
      try {
        const docRef = db.collection('journeys')
          .doc(request.data.journeyId)
          .collection('images')
          .doc(request.data.imageId);
        
        const updateData: any = {
          status: analysisResult.status,
          isInvoice: analysisResult.isInvoice,
          lastAnalyzedAt: new Date().toISOString()
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
        
        console.log(`Updated journey image document with analysis results. Status: ${analysisResult.status}`);
      } catch (dbError) {
        console.error("Error updating Firestore:", dbError);
        // Proceed with returning results even if the database update fails
      }
    }
    
    // Log processing result
    console.log("Text analysis completed:", {
      success: analysisResult.success,
      status: analysisResult.status,
      isInvoice: analysisResult.isInvoice
    });
    
    return analysisResult;
  } catch (error) {
    console.error("Error in analyzeImage function:", error);
    throw new HttpsError("internal", "Error analyzing image text: " + (error instanceof Error ? error.message : "Unknown error"));
  }
}); 