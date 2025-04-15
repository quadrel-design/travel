/// <reference types="jsr:@supabase/functions-js/edge-runtime.d.ts" />
// import "jsr:@supabase/functions-js/edge-runtime.d.ts"; // Keep commented if directive is used
import { createClient } from 'npm:@supabase/supabase-js@2'; // Revert to npm: specifier

// index.ts - REST API Version
console.log("--- index.ts script loading (REST API Version) ---");

// Helper function to get secrets
function getEnv(key: string): string {
  const value = Deno.env.get(key);
  if (value === undefined) {
    // Throw error if critical secret is missing in production
    throw new Error(`Missing environment variable: ${key}`);
  }
  return value;
}

// --- Google Auth Helpers (JWT for Service Account) ---

const GOOGLE_TOKEN_URI = "https://oauth2.googleapis.com/token";
const GOOGLE_VISION_API_SCOPE = "https://www.googleapis.com/auth/cloud-vision";
const GOOGLE_VISION_API_ENDPOINT = "https://vision.googleapis.com/v1/images:annotate";

interface ServiceAccountCredentials {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
  auth_provider_x509_cert_url: string;
  client_x509_cert_url: string;
  universe_domain: string;
}

// Helper to import PKCS8 private key for Web Crypto API
async function importPrivateKey(pemKey: string): Promise<CryptoKey> {
  // Remove PEM header/footer and line breaks
  const pemBody = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const keyBuffer = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0));

  try {
    return await crypto.subtle.importKey(
      "pkcs8",
      keyBuffer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      true, // extractable
      ["sign"]
    );
  } catch (e) {
     console.error("Failed to import private key:", e);
     throw new Error(`Failed to import private key: ${e.message}`);
  }
}

// Creates a signed JWT assertion
async function createJwtAssertion(
  creds: ServiceAccountCredentials,
  privateKey: CryptoKey
): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600; // Expires in 1 hour

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: creds.client_email,
    scope: GOOGLE_VISION_API_SCOPE,
    aud: GOOGLE_TOKEN_URI,
    exp: exp,
    iat: iat,
  };

  const headerBase64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const payloadBase64 = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const unsignedToken = `${headerBase64}.${payloadBase64}`;

  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    privateKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signatureBase64 = btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  return `${unsignedToken}.${signatureBase64}`;
}

// Fetches an OAuth 2.0 access token
async function getAccessToken(): Promise<string> {
  let creds: ServiceAccountCredentials;
  let privateKey: CryptoKey;
  let assertion: string;

  try { // Add try block for granular logging
    console.log("[getAccessToken] Attempting to get Google credentials secret...");
    const credentialsJson = getEnv('GOOGLE_APPLICATION_CREDENTIALS_JSON');

    console.log("[getAccessToken] Attempting to parse credentials JSON...");
    try {
      creds = JSON.parse(credentialsJson);
    } catch (e) {
      console.error("[getAccessToken] Failed to parse credentials JSON:", e);
      throw new Error(`Invalid credentials JSON: ${e.message}`);
    }
    console.log("[getAccessToken] Credentials parsed, importing private key...");

    privateKey = await importPrivateKey(creds.private_key);
    console.log("[getAccessToken] Private key imported, creating JWT assertion...");

    assertion = await createJwtAssertion(creds, privateKey);
    console.log("[getAccessToken] JWT assertion created, fetching access token...");

  } catch (e) {
    console.error("[getAccessToken] Error during credential/JWT processing:", e);
    throw e; // Re-throw error to be caught by main handler
  }

  // Fetching token (keep outside initial try block for now to separate concerns)
  const response = await fetch(GOOGLE_TOKEN_URI, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: assertion,
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("Failed to fetch access token:", response.status, errorText);
    throw new Error(`Failed to get access token: ${response.status} ${errorText}`);
  }

  const tokenData = await response.json();
  console.log("Access token fetched successfully.");
  return tokenData.access_token;
}

// --- Invoice Keywords & Symbols ---
const INVOICE_KEYWORDS = [
  'invoice', 'bill', 'receipt', 'total', 'amount', 'due', 'tax', 'vat',
  'subtotal', 'payment', 'charge', 'service', 'balance', 'paid'
];
const CURRENCY_SYMBOLS = /\$|€|£|¥|₹/; // Regex for common currency symbols

