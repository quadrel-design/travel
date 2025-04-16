import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { decode } from 'https://deno.land/std@0.208.0/encoding/base64.ts';

console.log("Detect Invoice Text function startup (Vision + OpenAI Version)..."); // Add startup log

// Define CORS headers (Restored)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Allow requests from any origin
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', // Specify allowed headers
};

// Initialize Supabase client
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
);

// Google Cloud Vision API Configuration
const GOOGLE_VISION_API_KEY = Deno.env.get('GOOGLE_CLOUD_API_KEY');
const VISION_API_URL = `https://vision.googleapis.com/v1/images:annotate?key=${GOOGLE_VISION_API_KEY}`;

// OpenAI API Configuration
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY'); // Fetch key from Supabase Vault
const OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'; // Keep URL hardcoded for now
// Read model, temp, tokens from env vars with defaults
const OPENAI_MODEL = Deno.env.get('OPENAI_MODEL') ?? 'gpt-3.5-turbo';
const OPENAI_TEMPERATURE = parseFloat(Deno.env.get('OPENAI_TEMPERATURE') ?? '0.1'); // Parse float, default 0.1
const OPENAI_MAX_TOKENS = parseInt(Deno.env.get('OPENAI_MAX_TOKENS') ?? '60'); // Parse int, default 60

interface VisionApiResponse {
  responses: {
    fullTextAnnotation?: {
      text: string;
    };
    error?: {
      message: string;
    };
  }[];
}

interface OpenAiApiResponse {
  choices: {
    message: {
      content: string;
    };
  }[];
  error?: {
    message: string;
  };
}

interface ExtractedAmount {
    amount: number | null;
    currency: string | null;
}

// Helper function to safely parse potential JSON in OpenAI response
function tryParseJson(jsonString: string): any | null {
  try {
    // Sanitize potential markdown code fences if present
    const sanitizedString = jsonString.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    return JSON.parse(sanitizedString);
  } catch (error) {
    console.error('Failed to parse JSON from OpenAI response:', error, 'Raw string:', jsonString);
    return null; // Return null or the raw string if parsing fails
  }
}

// Helper function to extract amount and currency from OpenAI response
function extractAmountDetails(content: string | null): ExtractedAmount {
    if (!content) {
        console.log("No content received from OpenAI to extract details.");
        return { amount: null, currency: null };
    }

    const parsedJson = tryParseJson(content);

    if (parsedJson && typeof parsedJson.amount === 'number' && typeof parsedJson.currency === 'string') {
         console.log("Successfully parsed JSON:", parsedJson);
         // Check if currency is a reasonable length (e.g., <= 3 chars for codes, or 1 for symbols)
         if (parsedJson.currency.length > 0 && parsedJson.currency.length <= 3) {
              return { amount: parsedJson.amount, currency: parsedJson.currency.toUpperCase() };
         } else if (parsedJson.currency.length > 3) {
             // Attempt to extract common symbols/codes if a longer string is returned
             const currencyMatch = parsedJson.currency.match(/([€$£]|USD|EUR|GBP|CHF)/i);
             if (currencyMatch) {
                 console.warn("Extracted currency was long, using matched symbol/code:", currencyMatch[1]);
                 return { amount: parsedJson.amount, currency: currencyMatch[1].toUpperCase() };
             } else {
                 console.warn("Extracted currency seems invalid:", parsedJson.currency);
                 return { amount: parsedJson.amount, currency: null }; // Return amount but nullify invalid currency
             }
         } else {
             // Allow empty string if model returns it, maybe indicates not found
             console.warn("Extracted currency is empty string.");
             return { amount: parsedJson.amount, currency: null };
         }
    } else if (parsedJson && (parsedJson.amount === null || parsedJson.currency === null)) {
        // Handle cases where the model explicitly returns nulls in JSON
        console.log("OpenAI explicitly returned null for amount or currency:", parsedJson);
        return {
            amount: typeof parsedJson.amount === 'number' ? parsedJson.amount : null,
            currency: typeof parsedJson.currency === 'string' ? parsedJson.currency : null
        };
    }
    else {
         console.warn("OpenAI response was not in the expected JSON format or types were wrong:", content);
         // Fallback: Try simple regex for amount only if JSON fails (less reliable)
         // Look for numbers with decimal points or common currency symbols nearby
         const amountMatch = content.match(/([€$£]?\s?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})|\d+[.,]\d{1,2})/);
         if (amountMatch) {
             try {
                 // Extract number part, normalize decimal separator
                 const numStr = amountMatch[0].replace(/[€$£\s]/g, '').replace(',', '.');
                 const potentialAmount = parseFloat(numStr);
                 console.log("Using fallback regex, found potential amount:", potentialAmount);
                 // Very basic currency check based on symbols found
                 let potentialCurrency: string | null = null;
                 if (amountMatch[0].includes('€')) potentialCurrency = 'EUR';
                 else if (amountMatch[0].includes('$')) potentialCurrency = 'USD'; // Guess USD for $
                 else if (amountMatch[0].includes('£')) potentialCurrency = 'GBP';
                 return { amount: potentialAmount, currency: potentialCurrency };
             } catch (numError) {
                  console.error("Error parsing fallback number:", numError);
             }
         }
    }

    console.log("Could not extract amount details.");
    return { amount: null, currency: null };
}


