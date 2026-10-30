/**
 * Document Categorization Service
 * 
 * High-precision categorization of documents based on OCR extracted text
 * and document metadata. Distinguishes clinical records (Prescription, Lab Report,
 * Blood Test, Scan Report, Discharge Summary, Medical Bill) from general non-medical
 * documents (General / Other).
 * 
 * Strict word-boundary matching prevents false positives (e.g. "IMG" or "agreement" matching "mg").
 */

interface CategoryRule {
  categoryName: string;
  patterns: { pattern: RegExp; tag?: string; weight: number }[];
  requiresMedicalAnchor?: boolean;
}

// Global clinical anchors that confirm a document possesses medical context
const CLINICAL_ANCHORS: RegExp[] = [
  /\b(?:hospital|clinic|dispensary|nursing\s*home|health\s*centre)\b/i,
  /\b(?:patient|patient's|pt\.?)\b/i,
  /\b(?:doctor|physician|dr\.|dr\b|consultant|specialist|surgeon)\b/i,
  /\b(?:mbbs|m\.b\.b\.s|md|m\.d\.|ms|m\.s\.|bams|bhms)\b/i,
  /\b(?:pathology|laboratory|diagnostic|radiology|imaging)\b/i,
  /\b(?:prescription|prescribed|\brx\b|treatment|diagnosis|clinical|medical)\b/i,
  /\b(?:symptoms|investigation|specimen|reference\s*range|vitals)\b/i,
  /\b(?:hemoglobin|glucose|blood\s*sugar|blood\s*test|lab\s*report|discharge\s*summary)\b/i,
];

const CATEGORY_RULES: CategoryRule[] = [
  {
    categoryName: 'Blood Test',
    requiresMedicalAnchor: false, // Medical test names themselves act as anchors
    patterns: [
      { pattern: /\b(?:complete blood count|cbc)\b/i, tag: 'Complete Blood Count', weight: 2.0 },
      { pattern: /\b(?:hemoglobin|haemoglobin)\b/i, tag: 'Hemoglobin', weight: 1.5 },
      { pattern: /\b(?:hematology|haematology)\b/i, tag: 'Hematology', weight: 1.5 },
      { pattern: /\b(?:platelet\s*count|platelets)\b/i, tag: 'Platelets', weight: 1.5 },
      { pattern: /\b(?:blood\s*group|rh\s*factor)\b/i, tag: 'Blood Group', weight: 1.2 },
      { pattern: /\b(?:wbc\s*count|rbc\s*count|tlc|dlc)\b/i, tag: 'WBC/RBC', weight: 1.2 },
      { pattern: /\b(?:blood\s*sugar|fasting\s*blood\s*sugar|fasting\s*glucose|ppbs|fbs)\b/i, tag: 'Blood Sugar', weight: 1.5 },
      { pattern: /\b(?:lipid\s*profile|cholesterol|triglycerides?|hdl|ldl)\b/i, tag: 'Lipid Profile', weight: 1.5 },
      { pattern: /\b(?:hba1c|glycated\s*hemoglobin)\b/i, tag: 'HbA1c', weight: 1.5 },
      { pattern: /\b(?:liver\s*function|lft|kidney\s*function|kft|rft)\b/i, tag: 'LFT/KFT', weight: 1.5 },
      { pattern: /\b(?:serum\s*creatinine|blood\s*urea)\b/i, tag: 'Creatinine/Urea', weight: 1.5 },
      { pattern: /\b(?:thyroid|tsh|t3|t4)\b/i, tag: 'Thyroid', weight: 1.2 },
    ],
  },
  {
    categoryName: 'Lab Report',
    requiresMedicalAnchor: false,
    patterns: [
      { pattern: /\b(?:lab(?:oratory)?\s*report|pathology\s*report)\b/i, tag: 'Lab Report', weight: 2.0 },
      { pattern: /\b(?:test\s*report|investigation\s*report)\b/i, tag: 'Investigation', weight: 1.5 },
      { pattern: /\b(?:culture\s*(?:&|and)\s*sensitivity)\b/i, tag: 'Culture/Sensitivity', weight: 1.5 },
      { pattern: /\b(?:urine\s*routine|urinalysis|stool\s*routine|stool\s*test)\b/i, tag: 'Urinalysis', weight: 1.5 },
      { pattern: /\b(?:specimen|sample\s*type|biological\s*reference\s*interval)\b/i, tag: 'Pathology', weight: 1.2 },
      { pattern: /\b(?:pathologist|microbiology|biochemistry|histopathology)\b/i, tag: 'Laboratory', weight: 1.5 },
    ],
  },
  {
    categoryName: 'Prescription',
    requiresMedicalAnchor: true,
    patterns: [
      { pattern: /\b(?:prescription|prescribed)\b/i, tag: 'Prescription', weight: 2.5 },
      { pattern: /\bRx\b/i, tag: 'Rx', weight: 2.0 },
      { pattern: /\b(?:tab(?:let)?s?|caps?(?:ule)?s?|syrup|inj(?:ection)?s?)\b/i, tag: 'Medication', weight: 1.5 },
      { pattern: /\b\d+\s*(?:mg|mcg|ml|gm)\b/i, tag: 'Dosage', weight: 1.2 },
      { pattern: /\b(?:once|twice|thrice)\s+daily\b/i, tag: 'Dosage Schedule', weight: 1.2 },
      { pattern: /\b(?:before|after)\s+food\b/i, tag: 'Instructions', weight: 1.0 },
      { pattern: /\b(?:od|bd|tds|qid|hs|sos|prn)\b/i, tag: 'Dosage', weight: 1.0 },
      { pattern: /\b(?:pharmacy|dispense|refill)\b/i, tag: 'Pharmacy', weight: 1.2 },
    ],
  },
  {
    categoryName: 'Scan Report',
    requiresMedicalAnchor: false,
    patterns: [
      { pattern: /\b(?:x-?ray|radiology|radiograph)\b/i, tag: 'X-Ray', weight: 2.0 },
      { pattern: /\b(?:mri|magnetic\s*resonance)\b/i, tag: 'MRI', weight: 2.0 },
      { pattern: /\b(?:ct\s*scan|computed\s*tomography)\b/i, tag: 'CT Scan', weight: 2.0 },
      { pattern: /\b(?:ultrasound|sonography|usg)\b/i, tag: 'Ultrasound', weight: 2.0 },
      { pattern: /\b(?:ecg|ekg|electrocardiogram)\b/i, tag: 'ECG', weight: 2.0 },
      { pattern: /\b(?:echocardiogram|echo\s*report)\b/i, tag: 'Echo', weight: 2.0 },
      { pattern: /\b(?:mammogram|pet\s*scan|dexa\s*scan)\b/i, tag: 'Imaging', weight: 2.0 },
      { pattern: /\b(?:impression|radiological\s*findings)\b/i, tag: 'Scan Report', weight: 1.5 },
    ],
  },
  {
    categoryName: 'Discharge Summary',
    requiresMedicalAnchor: true,
    patterns: [
      { pattern: /\bdischarge\s*summary\b/i, tag: 'Discharge Summary', weight: 2.5 },
      { pattern: /\b(?:date\s*of\s*admission|date\s*of\s*discharge)\b/i, tag: 'Admission/Discharge', weight: 2.0 },
      { pattern: /\b(?:hospital\s*stay|inpatient|ward\s*no|bed\s*no)\b/i, tag: 'Inpatient', weight: 1.5 },
      { pattern: /\b(?:final\s*diagnosis|treatment\s*given|course\s*in\s*hospital)\b/i, tag: 'Diagnosis', weight: 1.5 },
      { pattern: /\b(?:discharge\s*advice|condition\s*at\s*discharge)\b/i, tag: 'Discharge Advice', weight: 1.5 },
    ],
  },
  {
    categoryName: 'Medical Bill',
    requiresMedicalAnchor: true,
    patterns: [
      // Medical bills require explicit medical billing terms, NOT generic finance/investment terms
      { pattern: /\b(?:hospital\s*bill|pharmacy\s*bill|clinic\s*receipt|medical\s*invoice)\b/i, tag: 'Medical Bill', weight: 2.5 },
      { pattern: /\b(?:consultation\s*fee|bed\s*charges|opd\s*charges|ipd\s*charges|procedure\s*charges|lab\s*charges)\b/i, tag: 'Medical Charges', weight: 2.0 },
      { pattern: /\b(?:health\s*insurance|mediclaim|tpa\s*claim|cashless\s*claim)\b/i, tag: 'Insurance Claim', weight: 2.0 },
    ],
  },
];

export interface CategorizationResult {
  categoryName: string;
  confidence: number;
  tags: string[];
}

export class CategorizerService {
  /**
   * Count clinical anchor occurrences to verify if text is medical.
   */
  hasMedicalContext(text: string): boolean {
    let count = 0;
    for (const anchor of CLINICAL_ANCHORS) {
      if (anchor.test(text)) {
        count++;
        if (count >= 2) return true; // At least 2 medical indicators
      }
    }
    return count >= 1;
  }

  /**
   * Clean filename to avoid accidental substring matches (e.g., "IMG-" matching "mg").
   */
  private extractMeaningfulFilenameKeywords(fileName?: string): string {
    if (!fileName) return '';
    // Strip file extension
    let clean = fileName.replace(/\.[a-zA-Z0-9]+$/, '');
    // Strip common camera/phone prefixes
    clean = clean.replace(/^(?:IMG|WP|PXL|WA|PHOTO|SCAN|DOC)[-_0-9]+/i, '');
    clean = clean.replace(/[_-]+/g, ' ');
    return clean.trim();
  }

  /**
   * Categorize a document based on extracted text and metadata.
   */
  categorize(text: string, fileName?: string): CategorizationResult {
    const cleanFileName = this.extractMeaningfulFilenameKeywords(fileName);
    const fullText = `${text}\n${cleanFileName}`;

    // Check if the document has any medical indicators
    const hasMedContext = this.hasMedicalContext(fullText);

    let bestCategory = 'General';
    let bestScore = 0;
    const categoryTags: Map<string, string[]> = new Map();

    for (const rule of CATEGORY_RULES) {
      // If rule requires medical context and none is found, skip medical classification
      if (rule.requiresMedicalAnchor && !hasMedContext) {
        continue;
      }

      let score = 0;
      const matchedTags: string[] = [];

      for (const p of rule.patterns) {
        if (p.pattern.test(fullText)) {
          score += p.weight;
          if (p.tag && !matchedTags.includes(p.tag)) {
            matchedTags.push(p.tag);
          }
        }
      }

      if (score > 0) {
        categoryTags.set(rule.categoryName, matchedTags);
      }

      // Minimum threshold of 1.5 to assign a specific medical category
      if (score >= 1.5 && score > bestScore) {
        bestScore = score;
        bestCategory = rule.categoryName;
      }
    }

    // If no strong medical category matched, classify as General (or Other if non-medical)
    if (bestScore < 1.5) {
      bestCategory = hasMedContext ? 'General' : 'Other';
      return {
        categoryName: bestCategory,
        confidence: hasMedContext ? 0.4 : 0.9,
        tags: [],
      };
    }

    // Extract tags specific to the chosen category
    const tags = categoryTags.get(bestCategory) || [];
    const confidence = Math.min(bestScore / 3.5, 0.98);

    return {
      categoryName: bestCategory,
      confidence: parseFloat(confidence.toFixed(2)),
      tags: tags.slice(0, 5),
    };
  }
}

export const categorizerService = new CategorizerService();
