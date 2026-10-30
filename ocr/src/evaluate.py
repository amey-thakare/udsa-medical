import os
import torch
import Levenshtein
import pandas as pd
import json

from dataset_loader import get_dataloader
from model import CRNN

def ctc_decode(preds, idx2char):
    # preds: [W, B, C]
    _, preds_idx = preds.max(2)
    preds_idx = preds_idx.transpose(0, 1) # [B, W]
    
    decoded = []
    for batch in preds_idx:
        seq = []
        prev = 0
        for p in batch:
            p = p.item()
            if p != 0 and p != prev:
                seq.append(idx2char[p])
            prev = p
        decoded.append("".join(seq))
    return decoded

def evaluate():
    config_path = os.path.join(os.path.dirname(__file__), '../configs/dataset.yaml')
    test_loader = get_dataloader(config_path, split='test')
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'mps' if torch.backends.mps.is_available() else 'cpu')
    
    vocab = test_loader.dataset.vocab
    idx2char = test_loader.dataset.idx2char
    num_classes = len(vocab) + 1
    
    model = CRNN(img_channels=1, num_classes=num_classes).to(device)
    model_path = os.path.join(os.path.dirname(__file__), '../models/best_model/best_crnn.pth')
    if os.path.exists(model_path):
        model.load_state_dict(torch.load(model_path, map_location=device))
    else:
        print("Warning: best model not found. Using untrained weights.")
        
    model.eval()
    
    results = []
    total_cer = 0
    total_wer = 0
    total_words = 0
    total_chars = 0
    exact_matches = 0
    
    with torch.no_grad():
        for images, labels in test_loader:
            images = images.to(device)
            preds = model(images)
            decoded_preds = ctc_decode(preds, idx2char)
            
            # Since CRNN outputs raw logits, we can get confidence by softmax
            probs = torch.nn.functional.softmax(preds, dim=2)
            max_probs, _ = probs.max(dim=2)
            # pseudo confidence: average over sequence
            confidences = max_probs.mean(dim=0).cpu().numpy()
            
            for gt, pred, conf in zip(labels, decoded_preds, confidences):
                dist = Levenshtein.distance(pred, gt)
                cer = dist / max(len(gt), 1)
                
                wer = 1.0 if pred != gt else 0.0 # for single synthetic words
                
                total_cer += dist
                total_chars += max(len(gt), 1)
                
                total_wer += int(pred != gt)
                total_words += 1
                
                if pred == gt:
                    exact_matches += 1
                    
                results.append({
                    "ground_truth": gt,
                    "prediction": pred,
                    "CER": cer,
                    "WER": wer,
                    "confidence": float(conf)
                })
                
    final_cer = total_cer / total_chars
    final_wer = total_wer / total_words
    exact_match_acc = exact_matches / total_words
    
    metrics = {
        "CER": final_cer,
        "WER": final_wer,
        "Exact_Match_Accuracy": exact_match_acc,
        "Test_Samples": total_words
    }
    
    out_dir = os.path.join(os.path.dirname(__file__), '../evaluation')
    os.makedirs(out_dir, exist_ok=True)
    
    with open(os.path.join(out_dir, 'results.json'), 'w') as f:
        json.dump(metrics, f, indent=4)
        
    df = pd.DataFrame(results)
    df.to_csv(os.path.join(out_dir, 'test_predictions.csv'), index=False)
    
    print("Evaluation Complete.")
    print(json.dumps(metrics, indent=2))

if __name__ == '__main__':
    evaluate()
