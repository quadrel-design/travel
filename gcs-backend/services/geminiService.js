/**
 * @fileoverview Gemini AI Service Module.
 * This module provides functionality to interact with Google's Gemini AI models for analyzing text.
 * It is primarily used to parse OCR (Optical Character Recognition) text from invoices or receipts
 * and extract structured data such as total amount, date, merchant name, etc.
 * Requires the `GEMINI_API_KEY` environment variable to be set.
 * @module services/geminiService
 */
const { GoogleGenerativeAI } = require('@google/generative-ai');

const geminiApiKey = process.env.GEMINI_API_KEY;
const genAI = new GoogleGenerativeAI(geminiApiKey);

// Debug log to verify project ID and credentials
// These are less relevant here as Gemini uses an API Key primarily for this client,
// but keeping for consistency during current debugging phase.
console.log('Gemini Service: GOOGLE_CLOUD_PROJECT:', process.env.GOOGLE_CLOUD_PROJECT);
console.log('Gemini Service: GOOGLE_APPLICATION_CREDENTIALS:', process.env.GOOGLE_APPLICATION_CREDENTIALS);

/**
 * @async
 * @function analyzeDetectedText
 * @summary Analyzes OCR text using Gemini AI to extract structured invoice/receipt data.
 * @description Sends the provided OCR text to the Gemini AI model with a specific prompt
 * to identify if the text is from an invoice/receipt and to extract key information
 * like total amount, currency, date, merchant name, location, taxes, and category.
 * It includes retry logic for API calls and robust JSON parsing of the AI's response.
 * 
 * @param {string} ocrText - The raw text extracted from an image by an OCR process.
 * @returns {Promise<object>} A promise that resolves to an object containing the analysis results.
 *   @property {boolean} success - True if the analysis (API call and parsing) was successful, false otherwise.
 *   @property {object|null} invoiceAnalysis - If successful and parsing worked, an object containing extracted data:
 *     @property {number|null} totalAmount - The final total amount, as a numeric value.
 *     @property {string|null} currency - The 3-letter currency code (e.g., USD, EUR).
 *     @property {string|null} date - Invoice/receipt date in ISO format (YYYY-MM-DD).
 *     @property {string|null} merchantName - Name of the merchant.
 *     @property {string|null} location - Location/address of the merchant.
 *     @property {number|null} taxes - Tax amount, as a numeric value.
 *     @property {string|null} category - Primary expense category.
 *     @property {string|null} taxonomy - Hierarchical classification (e.g., "travel/accommodation/hotel").
 *     @property {boolean} isInvoice - True if the AI determined the text is likely an invoice/receipt (based on totalAmount and currency presence).
 *   @property {string} status - A string indicating the outcome: 
 *                                 `'Invoice'` (successful, likely an invoice),
 *                                 `'Text'` (successful, but not classified as an invoice),
 *                                 `'ConfigurationError'` (API key missing),
 *                                 `'ParsingError'` (failed to parse AI response),
 *                                 `'ApiError'` (Gemini API call failed after retries).
 *   @property {boolean} isInvoice - Overall determination if the text is an invoice (matches `invoiceAnalysis.isInvoice`).
 *   @property {string} [error] - An error message if `success` is false.
 */
