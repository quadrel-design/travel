export type InvoiceImageStatus =
  | "uploaded"
  | "ocrStart"
  | "ocrInProgress"
  | "ocrError"
  | "ocrNoText"
  | "ocrFinished"
  | "analyzeStart"
  | "analyzeInProgress"
  | "analyzeError"
  | "analyzeFinished";

export const allowedTransitions: Record<InvoiceImageStatus, InvoiceImageStatus[]> = {
  uploaded: ["ocrStart"],
  ocrStart: ["ocrInProgress"],
  ocrInProgress: ["ocrError", "ocrNoText", "ocrFinished"],
  ocrError: [],
  ocrNoText: ["analyzeStart"],
  ocrFinished: ["analyzeStart"],
  analyzeStart: ["analyzeInProgress"],
  analyzeInProgress: ["analyzeError", "analyzeFinished"],
  analyzeError: [],
  analyzeFinished: [],
}; 