import os
import glob
import random
import yaml
from PIL import Image
import torch
from torch.utils.data import Dataset, DataLoader
import torchvision.transforms as transforms

class OCRDataset(Dataset):
    def __init__(self, data_root, level="character", split="train", transform=None, seed=42, splits_config=None, synthetic_seq_len=(3, 8)):
        self.data_root = data_root
        self.level = level
        self.split = split
        self.transform = transform
        self.seed = seed
        self.synthetic_seq_len = synthetic_seq_len
        
        # Load configs
        if splits_config is None:
            splits_config = {"train": 0.8, "validation": 0.1, "test": 0.1}
            
        self.files = []
        self.labels = []
        
        if self.level == "character":
            self._load_character_data(splits_config)
        elif self.level == "synthetic_word":
            # Uses character data but synthesizes words on the fly
            self._load_character_data(splits_config)
        elif self.level in ["word", "line", "document"]:
            self._load_sequence_data(splits_config)
        else:
            raise ValueError(f"Unknown level: {level}")
            
    def _load_character_data(self, splits_config):
        classes = sorted([d for d in os.listdir(self.data_root) if os.path.isdir(os.path.join(self.data_root, d))])
        
        # We need a deterministic char-to-id mapping
        self.char2id = {c: i for i, c in enumerate(classes)}
        self.id2char = {i: c for c, i in self.char2id.items()}
        
        all_files_by_class = {}
        for cls in classes:
            cls_dir = os.path.join(self.data_root, cls)
            # Find all image files
            images = glob.glob(os.path.join(cls_dir, "*.*"))
            images = [f for f in images if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp', '.bmp'))]
            
            # Deterministic sort for reproducible splitting
            images.sort()
            
            # Shuffle with seed to prevent leakage
            random.seed(self.seed)
            random.shuffle(images)
            
            n = len(images)
            train_end = int(n * splits_config.get("train", 0.8))
            val_end = train_end + int(n * splits_config.get("validation", 0.1))
            
            if self.split == "train":
                all_files_by_class[cls] = images[:train_end]
            elif self.split == "validation":
                all_files_by_class[cls] = images[train_end:val_end]
            elif self.split == "test":
                all_files_by_class[cls] = images[val_end:]
            else:
                all_files_by_class[cls] = images
                
        # Flatten
        for cls, files in all_files_by_class.items():
            self.files.extend(files)
            # map class name to standard char if needed, for this dataset: 'A_U' -> 'A', 'a_L' -> 'a'
            actual_char = cls[0] if "_" in cls else cls
            self.labels.extend([actual_char] * len(files))
            
        # Group by label for synthetic generation
        self.files_by_label = {}
        for f, l in zip(self.files, self.labels):
            if l not in self.files_by_label:
                self.files_by_label[l] = []
            self.files_by_label[l].append(f)
            
        self.vocab = sorted(list(set(self.labels)))
        self.char2idx = {c: i+1 for i, c in enumerate(self.vocab)} # 0 for blank (CTC)
        self.idx2char = {i+1: c for i, c in enumerate(self.vocab)}
        self.idx2char[0] = '-' # blank
        
    def _load_sequence_data(self, splits_config):
        # Placeholder for real sequence data (words/lines/docs)
        # E.g., reading a labels.json or labels.txt
        # Not fully implemented until Phase 13
        self.vocab = []
        pass
        
    def __len__(self):
        if self.level == "synthetic_word":
            # Arbitrary epoch size for synthetic data
            return len(self.files) // max(1, sum(self.synthetic_seq_len)//2)
        return len(self.files)
        
    def __getitem__(self, idx):
        if self.level == "character":
            img_path = self.files[idx]
            label = self.labels[idx]
            img = Image.open(img_path).convert('RGB')
            if self.transform:
                img = self.transform(img)
            return img, label
            
        elif self.level == "synthetic_word":
            # Generate a random word length
            seq_len = random.randint(self.synthetic_seq_len[0], self.synthetic_seq_len[1])
            # Pick random chars
            chars = random.choices(self.vocab, k=seq_len)
            
            # Load random images for these chars
            imgs = []
            for c in chars:
                c_files = self.files_by_label[c]
                if not c_files: continue
                img_path = random.choice(c_files)
                imgs.append(Image.open(img_path).convert('L')) # Grayscale
                
            # Concatenate horizontally
            if not imgs:
                return torch.zeros((1, 32, 128)), ""
                
            widths, heights = zip(*(i.size for i in imgs))
            total_width = sum(widths)
            max_height = max(heights)
            
            # Simple synthesis
            new_im = Image.new('L', (total_width, max_height), 255) # white bg
            x_offset = 0
            for im in imgs:
                new_im.paste(im, (x_offset, max_height - im.size[1]))
                x_offset += im.size[0]
                
            label = "".join(chars)
            if self.transform:
                new_im = self.transform(new_im)
            else:
                # Default resize for sequence model
                new_im = new_im.resize((128, 32))
                new_im = transforms.ToTensor()(new_im)
                
            return new_im, label

def collate_fn(batch):
    images, labels = zip(*batch)
    images = torch.stack(images)
    return images, labels

def get_dataloader(config_path, split="train"):
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
        
    ds_config = config['dataset']
    splits = config['splits']
    
    transform = transforms.Compose([
        transforms.Resize((32, 128)),
        transforms.ToTensor(),
        transforms.Normalize((0.5,), (0.5,))
    ])
    
    dataset = OCRDataset(
        data_root=ds_config['root'],
        level=ds_config.get('level', 'character'),
        split=split,
        transform=transform,
        splits_config=splits
    )
    
    loader = DataLoader(
        dataset, 
        batch_size=config.get('batch_size', 32),
        shuffle=(split == "train"),
        collate_fn=collate_fn,
        num_workers=4
    )
    return loader
