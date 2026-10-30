import cv2
import numpy as np
from PIL import Image

class OCRPreprocessor:
    def __init__(self):
        pass

    def to_grayscale(self, image):
        if len(image.shape) == 3:
            return cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        return image

    def resize_with_pad(self, image, target_width=128, target_height=32):
        # Resize preserving aspect ratio and pad
        h, w = image.shape[:2]
        aspect = w / h
        target_aspect = target_width / target_height

        if aspect > target_aspect:
            new_w = target_width
            new_h = max(1, int(target_width / aspect))
        else:
            new_h = target_height
            new_w = max(1, int(target_height * aspect))

        resized = cv2.resize(image, (new_w, new_h))
        
        # Pad
        pad_x = target_width - new_w
        pad_y = target_height - new_h
        
        top, bottom = pad_y // 2, pad_y - (pad_y // 2)
        left, right = pad_x // 2, pad_x - (pad_x // 2)
        
        color = [255, 255, 255] if len(image.shape) == 3 else 255
        padded = cv2.copyMakeBorder(resized, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color)
        return padded

    def normalize(self, image):
        # CLAHE (Contrast Limited Adaptive Histogram Equalization)
        gray = self.to_grayscale(image)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        return clahe.apply(gray)

    def denoise(self, image):
        # Fast non-local means denoising
        return cv2.fastNlMeansDenoising(image, None, 10, 7, 21)

    def adaptive_threshold(self, image):
        gray = self.to_grayscale(image)
        # Gaussian adaptive thresholding
        return cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)

    def sharpen(self, image):
        kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
        return cv2.filter2D(image, -1, kernel)

    def deskew(self, image):
        gray = self.to_grayscale(image)
        gray = cv2.bitwise_not(gray)
        coords = np.column_stack(np.where(gray > 0))
        if len(coords) == 0:
            return image
        angle = cv2.minAreaRect(coords)[-1]
        
        if angle < -45:
            angle = -(90 + angle)
        else:
            angle = -angle
            
        (h, w) = image.shape[:2]
        center = (w // 2, h // 2)
        M = cv2.getRotationMatrix2D(center, angle, 1.0)
        rotated = cv2.warpAffine(image, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
        return rotated
        
    def preprocess_pipeline(self, image_path, pipeline_type="default"):
        """
        Loads and preprocesses an image.
        pipeline_type can be: default, contrast, denoise, adaptive, deskew_sharpen
        """
        if isinstance(image_path, str):
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError(f"Could not load image: {image_path}")
        elif isinstance(image_path, np.ndarray):
            image = image_path
        elif isinstance(image_path, Image.Image):
            image = np.array(image_path)
            # convert RGB to BGR
            if len(image.shape) == 3:
                image = image[:, :, ::-1]
        else:
            raise ValueError("Unsupported input format")
            
        if pipeline_type == "default":
            # Grayscale -> Normalize -> Resize/Pad
            img = self.to_grayscale(image)
            img = self.normalize(img)
            img = self.resize_with_pad(img)
        elif pipeline_type == "contrast":
            img = self.normalize(image)
            img = self.resize_with_pad(img)
        elif pipeline_type == "denoise":
            img = self.to_grayscale(image)
            img = self.denoise(img)
            img = self.resize_with_pad(img)
        elif pipeline_type == "adaptive":
            img = self.adaptive_threshold(image)
            img = self.resize_with_pad(img)
        elif pipeline_type == "deskew_sharpen":
            img = self.deskew(image)
            img = self.sharpen(img)
            img = self.resize_with_pad(img)
        else:
            img = self.resize_with_pad(image)
            
        return img
