import os
import glob
import json
from PIL import Image

def analyze_dataset(dataset_path, output_path):
    print(f"Analyzing dataset at {dataset_path}...")
    
    classes = os.listdir(dataset_path)
    classes = [c for c in classes if os.path.isdir(os.path.join(dataset_path, c))]
    
    report = {
        "dataset_type": "CHARACTER OCR",
        "total_images": 0,
        "number_of_classes": len(classes),
        "samples_per_class": {},
        "min_class_count": float('inf'),
        "max_class_count": 0,
        "image_formats": {},
        "corrupted_images": 0,
        "image_dimensions_distribution": {},
        "class_imbalance": False,
        "missing_labels": 0,
        "invalid_labels": 0
    }
    
    for cls in classes:
        cls_dir = os.path.join(dataset_path, cls)
        files = glob.glob(os.path.join(cls_dir, "*.*"))
        
        count = 0
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext not in ['.jpg', '.jpeg', '.png', '.webp', '.bmp']:
                continue
                
            report["image_formats"][ext] = report["image_formats"].get(ext, 0) + 1
            
            try:
                with Image.open(f) as img:
                    img.verify()  # verify integrity
                with Image.open(f) as img:
                    dims = f"{img.size[0]}x{img.size[1]}"
                    report["image_dimensions_distribution"][dims] = report["image_dimensions_distribution"].get(dims, 0) + 1
                count += 1
            except Exception as e:
                report["corrupted_images"] += 1
                
        report["samples_per_class"][cls] = count
        report["total_images"] += count
        
        if count < report["min_class_count"]:
            report["min_class_count"] = count
        if count > report["max_class_count"]:
            report["max_class_count"] = count
            
    if report["max_class_count"] > report["min_class_count"] * 2:
        report["class_imbalance"] = True
        
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w') as f:
        json.dump(report, f, indent=4)
        
    print(f"Analysis complete. Report saved to {output_path}")
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    dataset_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../dataset'))
    output_file = os.path.abspath(os.path.join(os.path.dirname(__file__), '../evaluation/dataset_report.json'))
    analyze_dataset(dataset_dir, output_file)
