const { GoogleGenerativeAI } = require('@google/generative-ai');

const geminiApiKey = process.env.GEMINI_API_KEY;
const genAI = new GoogleGenerativeAI(geminiApiKey);

async function analyzeDetectedText(ocrText) {
  if (!geminiApiKey) {
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

  try {
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const analysisText = response.text();
    let invoiceAnalysis;
    try {
      const jsonText = analysisText.replace(/```json\n?|\n?```/g, "").trim();
      try {
        invoiceAnalysis = JSON.parse(jsonText);
      } catch (parseError) {
        // Attempt to clean up malformed JSON
        const cleanedJson = jsonText
          .replace(/[\u0000-\u001F\u007F-\u009F]/gu, "")
          .replace(/[^\x20-\x7E]/g, "")
          .trim();
        invoiceAnalysis = JSON.parse(cleanedJson);
      }
      if (typeof invoiceAnalysis.totalAmount === "string") {
        const parsed = parseFloat(invoiceAnalysis.totalAmount);
        if (!isNaN(parsed)) {
          invoiceAnalysis.totalAmount = parsed;
        }
      }
      const isInvoice = !!(invoiceAnalysis.totalAmount && invoiceAnalysis.currency);
      invoiceAnalysis.isInvoice = isInvoice;
      return {
        success: true,
        invoiceAnalysis,
        status: isInvoice ? "Invoice" : "Text",
        isInvoice
      };
    } catch (e) {
      return {
        success: true,
        status: "Text",
        isInvoice: false,
        error: "Failed to parse analysis results"
      };
    }
  } catch (error) {
    return {
      success: false,
      status: "Text",
      isInvoice: false,
      error: error instanceof Error ? error.message : "Unknown error occurred",
    };
  }
}

module.exports = { analyzeDetectedText }; 