import argparse
import json
import math
import os
import random
from dataclasses import dataclass
from typing import Dict, List, Tuple

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
import torchvision
from sklearn.metrics import classification_report, confusion_matrix
from torch.utils.data import DataLoader, WeightedRandomSampler
from torchvision import transforms
from tqdm import tqdm


def set_seed(seed: int) -> None:
	"""
	Set seeds for reproducibility across Python, NumPy, and PyTorch.
	"""
	random.seed(seed)
	np.random.seed(seed)
	torch.manual_seed(seed)
	torch.cuda.manual_seed_all(seed)
	torch.backends.cudnn.deterministic = True
	torch.backends.cudnn.benchmark = False


@dataclass
class TrainConfig:
	data_dir: str
	output_dir: str
	image_size: int = 224
	batch_size: int = 32
	epochs: int = 12
	learning_rate: float = 3e-4
	weight_decay: float = 1e-4
	model_name: str = "mobilenet_v3_small"
	device: str = "cuda" if torch.cuda.is_available() else "cpu"
	seed: int = 42


def build_transforms(image_size: int) -> Tuple[transforms.Compose, transforms.Compose]:
	"""
	Build training and validation transforms.
	"""
	train_tfms = transforms.Compose([
		transforms.Resize(int(image_size * 1.15)),
		transforms.RandomResizedCrop(image_size, scale=(0.8, 1.0)),
		transforms.RandomHorizontalFlip(),
		transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2, hue=0.05),
		transforms.ToTensor(),
		transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
	])
	val_tfms = transforms.Compose([
		transforms.Resize(image_size),
		transforms.CenterCrop(image_size),
		transforms.ToTensor(),
		transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
	])
	return train_tfms, val_tfms


def make_datasets(data_dir: str, image_size: int) -> Tuple[torchvision.datasets.ImageFolder, torchvision.datasets.ImageFolder]:
	train_tfms, val_tfms = build_transforms(image_size)
	train_dir = os.path.join(data_dir, "train") if os.path.isdir(os.path.join(data_dir, "train")) else data_dir
	val_dir = os.path.join(data_dir, "val") if os.path.isdir(os.path.join(data_dir, "val")) else data_dir

	train_ds = torchvision.datasets.ImageFolder(root=train_dir, transform=train_tfms)
	val_ds = torchvision.datasets.ImageFolder(root=val_dir, transform=val_tfms)
	return train_ds, val_ds


def make_loaders(train_ds, val_ds, batch_size: int) -> Tuple[DataLoader, DataLoader, List[str]]:
	class_counts = np.bincount([y for _, y in train_ds.samples])
	class_weights = 1.0 / np.maximum(class_counts, 1)
	sample_weights = [class_weights[y] for _, y in train_ds.samples]
	sampler = WeightedRandomSampler(weights=sample_weights, num_samples=len(sample_weights), replacement=True)

	train_loader = DataLoader(train_ds, batch_size=batch_size, sampler=sampler, num_workers=4, pin_memory=True)
	val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False, num_workers=4, pin_memory=True)
	class_names = train_ds.classes
	return train_loader, val_loader, class_names


def build_model(num_classes: int, model_name: str) -> nn.Module:
	if model_name == "mobilenet_v3_small":
		model = torchvision.models.mobilenet_v3_small(weights=torchvision.models.MobileNet_V3_Small_Weights.DEFAULT)
		in_features = model.classifier[-1].in_features
		model.classifier[-1] = nn.Linear(in_features, num_classes)
	else:
		raise ValueError(f"Unsupported model: {model_name}")
	return model


def evaluate(model: nn.Module, loader: DataLoader, device: str) -> Tuple[float, float, Dict[str, float], np.ndarray]:
	model.eval()
	criterion = nn.CrossEntropyLoss()
	running_loss = 0.0
	correct = 0
	total = 0
	all_targets: List[int] = []
	all_preds: List[int] = []

	with torch.no_grad():
		for images, targets in loader:
			images = images.to(device, non_blocking=True)
			targets = targets.to(device, non_blocking=True)
			outputs = model(images)
			loss = criterion(outputs, targets)
			running_loss += loss.item() * images.size(0)
			_, preds = outputs.max(1)
			correct += preds.eq(targets).sum().item()
			total += images.size(0)
			all_targets.extend(targets.tolist())
			all_preds.extend(preds.tolist())

	avg_loss = running_loss / max(total, 1)
	acc = correct / max(total, 1)
	report = classification_report(all_targets, all_preds, output_dict=True, zero_division=0)
	conf_mat = confusion_matrix(all_targets, all_preds)
	return avg_loss, acc, report, conf_mat


