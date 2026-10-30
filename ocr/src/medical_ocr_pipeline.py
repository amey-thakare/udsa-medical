import os
import torch
import cv2
from PIL import Image
import numpy as np

from preprocess import OCRPreprocessor
from model import CRNN
from evaluate import ctc_decode
import yaml

class MedicalOCRPipeline:
    def __init__(self, config_path=None):
        if config_path is None:
            config_path = os.path.join(os.path.dirname(__file__), '../configs/dataset.yaml')
            
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
            
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'mps' if torch.backends.mps.is_available() else 'cpu')
        
        # Load vocab
        self.vocab = self._load_vocab(config)
        self.idx2char = {i+1: c for i, c in enumerate(self.vocab)}
        self.idx2char[0] = '-'
        
        self.model = CRNN(img_channels=1, num_classes=len(self.vocab)+1).to(self.device)
        model_path = os.path.join(os.path.dirname(__file__), '../models/best_model/best_crnn.pth')
        if os.path.exists(model_path):
            self.model.load_state_dict(torch.load(model_path, map_location=self.device))
        self.model.eval()
        
        self.preprocessor = OCRPreprocessor()
        
    def _load_vocab(self, config):
        dataset_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), config['dataset']['root']))
        if os.path.exists(dataset_dir):
            classes = sorted([d for d in os.listdir(dataset_dir) if os.path.isdir(os.path.join(dataset_dir, d))])
            vocab = [c[0] if "_" in c else c for c in classes]
            return sorted(list(set(vocab)))
        return []

    def detect_regions(self, image):
        """
        Simple heuristic text detector using contours for medical docs.
        In a production system, this would be CRAFT or DBNet.
        """
        gray = self.preprocessor.to_grayscale(image)
        thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 11, 2)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 3))
        dilated = cv2.dilate(thresh, kernel, iterations=1)
        
        contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        regions = []
        for c in contours:
            x, y, w, h = cv2.boundingRect(c)
            if w > 20 and h > 10:
                regions.append([x, y, x+w, y+h])
                
        # Sort top-to-bottom, left-to-right
        regions.sort(key=lambda b: (b[1], b[0]))
        return regions

    def recognize_region(self, region_img):
        img_tensor = torch.FloatTensor(region_img).unsqueeze(0).unsqueeze(0) / 255.0
        img_tensor = (img_tensor - 0.5) / 0.5
        img_tensor = img_tensor.to(self.device)
        
        with torch.no_grad():
            preds = self.model(img_tensor)
            decoded = ctc_decode(preds, self.idx2char)[0]
            
            probs = torch.nn.functional.softmax(preds, dim=2)
            max_probs, _ = probs.max(dim=2)
            confidence = float(max_probs.mean(dim=0).cpu().numpy()[0])
            
        return decoded, confidence

    def analyze_medical_value(self, text, confidence):
        # Flags suspicious medical extractions
        needs_review = False
        if confidence < 0.85:
            needs_review = True
            
        # Specific check for dangerous medical numeric patterns
        import re
        if re.search(r'\d+[.,]\d+', text) and confidence < 0.90:
            needs_review = True # Decimal points are critical
            
        if re.search(r'(g/dl|mg/dl|/µL|mmol/L)', text, re.IGNORECASE) and confidence < 0.88:
            needs_review = True
            
        return needs_review

    def process_document(self, image_path):
        if not os.path.exists(image_path):
            return {"success": False, "reason": "FILE_NOT_FOUND"}
            
        image = cv2.imread(image_path)
        
        # 1. Quality check (stub)
        if image.mean() < 30 or image.mean() > 225:
            return {"success": False, "reason": "IMAGE_QUALITY_TOO_LOW"}
            
        # 2. Deskew / Normalize
        processed_image = self.preprocessor.deskew(image)
        
        # 3. Detect regions
        regions_bbox = self.detect_regions(processed_image)
        
        results = []
        total_conf = 0
        
        # 4. OCR
        for bbox in regions_bbox:
            x1, y1, x2, y2 = bbox
            roi = processed_image[y1:y2, x1:x2]
            
            # prep for CRNN
            roi_prep = self.preprocessor.preprocess_pipeline(roi, pipeline_type="default")
            if len(roi_prep.shape) == 3:
                roi_prep = roi_prep.transpose(2, 0, 1)[0] # take L channel
            
            text, conf = self.recognize_region(roi_prep)
            
            needs_review = self.analyze_medical_value(text, conf)
            
            if text.strip():
                results.append({
                    "bbox": bbox,
                    "text": text,
                    "confidence": conf,
                    "needs_review": needs_review
                })
                total_conf += conf
                
        full_text = "\n".join([r['text'] for r in results])
        
        return {
            "success": True,
            "text": full_text,
            "regions": results,
            "overall_confidence": total_conf / len(results) if results else 0.0
        }

if __name__ == "__main__":
    pipeline = MedicalOCRPipeline()
    print("Pipeline ready.")
