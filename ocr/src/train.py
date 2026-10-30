import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
import yaml

from dataset_loader import get_dataloader
from model import CRNN

def train():
    config_path = os.path.join(os.path.dirname(__file__), '../configs/dataset.yaml')
    train_loader = get_dataloader(config_path, split='train')
    val_loader = get_dataloader(config_path, split='validation')
    
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
        
    device = torch.device('cuda' if torch.cuda.is_available() else 'mps' if torch.backends.mps.is_available() else 'cpu')
    print(f"Using device: {device}")
    
    vocab = train_loader.dataset.vocab
    num_classes = len(vocab) + 1 # +1 for CTC blank
    
    model = CRNN(img_channels=1, num_classes=num_classes).to(device)
    
    criterion = nn.CTCLoss(blank=0, zero_infinity=True)
    optimizer = optim.Adam(model.parameters(), lr=config.get('learning_rate', 0.001))
    
    epochs = config.get('epochs', 10)
    best_val_loss = float('inf')
    
    checkpoint_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../checkpoints'))
    best_model_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../models/best_model'))
    os.makedirs(checkpoint_dir, exist_ok=True)
    os.makedirs(best_model_dir, exist_ok=True)
    
    for epoch in range(epochs):
        model.train()
        train_loss = 0.0
        
        for batch_idx, (images, labels) in enumerate(train_loader):
            images = images.to(device)
            
            batch_size = images.size(0)
            
            optimizer.zero_grad()
            preds = model(images) # [W, B, C]
            
            input_lengths = torch.IntTensor([preds.size(0)] * batch_size)
            
            # encode labels
            targets = []
            target_lengths = []
            for label in labels:
                target = [train_loader.dataset.char2idx[c] for c in label if c in train_loader.dataset.char2idx]
                targets.extend(target)
                target_lengths.append(len(target))
                
            targets = torch.IntTensor(targets)
            target_lengths = torch.IntTensor(target_lengths)
            
            loss = criterion(preds.log_softmax(2), targets, input_lengths, target_lengths)
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
            
            if batch_idx % 10 == 0:
                print(f"Epoch {epoch+1}/{epochs} | Batch {batch_idx}/{len(train_loader)} | Loss: {loss.item():.4f}")
                
        # Validation
        model.eval()
        val_loss = 0.0
        with torch.no_grad():
            for images, labels in val_loader:
                images = images.to(device)
                batch_size = images.size(0)
                preds = model(images)
                
                input_lengths = torch.IntTensor([preds.size(0)] * batch_size)
                targets = []
                target_lengths = []
                for label in labels:
                    target = [val_loader.dataset.char2idx[c] for c in label if c in val_loader.dataset.char2idx]
                    targets.extend(target)
                    target_lengths.append(len(target))
                    
                targets = torch.IntTensor(targets)
                target_lengths = torch.IntTensor(target_lengths)
                
                loss = criterion(preds.log_softmax(2), targets, input_lengths, target_lengths)
                val_loss += loss.item()
                
        avg_val_loss = val_loss / len(val_loader)
        print(f"Epoch {epoch+1}/{epochs} | Val Loss: {avg_val_loss:.4f}")
        
        torch.save(model.state_dict(), os.path.join(checkpoint_dir, f'crnn_epoch_{epoch+1}.pth'))
        
        if avg_val_loss < best_val_loss:
            best_val_loss = avg_val_loss
            torch.save(model.state_dict(), os.path.join(best_model_dir, 'best_crnn.pth'))
            print("Saved best model.")
            
if __name__ == '__main__':
    train()
