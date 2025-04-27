// import * as functions from 'firebase-functions';
import { logger } from "firebase-functions"; // Use v2 logger
import { CloudPricingService, ServiceConfig, CloudServicePricing } from './cloud-pricing';
// import admin from 'firebase-admin'; // Assuming admin might be needed later

// Service configuration specific to Vision API OCR
const VISION_API_SERVICE_ID = 'C08E-37B9-80D3';
const visionApiOcrConfig: ServiceConfig = {
  serviceDisplayName: 'Cloud Vision API',
  serviceId: VISION_API_SERVICE_ID,
  skuKeywords: ['Text Detection'] // Use the specific keyword identified earlier
};

// Interface for the final formatted pricing data, including single-use price
export interface FormattedCloudServicePricing extends CloudServicePricing {
  singleUsePrice?: number; // Optional, as not all services have a clear single-use price
}

/**
 * Defines configuration and provides a function to fetch and format pricing
 * specifically for the Google Cloud Vision API's Text Detection feature,
 * using the `CloudPricingService`. Calculates an estimated single-use price.
 */
export async function getFormattedVisionOcrPricing(
  pricingService: CloudPricingService
): Promise<FormattedCloudServicePricing | null> {
  try {
    // Fetch the base pricing info using the generic service
    const basePricing = await pricingService.getServicePricing(visionApiOcrConfig);
    
    if (!basePricing) {
      logger.error('Failed to retrieve base pricing for Vision API OCR.');
      return null;
    }
    
    // Calculate the single-use price (price for the first unit above the free tier)
    let singleUsePrice = 0;
    if (basePricing.tieredPrices && basePricing.tieredPrices.length > 0) {
      // Find the first tier with a start amount > 0 and a price > 0
      const firstPaidTier = basePricing.tieredPrices.find(
        tier => tier.startUsageAmount > 0 && tier.pricePerUnit > 0
      );
      if (firstPaidTier) {
        singleUsePrice = firstPaidTier.pricePerUnit;
      }
    }
    
    // Combine base pricing with the calculated single-use price
    const formattedPricing: FormattedCloudServicePricing = {
      ...basePricing,
      singleUsePrice: singleUsePrice,
      lastUpdated: new Date() // Placeholder, will be replaced by server timestamp in Firestore
    };
    
    return formattedPricing;

  } catch (error) {
    const errorMessage = (error instanceof Error) ? error.message : String(error);
    logger.error('Error fetching or formatting Vision API OCR pricing:', { error: errorMessage });
    return null;
  }
} 