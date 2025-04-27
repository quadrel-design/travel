/**
 * @file google-vision-api-pricing.ts
 * @description Scheduled function that fetches Google Cloud Vision API pricing from the public Cloud Billing Catalog API.
 * 
 * This module fetches public pricing information for the Google Cloud Vision API
 * and stores it in Firestore for application use.
 * 
 * @requires Cloud Billing API to be enabled (cloudbilling.googleapis.com)
 * @requires No special permissions (uses public pricing information)
 */

import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { initializeApp } from "firebase-admin/app";
import axios from 'axios';
import { GoogleAuth } from 'google-auth-library';

// Initialize Firebase
const app = initializeApp();

// Initialize Firestore
const db = getFirestore(app);

// Cloud Billing Catalog API endpoint (provides public pricing information)
const PRICING_API_BASE_URL = 'https://cloudbilling.googleapis.com/v2beta';

/**
 * Interface for storing Vision API pricing data in Firestore
 */
interface VisionApiPricing {
  serviceType: string;
  priceUnit: string;
  provider: string;
  pricePerUse: number;
  pricePerSingleUse: number; // Price for a single use
  description: string;
  currency: string;
  costOverall: number;
  currentPriceModel: string;
  lastUpdate: FieldValue;
  freeTierLimit: number;  // Number of free requests per month
  error?: string;
}

/**
 * Configuration for Vision API pricing
 */
const VISION_API_CONFIG = {
  displayName: 'Cloud Vision API',
  serviceName: 'services/570F-492C-BDE4', // Vision API service ID in Pricing API format
  documentName: 'Google Vision',
  skuKeyword: 'text detection', // For OCR/Text Detection
  defaultPriceUnit: '1000 requests',
  fallbackPrice: 0.00025, // $0.00025 per 1000 requests as fallback
  description: 'Google Cloud Vision API OCR/Text Detection Service',
  freeTierLimit: 1000    // 1000 free requests per month
};

/**
 * Fetches the current price for Google Cloud Vision API OCR/Text Detection
 * Can be called directly from other modules to get the current price
 * 
 * @returns {Promise<{pricePerUse: number, pricePerSingleUse: number, currency: string, priceUnit: string, freeTierLimit: number, error?: string}>} 
 *          The current price per use and pricing details
 */
