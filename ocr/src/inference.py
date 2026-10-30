import sys
import json
import argparse
from medical_ocr_pipeline import MedicalOCRPipeline

def main():
    parser = argparse.ArgumentParser(description="Medical OCR Inference")
    parser.add_argument('--image', required=True, help="Path to the image")
    args = parser.parse_args()
    
    pipeline = MedicalOCRPipeline()
    result = pipeline.process_document(args.image)
    
    print(json.dumps(result))
    
if __name__ == '__main__':
    main()