def train(cfg: TrainConfig) -> None:
	set_seed(cfg.seed)
	os.makedirs(cfg.output_dir, exist_ok=True)

	train_ds, val_ds = make_datasets(cfg.data_dir, cfg.image_size)
	train_loader, val_loader, class_names = make_loaders(train_ds, val_ds, cfg.batch_size)

	device = torch.device(cfg.device)
	model = build_model(num_classes=len(class_names), model_name=cfg.model_name).to(device)

	# Class weighting for imbalance based on training distribution
	class_counts = np.bincount([y for _, y in train_ds.samples], minlength=len(class_names))
	class_weights = torch.tensor(1.0 / np.maximum(class_counts, 1), dtype=torch.float32, device=device)
	criterion = nn.CrossEntropyLoss(weight=class_weights)

	optimizer = optim.AdamW(model.parameters(), lr=cfg.learning_rate, weight_decay=cfg.weight_decay)
	lr_scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=cfg.epochs)

	best_val_acc = 0.0
	best_checkpoint_path = os.path.join(cfg.output_dir, "model_best.pt")

	for epoch in range(1, cfg.epochs + 1):
		model.train()
		epoch_loss = 0.0
		epoch_correct = 0
		epoch_total = 0
		pbar = tqdm(train_loader, desc=f"Epoch {epoch}/{cfg.epochs}", ncols=100)
		for images, targets in pbar:
			images = images.to(device, non_blocking=True)
			targets = targets.to(device, non_blocking=True)

			optimizer.zero_grad(set_to_none=True)
			outputs = model(images)
			loss = criterion(outputs, targets)
			loss.backward()
			optimizer.step()

			epoch_loss += loss.item() * images.size(0)
			_, preds = outputs.max(1)
			epoch_correct += preds.eq(targets).sum().item()
			epoch_total += images.size(0)
			pbar.set_postfix(loss=f"{epoch_loss / max(epoch_total,1):.4f}", acc=f"{epoch_correct / max(epoch_total,1):.3f}")

		lr_scheduler.step()

		val_loss, val_acc, val_report, val_conf = evaluate(model, val_loader, cfg.device)

		metrics = {
			"epoch": epoch,
			"train_loss": epoch_loss / max(epoch_total, 1),
			"train_acc": epoch_correct / max(epoch_total, 1),
			"val_loss": val_loss,
			"val_acc": val_acc,
			"val_report": val_report,
			"val_confusion_matrix": val_conf.tolist(),
			"class_names": class_names,
		}
		with open(os.path.join(cfg.output_dir, "metrics.json"), "w") as f:
			json.dump(metrics, f, indent=2)

		# Save best
		if val_acc > best_val_acc:
			best_val_acc = val_acc
			state = {
				"epoch": epoch,
				"model_name": cfg.model_name,
				"model_state": model.state_dict(),
				"class_names": class_names,
				"image_size": cfg.image_size,
			}
			torch.save(state, best_checkpoint_path)

	# Persist class index mapping
	class_index_to_label = {int(i): name for i, name in enumerate(class_names)}
	with open(os.path.join(cfg.output_dir, "class_index_to_label.json"), "w") as f:
		json.dump(class_index_to_label, f, indent=2)

	print(f"Training complete. Best model saved to: {best_checkpoint_path}")


def parse_args() -> TrainConfig:
	parser = argparse.ArgumentParser(description="Train a Noma image classifier (MobileNetV3).")
	parser.add_argument("--data_dir", type=str, required=True, help="Path to ImageFolder dataset or to split with train/val subfolders.")
	parser.add_argument("--output_dir", type=str, required=True, help="Directory to save checkpoints and metrics.")
	parser.add_argument("--image_size", type=int, default=224)
	parser.add_argument("--batch_size", type=int, default=32)
	parser.add_argument("--epochs", type=int, default=12)
	parser.add_argument("--lr", type=float, default=3e-4)
	parser.add_argument("--weight_decay", type=float, default=1e-4)
	parser.add_argument("--model_name", type=str, default="mobilenet_v3_small")
	parser.add_argument("--seed", type=int, default=42)
	args = parser.parse_args()
	return TrainConfig(
		data_dir=args.data_dir,
		output_dir=args.output_dir,
		image_size=args.image_size,
		batch_size=args.batch_size,
		epochs=args.epochs,
		learning_rate=args.lr,
		weight_decay=args.weight_decay,
		model_name=args.model_name,
		seed=args.seed,
	)


if __name__ == "__main__":
	cfg = parse_args()
	train(cfg)
