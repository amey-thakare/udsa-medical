/**
 * Health Parameter Extraction Service
 * 
 * Extracts structured health parameters from OCR text using
 * medical regex patterns and clinical validation.
 * 
 * Strict guardrails prevent extracting false positives from non-medical documents
 * (such as business notes, invoices, or general text).
 */

export interface ExtractedParameter {
  parameterName: string;
  value: number;
  unit: string;
  confidence: number;
  originalText: string;
}

interface PatternConfig {
  parameterName: string;
  patterns: RegExp[];
  unit: string;
  minPlausible: number;
  maxPlausible: number;
}

const PARAMETER_PATTERNS: PatternConfig[] = [
  {
    parameterName: 'glucose',
    patterns: [
      // Explicit "Blood Glucose", "Blood Sugar", "Fasting Glucose", "Random Glucose"
      /\b(?:bl[o0]{2}d\s*)?(?:gl[uo]c[o0]se|sugar)\b[^0-9]{0,25}?(\d+(?:[.,]\d+)?)\s*(?:mg\s*\/?\s*d[lL1])?/gi,
      // Fasting/Random/PP explicit
      /\b(?:fast(?:ing)?|rand[o0]m|pp|p[o0]st[\s-]*prand[il]al)\s+(?:bl[o0]{2}d\s+)?(?:sugar|gl[uo]c[o0]se)\b[^0-9]{0,20}?(\d+(?:[.,]\d+)?)/gi,
      // Abbreviations REQUIRE the clinical unit mg/dL so "RBF" or financial terms never match
      /\b(?:FBS|RBS|PPBS|FPG|RPG|F\.B\.S|R\.B\.S)\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(?:mg\s*\/?\s*d[lL1])/gi,
    ],
    unit: 'mg/dL',
    minPlausible: 30,
    maxPlausible: 600,
  },
  {
    parameterName: 'hemoglobin',
    patterns: [
      // Full name
      /\b(?:h[ae][em][o0]gl[o0]b[il1]n|h[ae]m[o0]gl[o0]b[il1]n)\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(?:g\s*\/?\s*d[lL1]|gm?\s*%)?/gi,
      // Abbreviations Hb, Hgb, HGB with unit or colon separator
      /\b(?:Hb|Hgb|HGB|H\.G\.B)\b\s*[:.\-=]?\s*(\d+(?:[.,]\d+)?)\s*(?:g\s*\/?\s*d[lL1]|gm?\s*%)?/gi,
    ],
    unit: 'g/dL',
    minPlausible: 3,
    maxPlausible: 25,
  },
  {
    parameterName: 'systolic_bp',
    patterns: [
      // Explicit "Blood Pressure 120/80"
      /\b(?:bl[o0]{2}d\s*press?ure|bp|b\.p\.)\b[^0-9]{0,15}?(\d{2,3})\s*[\/\\|]\s*\d{2,3}\s*(?:mm\s*[hH][gG])?/gi,
      // "Systolic: 120"
      /\bsyst[o0]l[il1]c\b[^0-9]{0,15}?(\d{2,3})\s*(?:mm\s*[hH][gG])?/gi,
    ],
    unit: 'mmHg',
    minPlausible: 60,
    maxPlausible: 250,
  },
  {
    parameterName: 'diastolic_bp',
    patterns: [
      // Second number from "Blood Pressure 120/80"
      /\b(?:bl[o0]{2}d\s*press?ure|bp|b\.p\.)\b[^0-9]{0,15}?\d{2,3}\s*[\/\\|]\s*(\d{2,3})\s*(?:mm\s*[hH][gG])?/gi,
      // "Diastolic: 80"
      /\bd[il1]ast[o0]l[il1]c\b[^0-9]{0,15}?(\d{2,3})\s*(?:mm\s*[hH][gG])?/gi,
    ],
    unit: 'mmHg',
    minPlausible: 30,
    maxPlausible: 160,
  },
  {
    parameterName: 'cholesterol',
    patterns: [
      // Explicit "Total Cholesterol" or "Cholesterol"
      /\b(?:t[o0]tal\s*)?ch[o0]lester[o0]l\b[^0-9]{0,20}?(\d+(?:[.,]\d+)?)\s*(?:mg\s*\/?\s*d[lL1])?/gi,
      // Abbreviation TC or CHOL with unit or colon
      /\b(?:TC|CHOL|T\.?\s*CHOL)\b\s*[:.\-=]?\s*(\d+(?:[.,]\d+)?)\s*(?:mg\s*\/?\s*d[lL1])/gi,
    ],
    unit: 'mg/dL',
    minPlausible: 50,
    maxPlausible: 500,
  },
  {
    parameterName: 'heart_rate',
    patterns: [
      // Explicit "Heart Rate" or "Pulse"
      /\b(?:heart\s*rate|pulse(?:\s*rate)?)\b[^0-9]{0,15}?(\d{2,3})\s*(?:bpm|b\.p\.m|beats?\s*(?:per|\/)\s*min(?:ute)?|\/\s*min)?/gi,
      // Abbreviation HR requires clinical unit bpm or /min to prevent matching Human Resources
      /\bHR\b\s*[:.\-=]?\s*(\d{2,3})\s*(?:bpm|b\.p\.m|\/\s*min)/gi,
    ],
    unit: 'bpm',
    minPlausible: 30,
    maxPlausible: 250,
  },
  {
    parameterName: 'hba1c',
    patterns: [
      // HbA1c, Glycated hemoglobin
      /\b(?:hba[l1]c|hb\s*a[l1]c|glyc[ao]ted\s*h[ae][em][o0]?gl[o0]b[il1]n)\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*%?/gi,
      // "A1c: 6.5%"
      /\bA[l1][cC]\b\s*[:.\-=]?\s*(\d+(?:[.,]\d+)?)\s*%/gi,
    ],
    unit: '%',
    minPlausible: 3,
    maxPlausible: 20,
  },
  {
    parameterName: 'creatinine',
    patterns: [
      /\b(?:serum\s*)?creat[il1]n[il1]ne?\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(?:mg\s*\/?\s*d[lL1])?/gi,
      /\bs\.?\s*creat\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(?:mg\s*\/?\s*d[lL1])?/gi,
    ],
    unit: 'mg/dL',
    minPlausible: 0.1,
    maxPlausible: 20,
  },
  {
    parameterName: 'wbc',
    patterns: [
      /\b(?:wh[il1]te\s*bl[o0]{2}d\s*c[e3]lls?|t[o0]tal\s*(?:wbc|leuc[o0]cyte|leuk[o0]cyte)\s*c[o0]unt)\b[^0-9]{0,15}?(\d+(?:[,.]?\d+)?)/gi,
      /\b(?:WBC|W\.B\.C|TLC)\b\s*[:.\-=]?\s*(\d+(?:[,.]?\d+)?)/gi,
    ],
    unit: 'cells/mcL',
    minPlausible: 1000,
    maxPlausible: 50000,
  },
  {
    parameterName: 'platelets',
    patterns: [
      /\b(?:plat[e3]l[e3]t\s*c[o0]unt|plat[e3]l[e3]ts?)\b[^0-9]{0,15}?(\d+(?:[,.]?\d+)?)/gi,
      /\bPLT\b\s*[:.\-=]?\s*(\d+(?:[,.]?\d+)?)/gi,
    ],
    unit: 'cells/mcL',
    minPlausible: 10000,
    maxPlausible: 900000,
  },
];