export async function getCurrentVisionApiPrice(): Promise<{
  pricePerUse: number, 
  pricePerSingleUse: number,
  currency: string, 
  priceUnit: string,
  freeTierLimit: number,
  error?: string
}> {
  try {
    // Use default project ID from environment
    const projectId = process.env.GOOGLE_CLOUD_PROJECT || 'splitbase-7ec0f';
    
    // Get service account credentials for authentication
    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
      projectId
    });

    // Get authentication token
    const authClient = await auth.getClient();
    const authToken = await authClient.getAccessToken();
    
    if (!authToken || !authToken.token) {
      throw new Error('Failed to get authentication token for Cloud Billing Catalog API');
    }
    
    // Get the Vision API SKUs from the public catalog
    const skusUrl = `${PRICING_API_BASE_URL}/skus?parent=${VISION_API_CONFIG.serviceName}`;
    const skuResponse = await axios.get(skusUrl, {
      headers: {
        'Authorization': `Bearer ${authToken.token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!skuResponse.data.skus || skuResponse.data.skus.length === 0) {
      throw new Error('No Vision API SKUs found in Pricing API response');
    }
    
    // Find the text detection/OCR SKU
    const ocrSku = skuResponse.data.skus.find((sku: any) => {
      const description = sku.description?.toLowerCase() || '';
      return description.includes(VISION_API_CONFIG.skuKeyword.toLowerCase());
    });
    
    if (!ocrSku) {
      throw new Error('OCR/Text Detection SKU not found for Vision API');
    }
    
    // Get price information for the OCR SKU
    const priceUrl = `${PRICING_API_BASE_URL}/${ocrSku.name}/price`;
    const priceResponse = await axios.get(priceUrl, {
      headers: {
        'Authorization': `Bearer ${authToken.token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!priceResponse.data) {
      throw new Error('Price information not found for Vision API OCR SKU');
    }
    
    // Extract pricing information
    const price = priceResponse.data;
    let pricePerUse = VISION_API_CONFIG.fallbackPrice;
    let currency = 'USD';
    
    // Parse the price information from the response
    if (price.tieredRates && price.tieredRates.length > 0) {
      const baseRate = price.tieredRates[0];
      
      if (baseRate.unitPrice) {
        const units = baseRate.unitPrice.units || 0;
        const nanos = baseRate.unitPrice.nanos || 0;
        pricePerUse = Number(units) + (nanos / 1000000000);
        currency = baseRate.unitPrice.currencyCode || 'USD';
      }
    }
    
    // Calculate price for a single request (since API price is per 1000 requests)
    const pricePerSingleUse = pricePerUse / 1000;
    
    // Return the current price information
    return {
      pricePerUse,           // Original price per 1000 requests
      pricePerSingleUse,     // Price for a single request
      currency,
      priceUnit: VISION_API_CONFIG.defaultPriceUnit,
      freeTierLimit: VISION_API_CONFIG.freeTierLimit
    };
  } catch (error) {
    console.error("Error fetching Vision API pricing:", error);
    
    // Calculate fallback price for a single request
    const fallbackPricePerSingleUse = VISION_API_CONFIG.fallbackPrice / 1000;
    
    // Return fallback pricing on error
    return {
      pricePerUse: VISION_API_CONFIG.fallbackPrice,
      pricePerSingleUse: fallbackPricePerSingleUse,
      currency: 'USD',
      priceUnit: VISION_API_CONFIG.defaultPriceUnit,
      freeTierLimit: VISION_API_CONFIG.freeTierLimit,
      error: error instanceof Error ? error.message : 'Unknown error fetching pricing data'
    };
  }
}

/**
 * Calculate the price for a specific number of OCR requests, taking into account the free tier
 * 
 * @param {number} requestCount - Number of OCR requests
 * @param {number} usedThisMonth - Number of requests already used this month (optional)
 * @returns {Promise<{cost: number, freeRequestsUsed: number, paidRequestsCount: number, currency: string, error?: string}>} The calculated cost
 */
export async function calculateVisionApiCost(
  requestCount: number, 
  usedThisMonth: number = 0
): Promise<{
  cost: number,
  freeRequestsUsed: number,
  paidRequestsCount: number,
  currency: string,
  error?: string
}> {
  const priceInfo = await getCurrentVisionApiPrice();
  
  // Calculate free tier usage
  const freeRequestsRemaining = Math.max(0, priceInfo.freeTierLimit - usedThisMonth);
  const freeRequestsUsed = Math.min(requestCount, freeRequestsRemaining);
  const paidRequestsCount = Math.max(0, requestCount - freeRequestsUsed);
  
  // Calculate the cost using the price per single request, only for paid requests
  const cost = paidRequestsCount * priceInfo.pricePerSingleUse;
  
  return {
    cost,
    freeRequestsUsed,
    paidRequestsCount,
    currency: priceInfo.currency,
    error: priceInfo.error
  };
}

/**
 * Check if a specific request falls within the free tier
 * 
 * @param {number} usedThisMonth - Number of requests already used this month
 * @returns {Promise<{isFreeTier: boolean, freeRequestsRemaining: number, error?: string}>} Free tier status
 */
export async function checkFreeTierStatus(usedThisMonth: number = 0): Promise<{
  isFreeTier: boolean,
  freeRequestsRemaining: number,
  error?: string
}> {
  const priceInfo = await getCurrentVisionApiPrice();
  
  const freeRequestsRemaining = Math.max(0, priceInfo.freeTierLimit - usedThisMonth);
  const isFreeTier = freeRequestsRemaining > 0;
  
  return {
    isFreeTier,
    freeRequestsRemaining,
    error: priceInfo.error
  };
}

/**
 * Scheduled function that runs every hour to fetch current Google Cloud Vision API pricing
 * and update Firestore with the latest pricing information.
 * 
 * @function GoogleVisionApiPricing
 * @param {Object} event - The event object passed by the scheduler
 * @returns {Promise<void>} A Promise that resolves when the function completes
 */
export const GoogleVisionApiPricing = onSchedule('every 1 hours', async (event) => {
  logger.info("Scheduled function GoogleVisionApiPricing started.");

  try {
    // Get the current pricing data
    const priceInfo = await getCurrentVisionApiPrice();
    
    // Create the Vision API pricing data
    const visionApiPricing: VisionApiPricing = {
      serviceType: 'OCR/Text Detection',
      priceUnit: VISION_API_CONFIG.defaultPriceUnit,
      provider: 'Google Cloud',
      pricePerUse: priceInfo.pricePerUse,
      pricePerSingleUse: priceInfo.pricePerSingleUse,
      description: VISION_API_CONFIG.description,
      currency: priceInfo.currency,
      costOverall: 0, // This will be calculated elsewhere as usage accumulates
      currentPriceModel: 'Pay as you go',
      freeTierLimit: priceInfo.freeTierLimit,
      lastUpdate: FieldValue.serverTimestamp()
    };
    
    // Update Firestore
    const visionRef = db.collection('cloud-pricing').doc(VISION_API_CONFIG.documentName);
    await visionRef.set(visionApiPricing, { merge: true });
    logger.info(`Successfully updated 'cloud-pricing/${VISION_API_CONFIG.documentName}' with current pricing: ${priceInfo.pricePerSingleUse} ${priceInfo.currency} per single request (${priceInfo.pricePerUse} ${priceInfo.currency} per ${priceInfo.priceUnit})`);
    logger.info(`Free tier: ${priceInfo.freeTierLimit} requests per month`);
    
  } catch (error) {
    logger.error("Error fetching Vision API pricing:", error);
    
    // Calculate fallback price for a single request
    const fallbackPricePerSingleUse = VISION_API_CONFIG.fallbackPrice / 1000;
    
    // Update with fallback pricing on error
    const fallbackData: VisionApiPricing = {
      serviceType: 'OCR/Text Detection',
      priceUnit: VISION_API_CONFIG.defaultPriceUnit,
      provider: 'Google Cloud',
      pricePerUse: VISION_API_CONFIG.fallbackPrice,
      pricePerSingleUse: fallbackPricePerSingleUse,
      description: VISION_API_CONFIG.description,
      currency: 'USD',
      costOverall: 0,
      currentPriceModel: 'Pay as you go',
      freeTierLimit: VISION_API_CONFIG.freeTierLimit,
      lastUpdate: FieldValue.serverTimestamp(),
      error: 'Vision API pricing information could not be retrieved from public Cloud Billing Catalog API'
    };
    
    const visionRef = db.collection('cloud-pricing').doc(VISION_API_CONFIG.documentName);
    await visionRef.set(fallbackData, { merge: true });
    logger.info(`Updated 'cloud-pricing/${VISION_API_CONFIG.documentName}' with fallback price due to error`);
  }
  
  logger.info("Scheduled function GoogleVisionApiPricing finished.");
}); 