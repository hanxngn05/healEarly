Noma Detection (iOS + On‑Device ML)
===================================

Important: This project is for research and education only and is NOT a medical device. It must not be used for diagnosis or clinical decision-making. If you pursue clinical use, you will need IRB/ethics approval, data governance, informed consent workflows, rigorous validation, and regulatory pathways (e.g., FDA/CE).

## Introduction
This project is developed by Dr. Saji Vijayan, Han Nguyen, Isabel Cheng, and Emily Fang, whose team placed in the Top 3 at Babson Buildathon 2025.

## Project Overview
- iOS app to capture face/mouth images and run on-device inference for potential Noma risk screening using a Core ML model.
- Python pipeline to train a lightweight image classifier (MobileNetV3) from a folder-structured dataset and export to Core ML.
- Optional next step: add a gait analysis module using CoreMotion accelerometer/gyroscope data and an on-device classifier.
<p align="center">
  <a href="./demo.mp4">
    <img src="./demo.gif" width="320" alt="App demo">
  </a>
</p>

## Repository Layout
- `ml/`: Training and export scripts (PyTorch → Core ML).
- `ios/`: SwiftUI/AVFoundation scaffolding for camera capture and on-device inference.

## Data Requirements (Noma)
Prepare an `ImageFolder`-style dataset:

```
/path/to/dataset/
  noma/
    img_0001.jpg
    img_0002.jpg
    ...
  normal/
    img_1001.jpg
    img_1002.jpg
    ...
```

Recommendations:
- Aim for at least several hundred images per class; more is better.
- Include diverse lighting, skin tones, ages, camera orientations, and backgrounds.
- Include physician-labeled ground truth and avoid personally identifiable information; store data securely.
- Add a separate validation/test split from different subjects than training.

## Quickstart: Training
1) Create a Python environment and install dependencies:

```
python3 -m venv .venv
source .venv/bin/activate
pip install -r ml/requirements.txt
```

2) Train:

```
python ml/train_noma.py \
  --data_dir /path/to/dataset \
  --output_dir ./artifacts/noma_v1 \
  --epochs 12 --batch_size 32 --lr 3e-4
```

Artifacts:
- `model_best.pt`: best PyTorch weights
- `class_index_to_label.json`: class labels mapping
- `metrics.json`: basic train/val metrics

## Export to Core ML

```
python ml/export_coreml.py \
  --checkpoint ./artifacts/noma_v1/model_best.pt \
  --class_map ./artifacts/noma_v1/class_index_to_label.json \
  --output_mlmodel ./artifacts/noma_v1/NomaClassifier.mlmodel \
  --image_size 224
```

Notes:
- Export requires macOS for certain Core ML conversions; if you run into issues on Linux, try on macOS.
- The `.mlmodel` should be added to your Xcode project; Xcode will compile it to `.mlmodelc`.

## Ethics, Consent, Privacy
- Obtain explicit informed consent for data capture; support opt-out and deletion.
- Provide clear user-facing disclaimers that this is not a diagnosis tool.
- Conduct bias analysis across demographic subgroups; communicate limitations.