export class ParamExtractorService {
  /**
   * Verify if the text has clinical anchors before extracting parameters.
   */
  hasClinicalContext(text: string): boolean {
    const clinicalPatterns = [
      /\b(?:patient|doctor|physician|dr\.|hospital|clinic|dispensary)\b/i,
      /\b(?:laboratory|pathology|diagnostic|test\s*report|investigation)\b/i,
      /\b(?:blood|serum|plasma|urine|specimen|biological\s*reference)\b/i,
      /\b(?:reference\s*range|normal\s*range|vitals|vital\s*signs)\b/i,
      /\b(?:hemoglobin|glucose|cholesterol|creatinine|platelets|wbc|rbc)\b/i,
      /\b(?:mg\s*\/\s*d[lL]|g\s*\/\s*d[lL]|mm\s*Hg|cells\s*\/\s*mcL)\b/i,
    ];

    let matchCount = 0;
    for (const pattern of clinicalPatterns) {
      if (pattern.test(text)) {
        matchCount++;
        if (matchCount >= 2) return true;
      }
    }
    return matchCount >= 1;
  }

  /**
   * Pre-process OCR text to fix common OCR errors before pattern matching.
   */
  private normalizeText(text: string): string {
    let t = text;
    t = t.replace(/\r\n/g, '\n');
    t = t.replace(/[ \t]+/g, ' ');
    t = t.replace(/mg\s*\/\s*d[iI1]/g, 'mg/dL');
    t = t.replace(/g\s*\/\s*d[iI1]/g, 'g/dL');
    t = t.replace(/mm\s*[hH][gG9]/g, 'mmHg');
    t = t.replace(/([a-zA-Z]):(\d)/g, '$1: $2');
    return t;
  }