async function analyzeDetectedText(ocrText) {
  if (!geminiApiKey) {
    console.error("GEMINI_API_KEY is not set. Gemini analysis will be skipped.");
    return {
      success: false,
      isInvoice: false,
      invoiceAnalysis: null,
      status: "ConfigurationError",
      error: "No API key available for analysis. Gemini service not configured."
    };
  }
  const model = genAI.getGenerativeModel({
    model: "gemini-1.5-flash-latest",
    generationConfig: {
      temperature: 0.1,
      topK: 1,
      topP: 1,
    },
  });
  const prompt = `Analyze this text from an invoice or receipt image and extract the following information in a structured JSON format:

    - totalAmount: The final total amount paid, as a numeric value without currency symbols (REQUIRED)
    - currency: The 3-letter currency code (e.g., USD, EUR, GBP, JPY) (REQUIRED)
    - date: The invoice/receipt date in ISO format (YYYY-MM-DD)
    - merchantName: The full name of the merchant, company, or service provider
    - location: The physical location, address, or city of the merchant
    - taxes: The tax amount as a numeric value (include VAT, sales tax, etc.)
    - category: The primary expense category (e.g., food, transportation, accommodation, office, entertainment)
    - taxonomy: A hierarchical classification with '/' separators (e.g., "travel/accommodation/hotel", "business/office/supplies")

    Text from image to analyze:
    ${ocrText}

    Important: 
    - If you're uncertain about a value, use null rather than guessing
    - For totalAmount and taxes, return numeric values only (e.g., 10.99, not "$10.99")
    - Ensure all key names match exactly as specified above
    - Respond ONLY with the JSON object, no additional text, explanations, or markdown formatting`;

  try {
    let result;
    let response;
    let analysisText = '';
    const maxRetries = 2; // Max 2 retries (total 3 attempts)
    const retryDelay = 1500; // 1.5 seconds delay
    let lastApiError = null;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        console.log(`[GeminiService] Attempting to generate content (Attempt ${attempt + 1}/${maxRetries + 1})`);
        result = await model.generateContent(prompt);
        response = await result.response; // Assuming result.response is synchronous or a fast promise
        analysisText = response.text();   // Assuming response.text() is synchronous or a fast promise
        lastApiError = null; // Clear last error on success
        console.log("[GeminiService] Content generated successfully.");
        break; // Success, exit retry loop
      } catch (apiError) {
        lastApiError = apiError;
        console.error(`[GeminiService] API call failed (Attempt ${attempt + 1}/${maxRetries + 1}):`, apiError.message);
        if (attempt < maxRetries) {
          console.log(`[GeminiService] Retrying in ${retryDelay / 1000}s...`);
          await new Promise(resolve => setTimeout(resolve, retryDelay));
        } else {
          console.error("[GeminiService] Max retries reached for Gemini API call.");
        }
      }
    }

    if (lastApiError) {
      // If all retries failed, throw the last error to be caught by the outer try-catch
      throw lastApiError;
    }

    // Continue with parsing if API call was successful
    let invoiceAnalysis = null;
    try {
      const jsonText = analysisText.replace(/```json\n?|\n?```/g, "").trim();
      try {
        invoiceAnalysis = JSON.parse(jsonText);
      } catch (parseError) {
        console.warn("Initial JSON.parse failed for Gemini response. Attempting cleanup...", parseError);
        console.warn("Original text from Gemini:", analysisText);
        console.warn("Trimmed text:", jsonText);
        const cleanedJson = jsonText
          .replace(/[\u0000-\u001F\u007F-\u009F]/gu, "")
          .trim();
        console.warn("Cleaned text for parsing:", cleanedJson);
        invoiceAnalysis = JSON.parse(cleanedJson);
      }

      let numericTotalAmount;
      if (invoiceAnalysis && typeof invoiceAnalysis.totalAmount !== 'undefined') {
        if (typeof invoiceAnalysis.totalAmount === 'string') {
          const parsed = parseFloat(invoiceAnalysis.totalAmount.replace(/[^\d.-]/g, ''));
          if (!isNaN(parsed)) {
            invoiceAnalysis.totalAmount = parsed;
            numericTotalAmount = parsed;
          }
        } else if (typeof invoiceAnalysis.totalAmount === 'number' && !isNaN(invoiceAnalysis.totalAmount)) {
          numericTotalAmount = invoiceAnalysis.totalAmount;
        }
      }

      const isInvoice = !!(numericTotalAmount !== undefined && invoiceAnalysis && invoiceAnalysis.currency);
      if (invoiceAnalysis) {
        invoiceAnalysis.isInvoice = isInvoice;
      }

      return {
        success: true,
        invoiceAnalysis,
        status: isInvoice ? "Invoice" : "Text",
        isInvoice
      };
    } catch (e) {
      console.error("Failed to parse Gemini analysis results into JSON:", e);
      console.error("Original text from Gemini that failed parsing:", analysisText);
      return {
        success: false,
        invoiceAnalysis: null,
        status: "ParsingError",
        isInvoice: false,
        error: "Failed to parse analysis results from Gemini. Content may be malformed."
      };
    }
  } catch (error) {
    console.error("Error during Gemini content generation:", error);
    return {
      success: false,
      invoiceAnalysis: null,
      status: "ApiError",
      isInvoice: false,
      error: error instanceof Error ? error.message : "Unknown error occurred during Gemini API call",
    };
  }
}

module.exports = { analyzeDetectedText }; 