import argparse
import json
import os
from typing import List

import coremltools as ct
import torch
import torchvision
import torch.nn as nn


def build_model(num_classes: int, model_name: str, image_size: int) -> nn.Module:
	if model_name == "mobilenet_v3_small":
		model = torchvision.models.mobilenet_v3_small(weights=None)
		in_features = model.classifier[-1].in_features
		model.classifier[-1] = nn.Linear(in_features, num_classes)
	else:
		raise ValueError(f"Unsupported model: {model_name}")
	return model


def load_checkpoint(checkpoint_path: str) -> dict:
	state = torch.load(checkpoint_path, map_location="cpu")
	return state


def convert_to_coreml(checkpoint_path: str, class_names, output_mlmodel: str, image_size: int, model_name: str) -> None:
	os.makedirs(os.path.dirname(output_mlmodel), exist_ok=True)
	state = load_checkpoint(checkpoint_path)
	num_classes = len(class_names)

	model = build_model(num_classes=num_classes, model_name=model_name, image_size=image_size)
	model.load_state_dict(state["model_state"])
	model.eval()

	# Example input
	example = torch.randn(1, 3, image_size, image_size)
	traced = torch.jit.trace(model, example)

	# Convert to Core ML
	scale = 1.0 / 255.0
	bias = [0.0, 0.0, 0.0]
	input_type = ct.ImageType(name="image", shape=example.shape, color_layout="RGB", scale=scale, bias=bias)

	# Configure as a classifier so Vision yields VNClassificationObservation
	classifier_config = ct.ClassifierConfig(class_labels=class_names)
	mlmodel = ct.convert(
		traced,
		inputs=[input_type],
		classifier_config=classifier_config,
		minimum_deployment_target=ct.target.iOS17,
	)

	# Descriptions and metadata
	mlmodel.user_defined_metadata["classes"] = json.dumps(class_names)  # keep for reference
	mlmodel.short_description = "Noma risk screening classifier (MobileNetV3). Not a medical device."
	mlmodel.input_description["image"] = "Input image (RGB) scaled to {0}x{0}".format(image_size)
	for key in ("classLabel", "classLabelProbs"):
		if key in mlmodel.output_description:
			mlmodel.output_description[key] = "Predicted label" if key == "classLabel" else "Label probabilities"

	mlmodel.save(output_mlmodel)
	print(f"Saved Core ML model to: {output_mlmodel}")


def main():
	parser = argparse.ArgumentParser(description="Export PyTorch Noma classifier to Core ML (.mlmodel)")
	parser.add_argument("--checkpoint", type=str, required=True, help="Path to model_best.pt")
	parser.add_argument("--class_map", type=str, required=True, help="Path to class_index_to_label.json")
	parser.add_argument("--output_mlmodel", type=str, required=True, help="Output .mlmodel path")
	parser.add_argument("--image_size", type=int, default=224)
	parser.add_argument("--model_name", type=str, default="mobilenet_v3_small")
	args = parser.parse_args()

	with open(args.class_map, "r") as f:
		class_index_to_label = json.load(f)
	# Ensure order matches training indexing
	class_names = [class_index_to_label[str(i)] for i in range(len(class_index_to_label))]
	print("Classes:", class_names)

	convert_to_coreml(
		checkpoint_path=args.checkpoint,
		class_names=class_names,
		output_mlmodel=args.output_mlmodel,
		image_size=args.image_size,
		model_name=args.model_name,
	)


if __name__ == "__main__":
	main()
