const { GoogleGenerativeAI } = require('@google/generative-ai');

const geminiApiKey = process.env.GEMINI_API_KEY;
const genAI = new GoogleGenerativeAI(geminiApiKey);

// Debug log to verify project ID and credentials
// These are less relevant here as Gemini uses an API Key primarily for this client,
// but keeping for consistency during current debugging phase.
console.log('Gemini Service: GOOGLE_CLOUD_PROJECT:', process.env.GOOGLE_CLOUD_PROJECT);
console.log('Gemini Service: GOOGLE_APPLICATION_CREDENTIALS:', process.env.GOOGLE_APPLICATION_CREDENTIALS);

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
  const prompt = `Analyze this text from an image and extract the following information in JSON format:
    - totalAmount: the total amount as a number (required)
    - currency: the currency code (e.g., USD, EUR) (required)
    - date: the date in ISO format (YYYY-MM-DD)
    - merchantName: the name of the merchant/business
    - location: the location or address

    Text to analyze:
    ${ocrText}

    Respond ONLY with the JSON object, no additional text.`;

  try {
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const analysisText = response.text();
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