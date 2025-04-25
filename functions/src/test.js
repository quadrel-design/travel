// Load environment variables from .env file
require('dotenv').config();

const functions = require("firebase-functions-test")();
const { scanImage } = require("./index");
const fs = require("fs");

// Set up environment variables for testing
process.env.GOOGLE_APPLICATION_CREDENTIALS = "./splitbase-7ec0f-9618a4571647.json";

// Check for required environment variables
if (!process.env.GEMINI_API_KEY) {
  console.error("❌ Error: GEMINI_API_KEY environment variable is required.");
  console.error("Please check your .env file or set it before running the test:");
  console.error("export GEMINI_API_KEY=your_api_key_here");
  process.exit(1);
}

async function testScanImage() {
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
    
    // Create a wrapped version of the function with auth context
    const wrapped = functions.wrap(scanImage);
    const auth = { uid: 'test-user', email: 'test@example.com' };
    
    // First test without Gemini analysis to verify text extraction
    console.log("\nTesting text extraction only...");
    const textResult = await wrapped({
      data: {
        imageUrl: imagePath,
        journeyId: "test-journey",
        imageId: "test-image",
        skipAnalysis: true
      },
      auth
    });
    
    if (textResult.success && textResult.hasText) {
      console.log("✅ Text extraction successful");
      console.log("Extracted text:", textResult.text);
      console.log("Confidence:", textResult.confidence);
      console.log("Number of text blocks:", textResult.textBlocks?.length);
    } else {
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
      auth
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
      } else {
        console.log("❌ No invoice analysis available");
      }
    } else {
      console.log("\n❌ Analysis failed");
      if (result.error) {
        console.log("Error:", result.error);
      }
    }
  } catch (error) {
    console.error("\n❌ Test failed with error:", error);
  } finally {
    functions.cleanup();
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