// --- Main Request Handler ---
Deno.serve(async (req) => {
  const functionStartTime = Date.now();
  console.log(`[${functionStartTime}] Function execution started.`);

  // 1. CORS Preflight
  if (req.method === 'OPTIONS') {
    console.log(`[${functionStartTime}] Handling OPTIONS request.`);
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*', // Adjust for production
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    });
  }

  // 2. Validate Method
  if (req.method !== 'POST') {
    console.warn(`[${functionStartTime}] Received non-POST request (${req.method}).`);
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    });
  }

  try {
    console.log(`[${functionStartTime}] Processing POST request...`);
    // 3. Parse Request Body & Get Inputs
    let imageData: string;
    let recordId: string; // <<< Expect recordId
    try {
      const body = await req.json();
      imageData = body.imageData; 
      recordId = body.recordId; // <<< Get recordId from body
      if (!imageData || !recordId) { // <<< Validate both
        throw new Error("Missing 'imageData' or 'recordId' in request body.");
      }
      console.log(`[${functionStartTime}] Received request for recordId: ${recordId} (Image data length: ${imageData.length})`);
    } catch (error) {
      console.error(`[${functionStartTime}] Request Body Error:`, error);
      return new Response(JSON.stringify({ error: 'Invalid request body', details: error.message }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      });
    }

    // 4. Get Google Access Token
    console.log(`[${functionStartTime}] Attempting to get Google access token...`);
    const accessToken = await getAccessToken();
    console.log(`[${functionStartTime}] Google access token obtained.`);

    // 5. Prepare Vision API Request
    const visionRequestBody = {
      requests: [
        {
          image: { content: imageData },
          features: [{ type: 'DOCUMENT_TEXT_DETECTION' }],
        },
      ],
    };

    // 6. Call Google Vision API
    console.log(`[${functionStartTime}] Calling Google Vision API...`);
    const visionApiStartTime = Date.now();
    const visionResponse = await fetch(GOOGLE_VISION_API_ENDPOINT, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: JSON.stringify(visionRequestBody),
    });
    const visionApiEndTime = Date.now();
    console.log(`[${functionStartTime}] Vision API call duration: ${visionApiEndTime - visionApiStartTime} ms, Status: ${visionResponse.status}`);

    if (!visionResponse.ok) {
      const errorText = await visionResponse.text();
      console.error(`[${functionStartTime}] Google Vision API Error Response:`, errorText);
      throw new Error(`Google Vision API failed: ${visionResponse.status} ${errorText}`);
    }

    // 7. Process Vision API Response
    const visionResult = await visionResponse.json();
    const detectedText = visionResult.responses?.[0]?.fullTextAnnotation?.text ?? '';
    const hasPotentialText = detectedText.length > 0;
    console.log(`[${functionStartTime}] Vision API text detection complete. Has Text: ${hasPotentialText}, Text Length: ${detectedText.length}`);

    // 8. Perform Invoice Check (if text detected)
    let isInvoiceGuess = false;
    if (hasPotentialText) {
      const lowerCaseText = detectedText.toLowerCase();
      let keywordCount = 0;
      for (const keyword of INVOICE_KEYWORDS) {
        if (lowerCaseText.includes(keyword)) keywordCount++;
      }
      const hasCurrency = CURRENCY_SYMBOLS.test(lowerCaseText);
      if (keywordCount >= 1 || hasCurrency) { // Adjust threshold if needed
        isInvoiceGuess = true;
      }
      console.log(`[${functionStartTime}] Invoice Check - Keyword Count: ${keywordCount}, Has Currency: ${hasCurrency}, Result: ${isInvoiceGuess}`);
    } else {
      console.log(`[${functionStartTime}] Skipping invoice check as no text was detected.`);
    }

    // 9. Update Supabase Database
    console.log(`[${functionStartTime}] Attempting to update Supabase DB record: ${recordId}...`);
    const supabaseUrl = getEnv('SUPABASE_URL');
    const supabaseAnonKey = getEnv('SUPABASE_ANON_KEY'); 
    // Use service role key for backend updates for security/simplicity
    const supabaseServiceKey = getEnv('SUPABASE_SERVICE_ROLE_KEY'); 

    // Use service role client for update
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    const { error: updateError } = await supabaseAdmin
      .from('journey_images')
      .update({
        has_potential_text: hasPotentialText,
        is_invoice_guess: isInvoiceGuess,
        detected_text: detectedText, // Store the detected text
      })
      .eq('id', recordId); // <<< Use recordId to target the update

    if (updateError) {
      console.error(`[${functionStartTime}] Supabase DB Update Error for record ${recordId}:`, updateError);
      throw new Error(`Failed to update database record: ${updateError.message}`);
    }
    console.log(`[${functionStartTime}] Supabase DB record ${recordId} updated successfully.`);

    // 10. Return Success Response (No body needed)
    const functionEndTime = Date.now();
    console.log(`[${functionStartTime}] Function execution finished successfully. Duration: ${functionEndTime - functionStartTime} ms`);
    return new Response(null, { // Return 204 No Content or simple 200 OK
      status: 200, // Or 204
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json' // Even if body is null
      },
    });

  } catch (error) {
    // Catch errors from any step
    const functionEndTime = Date.now();
    console.error(`[${functionStartTime}] Function execution failed. Duration: ${functionEndTime - functionStartTime} ms. Error:`, error);
    return new Response(JSON.stringify({ error: 'Internal Server Error', details: error.message }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    });
  }
});

console.log("Detect Invoice Text function startup (REST API Version)...");
