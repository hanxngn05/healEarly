Noma Detection (iOS + On‑Device ML)
===================================

Important: This project is for research and education only and is NOT a medical device. It must not be used for diagnosis or clinical decision-making. If you pursue clinical use, you will need IRB/ethics approval, data governance, informed consent workflows, rigorous validation, and regulatory pathways (e.g., FDA/CE).

Project Overview
----------------
- iOS app to capture face/mouth images and run on-device inference for potential Noma risk screening using a Core ML model.
- Python pipeline to train a lightweight image classifier (MobileNetV3) from a folder-structured dataset and export to Core ML.
- Optional next step: add a gait analysis module using CoreMotion accelerometer/gyroscope data and an on-device classifier.

Repository Layout
-----------------
- `ml/`: Training and export scripts (PyTorch → Core ML).
- `ios/`: SwiftUI/AVFoundation scaffolding for camera capture and on-device inference.

Data Requirements (Noma)
------------------------
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

Quickstart: Training
--------------------
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

Export to Core ML
-----------------

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

iOS App (Camera + On-Device Inference)
--------------------------------------
Files under `ios/` show how to:
- Initialize a camera preview.
- Run Core ML inference via Vision (`VNCoreMLRequest`) on captured frames.
- Display the predicted label and confidence.

Steps:
1) Create a new Xcode SwiftUI app (iOS 16+ recommended).
2) Drag `ios/*.swift` into your project (Copy items if needed).
3) Drag `NomaClassifier.mlmodel` into Xcode; build to generate the model class.
4) Run on device; grant camera permissions.

Ethics, Consent, Privacy (Must-Haves)
-------------------------------------
- Obtain explicit informed consent for data capture; support opt-out and deletion.
- Avoid storing images on-device unless necessary; if stored, encrypt at rest and in transit.
- Provide clear user-facing disclaimers that this is not a diagnosis tool.
- Implement subject privacy protections: masking faces, limiting retention, and secure data handling.
- Conduct bias analysis across demographic subgroups; communicate limitations.

Optional: Gait Analysis (Next Iteration)
----------------------------------------
- Capture accelerometer/gyroscope with CoreMotion.
- Segment into windows (e.g., 4–6 seconds), extract time/frequency domain features, and train a small model.
- Export to Core ML (similar to image pipeline).
- Add a toggle/tab in the app to run gait screening.

Troubleshooting
---------------
- If training is unstable, lower learning rate, increase data, add augmentations, or use class weights.
- If export fails, ensure consistent model definition between training and export, and try `opset_version=13` for ONNX paths.
- If iOS inference is slow, use smaller image size (e.g., 192), ensure `preferredMetalDevice`, and throttle frame rate.

Demo (Screen Recording)
-----------------------
Short demo of the end-to-end flow (on-device, offline):

- Click to watch full video:

[![Demo](./demo.gif)](./demo.mp4)

License
-------
Choose an appropriate license for your use-case (e.g., Apache-2.0). Ensure that dataset licenses and consents permit your intended use.

Hackathon Demo Quickstart (No Dataset)
--------------------------------------
Need a quick demo without training?

1) Create and install the Python env:
```
python3 -m venv .venv
source .venv/bin/activate
pip install -r ml/requirements.txt
```

2) Generate a tiny demo Core ML model:
```
python ml/make_demo_model.py \
  --output_mlmodel ./artifacts/demo/NomaClassifier.mlmodel \
  --image_size 224 \
  --classes normal,noma
```

3) iOS app:
- Use the included XcodeGen project in `ios/`:
  - `brew install xcodegen`
  - `cd ios && xcodegen generate && open NomaApp.xcodeproj`
- Drag `./artifacts/demo/NomaClassifier.mlmodel` into Xcode (or skip it: app falls back to Demo Mode).
- Ensure Signing is set, plug in an iPhone, and Run.

Notes:
- If the model is missing, the app automatically runs in Demo Mode and shows plausible predictions based on frame brightness (for demo only).
- Replace the demo model with a trained one later for real results.