serve(async (req: Request) => {
  let journey_image_id: string | null = null; // Define here for broader scope in error handling
  try {
    console.log(`Request received: ${req.method} ${req.url}`);
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
      console.log("Handling OPTIONS request");
      return new Response('ok', { headers: corsHeaders });
    }

    // 1. Extract data from the request
    console.log("Parsing request body...");
    const body = await req.json();
    const image_base64 = body.image_base64;
    journey_image_id = body.journey_image_id; // Assign here

    // --- Input Validation --- 
    const errors: string[] = [];
    if (!image_base64 || typeof image_base64 !== 'string' || image_base64.trim().length === 0) {
      errors.push('Missing or invalid image_base64 (must be a non-empty string).');
    }
    // Basic UUID format check (simple regex)
    const uuidRegex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
    if (!journey_image_id || typeof journey_image_id !== 'string' || journey_image_id.trim().length === 0) {
      errors.push('Missing or invalid journey_image_id (must be a non-empty string).');
    } else if (!uuidRegex.test(journey_image_id)) {
       // Log a warning if it doesn't look like a UUID, but maybe still allow processing?
       // Or make it an error: errors.push('Invalid journey_image_id format (must be a UUID).');
       console.warn(`journey_image_id "${journey_image_id}" does not appear to be a valid UUID format.`);
    }

    if (errors.length > 0) {
      const errorMessage = `Invalid request: ${errors.join(' ')}`;
      console.error(errorMessage, { body }); // Log the error and received body
      return new Response(JSON.stringify({ error: errorMessage }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400, // Bad Request
      });
    }
    // --- End Input Validation ---

    console.log(`Received image_base64 (length: ${image_base64.length}), journey_image_id: ${journey_image_id}`);

    // --- API Key Validation ---
    if (!GOOGLE_VISION_API_KEY) { // Checks for null, undefined, empty string
      console.error(`Missing or empty GOOGLE_CLOUD_API_KEY for image ID: ${journey_image_id}`);
      throw new Error('Missing or empty GOOGLE_CLOUD_API_KEY environment variable');
    }
     if (!OPENAI_API_KEY) { // Checks for null, undefined, empty string
      console.error(`Missing or empty OPENAI_API_KEY for image ID: ${journey_image_id}`);
      throw new Error('Missing or empty OPENAI_API_KEY secret in Supabase Vault');
    }
    // --- End API Key Validation ---

    console.log(`Processing image ID: ${journey_image_id}`);

    // 2. Call Google Vision API for OCR
    console.log(`Calling Google Vision API for image ID: ${journey_image_id}...`);
    const visionApiBody = {
      requests: [
        {
          image: {
            content: image_base64,
          },
          features: [
            // Use DOCUMENT_TEXT_DETECTION for better structure if needed later,
            // but TEXT_DETECTION is sufficient for getting the raw text block.
            { type: 'TEXT_DETECTION' },
          ],
        },
      ],
    };

    const visionResponse = await fetch(VISION_API_URL, {
      method: 'POST',
      body: JSON.stringify(visionApiBody),
      headers: { 'Content-Type': 'application/json' },
    });

    console.log(`Google Vision API response status for image ID ${journey_image_id}: ${visionResponse.status}`);
    if (!visionResponse.ok) {
      const errorBody = await visionResponse.text();
      console.error(`Google Vision API error response body for image ID ${journey_image_id}:`, errorBody);
      throw new Error(`Google Vision API request failed for ${journey_image_id}: ${visionResponse.status} ${visionResponse.statusText}`);
    }

    const visionResult = await visionResponse.json() as VisionApiResponse;
    const annotation = visionResult.responses?.[0]?.fullTextAnnotation;
    const detectedText = annotation?.text?.trim() || null;
    const visionError = visionResult.responses?.[0]?.error?.message;

    // Handle Vision API explicitly returning an error in the response body
    if (visionError) {
       console.error(`Vision API returned an error for image ${journey_image_id}: ${visionError}`);
       // Update DB to indicate processing failed at Vision step
       const { error: updateError } = await supabaseAdmin
            .from('journey_images')
            .update({
                // Set flags indicating failure/no text, but update timestamp
                has_potential_text: false,
                detected_text: null, // Clear any previous text
                is_invoice_guess: false,
                detected_total_amount: null,
                detected_currency: null,
                // TODO: Consider adding a dedicated 'processing_error' text field
                last_processed_at: new Date().toISOString(),
            })
            .eq('id', journey_image_id);
        if (updateError) {
            console.error(`Supabase update error (Vision API error case) for image ID ${journey_image_id}:`, updateError);
            throw updateError; // Throw if DB update fails
        }
        console.log(`DB updated for Vision API error: ${journey_image_id}`);
        // Return 200 OK, but indicate failure in the message
        return new Response(JSON.stringify({ 
            error: `Processing failed: Vision API error: ${visionError}`,
            journey_image_id 
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200, // Indicate function completed, but processing failed
         });
    }

    // Handle case where Vision processed successfully but found no text
    if (!detectedText) {
        console.log(`No text detected by Vision API for image ${journey_image_id}. Updating DB.`);
        // Update DB indicating no text found
         const { error: updateError } = await supabaseAdmin
            .from('journey_images')
            .update({
                has_potential_text: false,
                detected_text: null,
                is_invoice_guess: false,
                detected_total_amount: null,
                detected_currency: null,
                last_processed_at: new Date().toISOString(), // Add timestamp
            })
            .eq('id', journey_image_id);
        if (updateError) {
            console.error(`Supabase update error (no text case) for image ID ${journey_image_id}:`, updateError);
            throw updateError;
        }
        console.log(`DB updated for no text detected: ${journey_image_id}`);
        return new Response(JSON.stringify({ message: 'No text detected', journey_image_id }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
         });
    }

    console.log(`Detected text for ${journey_image_id} (length: ${detectedText.length}). First 100 chars: ${detectedText.substring(0, 100)}...`);

    // 3. Basic Invoice Guess (optional, keep if useful)
    const simpleInvoiceGuess = /(invoice|rechnung|total|amount|betrag)/i.test(detectedText);
    console.log(`Simple invoice guess: ${simpleInvoiceGuess}`);

    // 4. Call OpenAI API to extract total amount and currency
    let extractedAmount: number | null = null;
    let extractedCurrency: string | null = null;

    console.log(`Calling OpenAI API for image ID: ${journey_image_id} using model: ${OPENAI_MODEL}, temp: ${OPENAI_TEMPERATURE}, tokens: ${OPENAI_MAX_TOKENS}...`);
    try {
        const openAiApiBody = {
          model: OPENAI_MODEL, // Use env var
          messages: [
            {
              role: 'system',
              // --- Use New, Refined Prompt --- 
              content: `You are an expert invoice and receipt processing assistant. Your SOLE task is to identify the single FINAL TOTAL AMOUNT PAYABLE (e.g., Grand Total, Total Due, Endbetrag, Gesamtbetrag) and its corresponding CURRENCY symbol or 3-letter ISO code from the provided OCR text.

CRITICAL INSTRUCTIONS:
1. FOCUS EXCLUSIVELY on the **final amount** the customer has to pay. This is often located near the bottom of the text.
2. ACTIVELY IGNORE all other numbers, including: line item prices, quantities, subtotals, tax amounts (like VAT, Sales Tax, MwSt.), discounts, shipping costs, or any intermediate calculations.
3. Respond ONLY with a valid JSON object in the format: {"amount": <number | null>, "currency": "<string | null>"}.
4. Use '.' as the decimal separator for the amount (e.g., 123.45).
5. For currency, use standard 3-letter ISO codes (e.g., "EUR", "USD", "GBP") or common symbols (e.g., "€", "$", "£").
6. If you CANNOT confidently determine the single final total amount payable, respond with: {"amount": null, "currency": null}. Do not guess if unsure.`
              // --- End New Prompt --- 
            },
            {
              role: 'user',
              content: `Extract the final total amount and currency from the following text:\n\n${detectedText}`
            }
          ],
          temperature: OPENAI_TEMPERATURE, // Use env var
          max_tokens: OPENAI_MAX_TOKENS, // Use env var
          response_format: { type: "json_object" } // Request JSON output
        };

        const openAiResponse = await fetch(OPENAI_API_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${OPENAI_API_KEY}`
          },
          body: JSON.stringify(openAiApiBody)
        });

        console.log(`OpenAI API response status for image ID ${journey_image_id}: ${openAiResponse.status}`);
        // Log OpenAI errors but don't throw - allow DB update with null amounts
         if (!openAiResponse.ok) {
          const errorBody = await openAiResponse.text();
          console.error(`OpenAI API HTTP error response for image ID ${journey_image_id}: ${openAiResponse.status}`, errorBody);
          // Proceed without amount/currency
        } else {
             const openAiResult = await openAiResponse.json() as OpenAiApiResponse;
             if (openAiResult.error) {
                 console.error(`OpenAI API returned an error object for image ID ${journey_image_id}:`, openAiResult.error.message);
                  // Proceed without amount/currency
             } else {
                const messageContent = openAiResult.choices?.[0]?.message?.content;
                console.log('OpenAI raw response content:', messageContent); // Log raw response
                if (messageContent) {
                    const details = extractAmountDetails(messageContent);
                    extractedAmount = details.amount;
                    extractedCurrency = details.currency;
                    console.log(`Extracted amount for image ID ${journey_image_id}: ${extractedAmount}, Currency: ${extractedCurrency}`);
                } else {
                     console.warn("No message content found in OpenAI response.");
                }
             }
        }

    } catch (error) {
         // Catch network errors during OpenAI call
         console.error(`Network or other error during OpenAI API call for image ${journey_image_id}:`, error);
         // Proceed without amount/currency
    }


    // 5. Update Supabase
    console.log(`Updating Supabase for image ID ${journey_image_id} with Amount: ${extractedAmount}, Currency: ${extractedCurrency}`);
    const { error: updateError } = await supabaseAdmin
      .from('journey_images')
      .update({
        has_potential_text: true,
        detected_text: detectedText,
        is_invoice_guess: simpleInvoiceGuess, // Keep simple guess for now
        detected_total_amount: extractedAmount, // Store extracted amount
        detected_currency: extractedCurrency,   // Store extracted currency
        last_processed_at: new Date().toISOString(), // Add timestamp
      })
      .eq('id', journey_image_id);

    if (updateError) {
      console.error(`Supabase update error for image ID ${journey_image_id}:`, updateError);
      throw updateError; // Throw if DB update fails
    }

    console.log(`Successfully processed and updated image ID: ${journey_image_id}`);

    // 6. Return success response
    return new Response(JSON.stringify({
         message: 'Image processed successfully',
         journey_image_id,
         detected_text_length: detectedText.length,
         is_invoice_guess: simpleInvoiceGuess,
         detected_total_amount: extractedAmount,
         detected_currency: extractedCurrency
     }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    // Use journey_image_id if available in the error message
    console.error(`Unhandled Error in Edge Function (Image ID: ${journey_image_id ?? 'unknown'}):`, error);
    return new Response(JSON.stringify({ error: error.message || 'An unexpected error occurred' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});