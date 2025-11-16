import argparse
import json
import os

import coremltools as ct
import torch
import torch.nn as nn


class TinyDemoNet(nn.Module):
	def __init__(self, num_classes: int = 2):
		super().__init__()
		self.pool = nn.AdaptiveAvgPool2d((1, 1))
		self.flatten = nn.Flatten()
		# Simple linear from 3 channels to num_classes
		self.fc = nn.Linear(3, num_classes)

	def forward(self, x):
		x = self.pool(x)
		x = self.flatten(x)
		return self.fc(x)


def main():
	parser = argparse.ArgumentParser(description="Create a tiny demo Core ML model for hackathon use.")
	parser.add_argument("--output_mlmodel", type=str, required=True, help="Output .mlmodel path")
	parser.add_argument("--image_size", type=int, default=224)
	parser.add_argument("--classes", type=str, default="normal,noma", help="Comma-separated class labels")
	args = parser.parse_args()

	class_names = [c.strip() for c in args.classes.split(",") if c.strip()]
	if len(class_names) < 2:
		raise ValueError("Please provide at least two classes, e.g. 'normal,noma'.")

	# Build a tiny network and set a slight bias towards 'normal' for safer demos
	model = TinyDemoNet(num_classes=len(class_names)).eval()
	with torch.no_grad():
		# Initialize weights with small values and bias to favor class 0
		for p in model.parameters():
			p.uniform_(-0.05, 0.05)
		if hasattr(model.fc, "bias") and model.fc.bias is not None:
			model.fc.bias[0] = 0.5

	example = torch.randn(1, 3, args.image_size, args.image_size)
	traced = torch.jit.trace(model, example)

	scale = 1.0 / 255.0
	bias = [0.0, 0.0, 0.0]
	input_type = ct.ImageType(name="image", shape=example.shape, color_layout="RGB", scale=scale, bias=bias)

	mlmodel = ct.convert(traced, inputs=[input_type], minimum_deployment_target=ct.target.iOS17)
	mlmodel.user_defined_metadata["classes"] = json.dumps(class_names)
	mlmodel.short_description = "Tiny demo classifier for hackathon demos. Not a medical device."
	mlmodel.input_description["image"] = f"Input {args.image_size}x{args.image_size} RGB image"
	mlmodel.output_description["var_1"] = "Raw logits"

	os.makedirs(os.path.dirname(args.output_mlmodel), exist_ok=True)
	mlmodel.save(args.output_mlmodel)
	print(f"Saved demo Core ML model to: {args.output_mlmodel}")


if __name__ == "__main__":
	main()