  /**
   * Extract health parameters from OCR text.
   * If the document is classified as General or Other (non-medical), parameters will NOT be extracted
   * unless strong clinical report indicators are present.
   */
  extract(text: string, categoryName?: string): ExtractedParameter[] {
    if (!text || text.trim().length === 0) {
      return [];
    }

    // Guardrail: Skip parameter extraction if category is explicitly non-medical or general,
    // unless document contains verifiable clinical lab context.
    const isExplicitNonMedical = categoryName === 'Other' || categoryName === 'Medical Bill';
    const hasClinical = this.hasClinicalContext(text);

    if (isExplicitNonMedical || (!hasClinical && categoryName === 'General')) {
      console.log(`[ParamExtractor] Non-medical document (${categoryName || 'Unknown'}, clinical: ${hasClinical}). Skipping health parameter extraction.`);
      return [];
    }

    // Normalize text to fix common OCR artifacts
    const normalizedText = this.normalizeText(text);
    const results: ExtractedParameter[] = [];
    const seen = new Set<string>();

    for (const paramConfig of PARAMETER_PATTERNS) {
      for (const pattern of paramConfig.patterns) {
        const regex = new RegExp(pattern.source, pattern.flags);
        let match;

        while ((match = regex.exec(normalizedText)) !== null) {
          const rawValue = match[1].replace(/,/g, '');
          const value = parseFloat(rawValue);

          if (isNaN(value)) continue;

          // Check plausibility range
          if (value < paramConfig.minPlausible || value > paramConfig.maxPlausible) continue;

          // Skip if already found
          if (seen.has(paramConfig.parameterName)) continue;
          seen.add(paramConfig.parameterName);

          const confidence = this.calculateConfidence(match[0], value, paramConfig);

          console.log(`[ParamExtractor] ✓ Found ${paramConfig.parameterName}: ${value} ${paramConfig.unit} (confidence: ${confidence.toFixed(2)}, matched: "${match[0].trim()}")`);

          results.push({
            parameterName: paramConfig.parameterName,
            value,
            unit: paramConfig.unit,
            confidence,
            originalText: match[0].trim(),
          });
        }
      }
    }

    console.log(`[ParamExtractor] Total extracted: ${results.length} parameters`);
    return results;
  }

  private calculateConfidence(
    matchText: string,
    value: number,
    config: PatternConfig
  ): number {
    let confidence = 0.70;

    const unitPatterns: Record<string, RegExp> = {
      'mg/dL': /mg\s*\/?\s*d[lL1]|mg\s*%/i,
      'g/dL': /g\s*\/?\s*d[lL1]|g\s*%|gm\s*\/?\s*d[lL1]/i,
      'mmHg': /mm\s*h[gG]|mmhg/i,
      'bpm': /bpm|beats?\s*(?:per|\/)\s*min/i,
      '%': /%/,
      'cells/mcL': /cells?\s*\/?\s*(?:mc|µ|u)?[lL1]|thou/i,
    };

    if (unitPatterns[config.unit]?.test(matchText)) {
      confidence += 0.2;
    }

    if (config.minPlausible <= value && value <= config.maxPlausible) {
      confidence += 0.05;
    }

    return Math.min(confidence, 0.98);
  }
}

export const paramExtractorService = new ParamExtractorService();
