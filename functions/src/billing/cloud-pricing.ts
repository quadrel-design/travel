// import * as functions from 'firebase-functions';
import { CloudCatalogClient } from '@google-cloud/billing';
import { logger } from "firebase-functions";
// import admin from 'firebase-admin'; // Assuming admin might be needed later

/**
 * Interface for Cloud Service pricing information
 */
export interface CloudServicePricing {
  serviceId: string;
  serviceName: string;
  skuId: string;
  skuDescription: string;
  pricePerUnit: number;
  tieredPrices?: Array<{
    startUsageAmount: number;
    pricePerUnit: number;
  }>;
  currency: string;
  lastUpdated: Date;
}

/**
 * Configuration for a service to retrieve pricing information
 */
export interface ServiceConfig {
  serviceDisplayName: string;
  serviceId: string;
  skuKeywords: string[];
}

/**
 * Provides a service (`CloudPricingService`) for interacting with the
 * Google Cloud Billing Catalog API to fetch service and SKU information,
 * focusing on retrieving pricing based on service configurations.
 */
export class CloudPricingService {
  private readonly client: CloudCatalogClient;

  /**
   * Initializes the Cloud Billing client.
   */
  constructor() {
    this.client = new CloudCatalogClient();
  }

  /**
   * List all available Google Cloud services
   */
  async listServices() {
    try {
      // Call the Cloud Billing API to list all services
      const [services] = await this.client.listServices({});
      return services || [];
    } catch (error) {
      const errorMessage = (error instanceof Error) ? error.message : String(error);
      logger.error('Error listing services:', { error: errorMessage });
      throw new Error(`Failed to list services: ${errorMessage}`);
    }
  }

  /**
   * Get SKUs for a specific service
   * @param serviceId The ID of the service (e.g., C08E-37B9-80D3)
   */
  async getServiceSkus(serviceId: string) {
    try {
      // Format the service name with the correct format expected by the API
      const parentService = `services/${serviceId}`;
      
      // Call the Cloud Billing API to list SKUs for the specified service
      const [skus] = await this.client.listSkus({
        parent: parentService,
        currencyCode: 'USD' // Or make currency configurable if needed
      });
      return skus || [];
    } catch (error) {
      const errorMessage = (error instanceof Error) ? error.message : String(error);
      logger.error(`Error getting SKUs for service ${serviceId}:`, { error: errorMessage });
      throw new Error(`Failed to get SKUs for service ${serviceId}: ${errorMessage}`);
    }
  }

  /**
   * Find a service by display name or keyword (useful for discovery, but not used in core pricing logic now)
   * @param keyword Keyword to search in service name
   */
  async findServiceByKeyword(keyword: string) {
    const services = await this.listServices();
    const lowercaseKeyword = keyword.toLowerCase();
    
    return services.find(service => 
      service.displayName?.toLowerCase().includes(lowercaseKeyword) ||
      service.name?.toLowerCase().includes(lowercaseKeyword)
    );
  }

  /**
   * Get pricing for a specific Google Cloud service based on provided config
   * @param config Service configuration containing serviceId and skuKeywords
   * @returns Cloud service pricing information, or null if not found
   */
  async getServicePricing(config: ServiceConfig): Promise<Omit<CloudServicePricing, 'lastUpdated'> | null> {
    try {
      // 1. Use the provided service ID directly
      const serviceId = config.serviceId;
      const serviceName = config.serviceDisplayName;
      
      // 2. Get all SKUs for the service
      const skus = await this.getServiceSkus(serviceId);
      
      if (skus.length === 0) {
        logger.warn(`No SKUs found for service: ${serviceName} (${serviceId})`);
        return null;
      }
      
      // 3. Find the specific SKU matching the keywords
      const targetSku = skus.find(sku => {
        if (!sku.description) return false; // Skip SKUs with no description
        // Check if the SKU description contains ANY of the specified keywords (case-insensitive)
        return config.skuKeywords.some(keyword => 
          sku.description.toLowerCase().includes(keyword.toLowerCase())
        );
      });
      
      if (!targetSku) {
        logger.warn(`No matching SKU found for ${serviceName} (${serviceId}) with keywords: [${config.skuKeywords.join(', ')}]`);
        
        // Log a few SKU descriptions to help debug if needed (optional)
        /*
        logger.info(`Sample SKUs available for ${serviceName}:`);
        skus.slice(0, 5).forEach(sku => {
          logger.info(`- ${sku?.description}`);
        });
        */
        
        return null;
      }
      
      // 4. Extract pricing information
      const pricingInfo = targetSku.pricingInfo?.[0];
      if (!pricingInfo) {
        logger.warn(`No pricing information available for SKU: ${targetSku.description} (${targetSku.name})`);
        return null;
      }
      
      // 5. Process tiered pricing if available
      const tieredRates = pricingInfo.pricingExpression?.tieredRates || [];
      const tieredPrices = tieredRates.map(tier => {
        // Safely handle potential null or undefined unitPrice
        const units = Number(tier.unitPrice?.units ?? 0);
        const nanos = Number(tier.unitPrice?.nanos ?? 0) / 1e9; // 1,000,000,000
        const price = units + nanos;
        
        return {
          startUsageAmount: Number(tier.startUsageAmount ?? 0),
          pricePerUnit: price
        };
      }).sort((a, b) => a.startUsageAmount - b.startUsageAmount); // Ensure tiers are sorted
      
      // 6. Determine the default price (often the first tier, but could be 0 if free tier exists)
      // Use the price of the tier starting at 0, or the first tier if no 0 tier exists, or 0 otherwise.
      const defaultPriceTier = tieredPrices.find(tier => tier.startUsageAmount === 0) || tieredPrices[0];
      const defaultPrice = defaultPriceTier?.pricePerUnit ?? 0;
      
      // Prepare the result (excluding lastUpdated, which will be added when writing to DB)
      return {
        serviceId: `services/${serviceId}`, // Full service name format
        serviceName: serviceName,
        skuId: targetSku.name, // Full SKU name format
        skuDescription: targetSku.description || '',
        pricePerUnit: defaultPrice,
        tieredPrices: tieredPrices.length > 0 ? tieredPrices : undefined,
        // Use currencyCode from the pricing expression, default to USD
        // Access via bracket notation due to potential type mismatch
        currency: pricingInfo.pricingExpression?.['currencyCode'] ?? 'USD',
      };
    } catch (error) {
      const errorMessage = (error instanceof Error) ? error.message : String(error);
      logger.error(`Error getting pricing for service ${config.serviceDisplayName} (${config.serviceId}):`, { error: errorMessage });
      return null;
    }
  }

  // Removed getVisionApiOcrPricing
  // Removed getCloudStoragePricing
  // Removed getCloudFunctionsPricing
  // Removed getComputeEnginePricing
  // Removed getAllServicePricing (this orchestration logic will move to the update script)
} 