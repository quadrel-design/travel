export type InvoiceImageStatus =
  | "uploaded"
  | "ocrInProgress"
  | "ocrError"
  | "ocrNoText"
  | "ocrFinished"
  | "analyzeInProgress"
  | "analyzeError"
  | "analyzeFinished";

export const allowedTransitions: Record<InvoiceImageStatus, InvoiceImageStatus[]> = {
  uploaded: ["ocrInProgress"],
  ocrInProgress: ["ocrError", "ocrNoText", "ocrFinished"],
  ocrError: [],
  ocrNoText: ["analyzeInProgress"],
  ocrFinished: ["analyzeInProgress"],
  analyzeInProgress: ["analyzeError", "analyzeFinished"],
  analyzeError: [],
  analyzeFinished: [],
}; 