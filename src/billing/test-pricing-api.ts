/**
 * Test script to fetch Vision API pricing data from Cloud Billing Catalog API
 * 
 * Run with: npx ts-node src/billing/test-pricing-api.ts
 */

import axios from 'axios';
import { GoogleAuth } from 'google-auth-library';

// Cloud Billing Catalog API endpoint (provides public pricing information)
const PRICING_API_BASE_URL = 'https://cloudbilling.googleapis.com/v2beta';

// Vision API service ID in Pricing API format
const VISION_API_SERVICE = 'services/570F-492C-BDE4';

// Text detection keyword to find the right SKU
const TEXT_DETECTION_KEYWORD = 'text detection';

/**
 * Main test function to fetch Vision API pricing
 */
async function testVisionApiPricing() {
  try {
    // Get authentication client
    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/cloud-platform']
    });

    console.log('Getting authentication token...');
    const authClient = await auth.getClient();
    const authToken = await authClient.getAccessToken();
    
    if (!authToken || !authToken.token) {
      throw new Error('Failed to get authentication token');
    }
    
    console.log('Successfully authenticated with Google Cloud');
    
    // Get available services to verify API access
    const servicesUrl = `${PRICING_API_BASE_URL}/services`;
    console.log(`Fetching services from ${servicesUrl}...`);
    
    const servicesResponse = await axios.get(servicesUrl, {
      headers: {
        'Authorization': `Bearer ${authToken.token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!servicesResponse.data.services) {
      throw new Error('No services found in API response');
    }
    
    console.log(`Found ${servicesResponse.data.services.length} services in total`);
    
    // Find Vision API service to verify it exists
    const visionService = servicesResponse.data.services.find(
      (service: any) => service.name === VISION_API_SERVICE
    );
    
    if (!visionService) {
      throw new Error(`Vision API service (${VISION_API_SERVICE}) not found in available services`);
    }
    
    console.log(`Found Vision API service: ${visionService.displayName}`);
    
    // Get the Vision API SKUs
    const skusUrl = `${PRICING_API_BASE_URL}/skus?parent=${VISION_API_SERVICE}`;
    console.log(`Fetching Vision API SKUs from ${skusUrl}...`);
    
    const skuResponse = await axios.get(skusUrl, {
      headers: {
        'Authorization': `Bearer ${authToken.token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!skuResponse.data.skus || skuResponse.data.skus.length === 0) {
      throw new Error('No Vision API SKUs found in API response');
    }
    
    console.log(`Found ${skuResponse.data.skus.length} SKUs for Vision API`);
    
    // Log some SKU descriptions to check what's available
    console.log('\nSample of Vision API SKUs:');
    skuResponse.data.skus.slice(0, 5).forEach((sku: any, index: number) => {
      console.log(`${index + 1}. ${sku.description} (${sku.name})`);
    });
    
    // Find text detection SKU
    const ocrSku = skuResponse.data.skus.find((sku: any) => {
      const description = sku.description?.toLowerCase() || '';
      return description.includes(TEXT_DETECTION_KEYWORD);
    });
    
    if (!ocrSku) {
      throw new Error(`Text detection SKU not found. Available SKUs: ${skuResponse.data.skus.map((s: any) => s.description).join(', ')}`);
    }
    
    console.log(`\nFound OCR/Text Detection SKU: ${ocrSku.description} (${ocrSku.name})`);
    
    // Get price information for OCR SKU
    const priceUrl = `${PRICING_API_BASE_URL}/${ocrSku.name}/price`;
    console.log(`Fetching price information from ${priceUrl}...`);
    
    const priceResponse = await axios.get(priceUrl, {
      headers: {
        'Authorization': `Bearer ${authToken.token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!priceResponse.data) {
      throw new Error('Price information not found');
    }
    
    // Log the raw price data
    console.log('\nRaw price data:');
    console.log(JSON.stringify(priceResponse.data, null, 2));
    
    // Extract and calculate the price
    const price = priceResponse.data;
    let pricePerUnit = 0;
    let currency = 'USD';
    
    if (price.tieredRates && price.tieredRates.length > 0) {
      const baseRate = price.tieredRates[0];
      
      if (baseRate.unitPrice) {
        const units = baseRate.unitPrice.units || 0;
        const nanos = baseRate.unitPrice.nanos || 0;
        pricePerUnit = Number(units) + (nanos / 1000000000);
        currency = baseRate.unitPrice.currencyCode || 'USD';
      }
    }
    
    console.log(`\nExtracted pricing information:`);
    console.log(`- Price: ${pricePerUnit} ${currency} per ${price.usageUnitDescription || 'unit'}`);
    console.log(`- Effective time: ${price.effectiveTime || 'Not specified'}`);
    
    console.log('\nTest completed successfully!');
  } catch (error) {
    console.error('Error in test:');
    console.error(error);
  }
}

// Run the test
testVisionApiPricing().catch(console.error); 