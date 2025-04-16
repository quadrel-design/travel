import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
// import { corsHeaders } from '../_shared/cors.ts'; // Use shared CORS headers - Defined locally instead
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'; // If needed for user context, etc.

console.log(`Location Autocomplete function booting up...`);

// Define CORS headers locally
const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Allow requests from any origin (restrict in production!)
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Google Cloud Vision API Configuration
const GOOGLE_PLACES_API_KEY = Deno.env.get('GOOGLE_PLACES_API_KEY');
const AUTOCOMPLETE_API_URL = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';

interface PlacesAutocompleteResponse {
  predictions: {
    description: string;
    place_id: string; // Keep place_id if you might need details later
    // ... other fields if needed
  }[];
  status: string;
  error_message?: string;
}

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    console.log("Handling OPTIONS request");
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Validate API Key
    if (!GOOGLE_PLACES_API_KEY) {
      console.error('Missing GOOGLE_PLACES_API_KEY environment variable.');
      throw new Error('Server configuration error: Missing API key.');
    }

    // 2. Parse request body and get query
    console.log("Parsing request body...");
    const body = await req.json();
    const query = body.query;

    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      console.error('Missing or invalid "query" parameter in request body.');
      return new Response(JSON.stringify({ error: 'Missing or invalid query parameter.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400, // Bad Request
      });
    }
    console.log(`Received autocomplete query: "${query}"`);

    // 3. Construct Google Places API URL
    // Consider adding session token management if desired (more complex for edge function)
    const params = new URLSearchParams({
      input: query,
      key: GOOGLE_PLACES_API_KEY,
      types: '(cities)', // Restrict to cities (adjust as needed)
      // sessiontoken: 'YOUR_SESSION_TOKEN' // Optional: Generate/manage session tokens
    });
    const requestUrl = `${AUTOCOMPLETE_API_URL}?${params.toString()}`;

    // 4. Call Google Places API
    console.log(`Calling Places API: ${requestUrl}`);
    const placesResponse = await fetch(requestUrl, {
      method: 'GET', // Autocomplete is usually GET
      headers: { 'Content-Type': 'application/json' },
    });

    console.log(`Places API response status: ${placesResponse.status}`);
    if (!placesResponse.ok) {
      const errorBody = await placesResponse.text();
      console.error(`Places API HTTP error response: ${placesResponse.status}`, errorBody);
      throw new Error(`Upstream API request failed: ${placesResponse.status} ${placesResponse.statusText}`);
    }

    // 5. Parse and Process Response
    const placesResult = await placesResponse.json() as PlacesAutocompleteResponse;

    if (placesResult.status === 'OK') {
      const suggestions = placesResult.predictions.map(p => p.description);
      console.log(`Returning ${suggestions.length} suggestions.`);
      return new Response(JSON.stringify({ suggestions }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    } else if (placesResult.status === 'ZERO_RESULTS') {
       console.log('Places API returned ZERO_RESULTS.');
       return new Response(JSON.stringify({ suggestions: [] }), { // Return empty list
         headers: { ...corsHeaders, 'Content-Type': 'application/json' },
         status: 200,
       });
    } else {
      // Handle other statuses (REQUEST_DENIED, INVALID_REQUEST, etc.)
      console.error(`Places API returned error status: ${placesResult.status} - ${placesResult.error_message ?? 'No error message provided.'}`);
      throw new Error(`Upstream API error: ${placesResult.status}`);
    }

  } catch (error) {
    console.error('Error in Edge Function:', error);
    // Return generic server error
    return new Response(JSON.stringify({ error: error.message || 'An unexpected error occurred' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
}); 